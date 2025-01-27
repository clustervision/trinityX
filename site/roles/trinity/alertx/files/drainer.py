#!/usr/bin/env python3

from flask import Flask, request, jsonify
import requests
import json
import subprocess
import re
import sys

app = Flask(__name__)

marker = "Trix-drainer:"
true_dict = {"true","True","yes","Yes"}
false_dict = {"false","False","no","No"}


def get_unique_nodes():
    """
    Returns all the unique nodes running on the system in a list
    """
    try:
        # Run the scontrol command and capture the output
        result = subprocess.run(['scontrol', 'show', 'nodes'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        
        # Check if the command was successful
        if result.returncode != 0:
            raise RuntimeError(f"Error running scontrol: {result.stderr}")
        
        # Use a regular expression to find all node names
        node_names = re.findall(r'NodeName=(\S+)', result.stdout)
        
        # Get unique node names
        unique_nodes = list(set(node_names))
        return unique_nodes
    except Exception as e:
        print(f"An error occurred: {e}")
        return []


def get_node_info(node_name):
    """
    Gets all slurm info on a specific node using the $node_name parameter 
    """
    try:
        # Run the scontrol command to get the node information
        output = subprocess.check_output(['scontrol', 'show', 'node', node_name], universal_newlines=True)
        
        # Split the output by whitespace while keeping key-value pairs intact
        node_info = {}
        for line in output.splitlines():
            key_value_pairs = re.findall(r'(\S+)=("[^"]+"|\S+)', line)
            for key, value in key_value_pairs:
                node_info[key] = value.strip('"')

        return node_info

    except subprocess.CalledProcessError as e:
        print(f"Error retrieving state for node {node_name}: {e}")
        return None


def node_info_to_json(node_name):
    """
    Executes the get_node_info func() and returns the information in JSON format
    """
    node_info = get_node_info(node_name)
    if node_info:
        # Convert the dictionary to JSON
        return json.dumps(node_info, indent=4)
    else:
        return "{}"

@app.route('/listener', methods=['POST'])
def listener():
    if request.is_json:
        prometheus_data = request.get_json()
        with open("/root/drainer/prometheus_data_final.txt", "w") as file:
            json.dump(prometheus_data, file, indent=4)
        if 'alerts' not in prometheus_data: # This is not being sent from prometheus
            return jsonify({'error': 'Invalid json content'}), 400
        all_nodes_list = get_unique_nodes()
        alerts_prometheus = prometheus_data['alerts']
        node_drained = False
        node_resumed = True
        nhc_firing_nodes = [] # Contains node names where NHC is on and gets at least one firing state
        nhc_resolved_nodes = [] # Contains node names where NHC is on and gets at least on resolved state
        for alert in alerts_prometheus:
            labels_dict = alert["labels"]
            alert_name = labels_dict["alertname"]
            hostname = ""
            if "hostname" in labels_dict:
                hostname = labels_dict["hostname"]
            else:
                continue
            node_name = hostname.split('.')[0]
            if node_name not in all_nodes_list: #Prometheus can return data on non-slurm nodes, this check eliminates these
                continue
            if "nhc" not in labels_dict:
                continue # No need for NHC to do much default is FALSE
            nhc = labels_dict["nhc"]
            if nhc in false_dict:
                continue # No need for NHC to do much

            node_info = json.loads(node_info_to_json(node_name))
            state = node_info["State"]

            if alert['status'] == 'firing':
                if nhc in true_dict:
                    ## Code to perform "firing" + "nhc" = disable node
                    ## Disable node only if it is enabled
                    ## Drain Node
                    if state == "IDLE":
                        nhc_firing_nodes.append(node_name) if node_name not in nhc_firing_nodes else None
                        reason = f"{marker} {alert_name} error triggered, check Grafana/Prometheus to debug"
                        try:
                            # Run the scontrol command to drain the node with the provided reason
                            print(node_name)
                            subprocess.check_call(['scontrol', 'update', f'NodeName={node_name}', 'State=DRAIN', f'Reason={reason}'])
                            print(f"Node {node_name} drained successfully with reason: {reason}")
                            node_drained = True
                        except subprocess.CalledProcessError as e:
                            print(f"Error draining node {node_name}: {e}")
                    else:
                        continue ## State is not IDLE anyways
                        
            elif alert['status'] == 'resolved':
                if nhc in true_dict:
                    reason = ""
                    if "Reason" in node_info:
                        reason = node_info["Reason"]
                    
                    if "DRAIN" in state and marker in reason:
                        nhc_resolved_nodes.append(node_name) if node_name not in nhc_resolved_nodes else None
                else:
                    continue

        # Drain nodes that should resolve but are not firing
        for resolve_node in nhc_resolved_nodes:            
            if resolve_node in nhc_firing_nodes:
                continue
            try:
                # Run the scontrol command to drain the node with the provided reason
                subprocess.check_call(['scontrol', 'update', f'NodeName={resolve_node}', 'State=RESUME'])
                print(f"Node {resolve_node} resumed successfully")
                node_resumed = True
            except subprocess.CalledProcessError as e:
                print(f"Error resuming node {resolve_node}: {e}")

        ## JSON Return
        messages = []

        if node_drained:
            messages.append("node(s) successfully drained")
        if node_resumed:
            messages.append("node(s) successfully resumed")

        if len(messages) == 0:
            return jsonify({"No content": "No changes made"}, 204)

        msg = ""
        if len(messages) == 2:
            msg = " & ".join(messages)
        else:
            msg = messages[0]
            
        return jsonify({"Success": msg}, 200)            
                        
    else:
        return jsonify({'error': 'Invalid Content-Type'}), 400
    
    

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5554)
    

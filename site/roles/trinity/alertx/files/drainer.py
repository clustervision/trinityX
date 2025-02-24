#!/usr/bin/env python3

from flask import Flask, request, jsonify
import requests
import json
import subprocess
import re
import sys
import logging
import os
import configparser

# Setup config
config = configparser.ConfigParser()
config.read('/trinity/local/etc/alertx/drainer.ini')

def get_config_option(section, option, default):
    try:
        return config.getboolean(section, option)
    except (configparser.NoOptionError, ValueError):
        return default

DEBUG_MODE = get_config_option('settings', 'debug', False)
AUTO_UNDRAIN = get_config_option('settings', 'auto_undrain', True)

# Setup logging
log_directory = '/var/log/alertx'
log_file = os.path.join(log_directory, 'drainer.log')

os.makedirs(log_directory, exist_ok=True)

logging.basicConfig(
    level=logging.DEBUG if DEBUG_MODE else logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(log_file),
        logging.StreamHandler(sys.stdout)
    ]
)

logger = logging.getLogger(__name__)

app = Flask(__name__)

marker = "Trix-drainer:"
true_dict = {"true", "True", "yes", "Yes"}
false_dict = {"false", "False", "no", "No"}

def get_unique_nodes():
    try:
        result = subprocess.run(['scontrol', 'show', 'nodes'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        if result.returncode != 0:
            raise RuntimeError(f"Error running scontrol: {result.stderr}")

        node_names = re.findall(r'NodeName=(\S+)', result.stdout)
        unique_nodes = list(set(node_names))
        if DEBUG_MODE:
            logger.debug(f"Unique nodes retrieved for this post request: {unique_nodes}")
        return unique_nodes
    except Exception as e:
        logger.error(f"An error occurred while retrieving unique nodes: {e}")
        return []

def get_node_info(node_name):
    try:
        output = subprocess.check_output(['scontrol', 'show', 'node', node_name], universal_newlines=True)
        node_info = {}
        for line in output.splitlines():
            key_value_pairs = re.findall(r'(\S+)=("[^"]+"|\S+)', line)
            for key, value in key_value_pairs:
                node_info[key] = value.strip('"')

        if DEBUG_MODE:
            logger.debug(f"Getting node info from slurm for {node_name}: {node_info}")
        return node_info
    except subprocess.CalledProcessError as e:
        logger.error(f"Error retrieving state for node {node_name}: {e}")
        return None

def node_info_to_json(node_name):
    node_info = get_node_info(node_name)
    if node_info:
        return json.dumps(node_info, indent=4)
    else:
        return "{}"

@app.route('/listener', methods=['POST'])
def listener():
    if request.is_json:
        logger.info(f"New JSON request received: ")
        prometheus_data = request.get_json()
        if 'alerts' not in prometheus_data:
            logger.warning("Invalid JSON content received: missing 'alerts'")
            return jsonify({'error': 'Invalid json content'}), 400

        all_nodes_list = get_unique_nodes()
        alerts_prometheus = prometheus_data['alerts']
        node_drained = False
        node_resumed = False
        nhc_firing_nodes = []
        nhc_resolved_nodes = []

        for alert in alerts_prometheus:
            labels_dict = alert["labels"]
            alert_name = labels_dict["alertname"]
            hostname = labels_dict.get("hostname", "")
            if not hostname:
                continue

            node_name = hostname.split('.')[0]
            if node_name not in all_nodes_list:
                continue

            if "nhc" not in labels_dict:
                continue

            nhc = labels_dict["nhc"]
            if nhc in false_dict:
                continue

            node_info = json.loads(node_info_to_json(node_name))
            state = node_info.get("State", "")

            if alert['status'] == 'firing' and nhc in true_dict:
                if "DRAIN" not in state:
                    nhc_firing_nodes.append(node_name)
                    reason = f"{marker} {alert_name} error triggered, check Grafana/Prometheus to debug"
                    try:
                        subprocess.check_call(['scontrol', 'update', f'NodeName={node_name}', 'State=DRAIN', f'Reason={reason}'])
                        logger.info(f"Node {node_name} drained successfully with reason: {reason}")
                        node_drained = True
                    except subprocess.CalledProcessError as e:
                        logger.error(f"Error draining node {node_name}: {e}")

            elif alert['status'] == 'resolved' and nhc in true_dict:
                reason = node_info.get("Reason", "")
                if "DRAIN" in state and marker in reason:
                    nhc_resolved_nodes.append(node_name)

        if AUTO_UNDRAIN:
            for resolve_node in nhc_resolved_nodes:
                if resolve_node in nhc_firing_nodes:
                    continue
                try:
                    subprocess.check_call(['scontrol', 'update', f'NodeName={resolve_node}', 'State=RESUME'])
                    logger.info(f"Node {resolve_node} resumed successfully")
                    node_resumed = True
                except subprocess.CalledProcessError as e:
                    logger.error(f"Error resuming node {resolve_node}: {e}")

        messages = []
        if node_drained:
            messages.append("node(s) successfully drained")
        if node_resumed:
            messages.append("node(s) successfully resumed")

        if not messages:
            return jsonify({"No content": "No changes made"}), 204

        msg = " & ".join(messages)
        logger.info(f"Listener processing completed for this post request: {msg}")
        return jsonify({"Success": msg}), 200

    else:
        logger.warning("Invalid Content-Type received")
        return jsonify({'error': 'Invalid Content-Type'}), 400

if __name__ == '__main__':
    logger.info("Starting Flask app on port 7150")
    app.run(host='0.0.0.0', port=7150)



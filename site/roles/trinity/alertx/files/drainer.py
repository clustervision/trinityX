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
import signal
import atexit

# Setup config
config = configparser.ConfigParser()
config.read('/trinity/local/alertx/drainer/config/drainer.ini') #Hardcoded path, do not change


def get_config_option(section, option, default, value_type='bool'):
    try:
        if value_type == 'bool':
            return config.getboolean(section, option)
        elif value_type == 'int':
            return config.getint(section, option)
        elif value_type == 'float':
            return config.getfloat(section, option)
        else:
            return config.get(section, option)
    except (configparser.NoOptionError, ValueError):
        return default


DEBUG_MODE = get_config_option('LOGGER', 'DEBUG_MODE', False)
LOG_DIR = get_config_option('LOGGER', 'LOG_DIR', '/var/log/alertx', 'str')
AUTO_UNDRAIN = get_config_option('DRAINING', 'AUTO_UNDRAIN', True)

# Setup logging
log_directory = LOG_DIR
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
true_dict = ["true", "True", "yes", "Yes", True]
false_dict = ["false", "False", "no", "No", False]


logger.info(f"AlertX-Drainer service started")

if DEBUG_MODE in true_dict:
    logger.info(f"debug mode is set to {DEBUG_MODE}")
elif DEBUG_MODE in false_dict:
    logger.info(f"debug mode is set to {DEBUG_MODE}")
else:
    logger.warning(f"debug mode is set to {DEBUG_MODE} which is faulty")


if AUTO_UNDRAIN in true_dict:
    logger.info(f"auto_undrain is set to {AUTO_UNDRAIN}")
elif AUTO_UNDRAIN in false_dict:
    logger.info(f"auto_undrain is set to {AUTO_UNDRAIN}")
else:
    logger.warning(f"auto_undrain is set to {AUTO_UNDRAIN} which is faulty")


def log_service_stop():
    logger.info("Service is stopping...")

atexit.register(log_service_stop)


def get_unique_nodes():
    try:
        result = subprocess.run(['scontrol', 'show', 'nodes'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        if result.returncode != 0:
            logger.error(f"Error running scontrol: {result.stderr}")
            raise RuntimeError(f"Error running scontrol: {result.stderr}")

        node_names = re.findall(r'NodeName=(\S+)', result.stdout)
        unique_nodes = list(set(node_names))
        logger.debug(f"Unique nodes retrieved from slurm: {unique_nodes}")
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
            description = "No description"
            if "annotations" in alert and "description" in alert["annotations"]:
                description = alert["annotations"]["description"]
            alert_name = labels_dict["alertname"]
            hostname = labels_dict.get("hostname", "")
            if not hostname:
                logger.debug(f"No hostname found for alert with name {alert_name}")
                logger.debug(f"Skipping alert: {alert_name}........")
                continue

            node_name = hostname.split('.')[0]
            if node_name not in all_nodes_list:
                logger.debug(f"Node ( {node_name} ) found in the prometheus alert {alert_name}, doesn't exist on slurm: scontrol show nodes")
                logger.debug(f"Skipping alert: {alert_name}........")
                continue

            if "nhc" not in labels_dict:
                logger.debug(f"For alert with name: {alert_name} the NHC flag doesn't exist, and so the default is NHC is OFF")
                logger.debug(f"Skipping alert: {alert_name}........")
                continue

            nhc = labels_dict["nhc"]
            if nhc in false_dict:
                logger.debug(f"For alert with name: {alert_name} the NHC flag is {nhc} which is not of value ( true )")
                logger.debug(f"Skipping alert: {alert_name}........")
                continue

            node_info = json.loads(node_info_to_json(node_name))
            state = node_info.get("State", "")

            if alert['status'] == 'firing' and nhc in true_dict:
                if "DRAIN" not in state:
                    logger.debug(f"Alert with name {alert_name} is firing for {node_name}, this node should drain now")
                    if node_name not in nhc_firing_nodes:
                        nhc_firing_nodes.append(node_name)
                    reason = f"{marker} {alert_name} error triggered, check the AlertX dashboard or AlertX logs to debug"
                    try:
                        subprocess.check_call(['scontrol', 'update', f'NodeName={node_name}', 'State=DRAIN', f'Reason={reason}'])
                        logger.info(f"Node {node_name} drained successfully with reason: {reason} ... Full description: {description}")
                        node_drained = True
                    except subprocess.CalledProcessError as e:
                        logger.error(f"Error draining node {node_name}: {e}")
                if "DRAIN" in state:
                    logger.debug(f"Alert with name {alert_name} is firing again for {node_name}, but the node is already drained")
                    if node_name not in nhc_firing_nodes:
                        nhc_firing_nodes.append(node_name)
                    logger.info(f"Node {node_name} is already drained but another NHC-enabled alert {alert_name} is firing ... Full description: {description}")

            elif alert['status'] == 'resolved' and nhc in true_dict:
                reason = node_info.get("Reason", "")
                if "DRAIN" in state and marker in reason:
                    logger.debug(f"Node {node_name} will potentially be undrained if no other alert is firing for this specific node and AUTO_UNDRAIN is set to True")
                    if node_name not in nhc_resolved_nodes:
                        nhc_resolved_nodes.append(node_name)
                else:
                    logger.debug(f"Node {node_name} is either already not drained or it wasn't drained by the drainer originally")
                    logger.debug(f"Hence drainer won't undrain this node {node_name}")

        if AUTO_UNDRAIN:
            for resolve_node in nhc_resolved_nodes:
                if resolve_node in nhc_firing_nodes:
                    logger.debug(f"Node {resolve_node} is resloved for at least one rule but also firing for at least one other NHC rule")
                    logger.debug(f"If node should be undrained then check for other NHC rules that are firing")
                    logger.debug(f"Node {resolve_node} won't be undrained .... skipping")
                    continue
                try:
                    subprocess.check_call(['scontrol', 'update', f'NodeName={resolve_node}', 'State=RESUME'])
                    logger.info(f"Node {resolve_node} resumed successfully")
                    node_resumed = True
                except subprocess.CalledProcessError as e:
                    logger.error(f"Error resuming node {resolve_node}: {e}")
        else:
            logger.debug(f"AUTO_UNDRAIN is set to false, drained node(s) will not undrain")
        
        messages = []
        if node_drained:
            messages.append("node(s) successfully drained")
        if node_resumed:
            messages.append("node(s) successfully resumed")

        if not messages:
            logger.info(f"No changes made during this post request")
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



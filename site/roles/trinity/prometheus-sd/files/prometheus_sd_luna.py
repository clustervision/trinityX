import subprocess 
import json
import yaml
import argparse
import time
import systemd.daemon

CMD = "luna node list --raw"
REFRESH_INTERVAL = 60

def get_hostnames():
    output = subprocess.check_output(CMD, shell=True)
    nodes = json.loads(output)
    hostnames = [  node['hostname'] for _, node in nodes.items() ]
    return hostnames

def get_exporters():
    targets = [{
        'targets': [
            f'{hostname}:9100' for hostname in get_hostnames()
        ]
    }]
    return targets

def write_exporters(filepath):
    targets = get_exporters()
    with open(filepath, 'w') as f:
        yaml.dump(targets, f)

def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('sd_file', help='Path to the file to write the service discovery targets to')
    return parser.parse_args()

def run():
    args = parse_args()
    systemd.daemon.notify('READY=1')
    while True:
        write_exporters(args.sd_file)
        time.sleep(REFRESH_INTERVAL)

if __name__ == '__main__':
    run()
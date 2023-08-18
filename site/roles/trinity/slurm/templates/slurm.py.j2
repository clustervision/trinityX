#!/usr/bin/env python3
import sys
import subprocess
import os
import datetime
import platform
import pprint
import requests

checktime = datetime.datetime.now().strftime("%s")
tagline = "hostname={}".format(os.uname().nodename)
lineprotocol = ""
url = "http://localhost:8086/write?db=slurm&precision=s"


# Squeue
# A (JobID), P (Partition), j (Jobname), u (Username)
# t (Job state), r (Reason), %C (CPUs requested or allocated)
# Mandatory: print the header, this is the field name.

# Sinfo
# %C Allocated / idle / other / total
# Transitioning from 6 allocated + 4 idle -> 10.

# 190001 11:30:48 [root@trixdev04 ~]# sinfo -o %C
# CPUS(A/I/O/T)
# 6/4/0/10
# 190001 11:30:50 [root@trixdev04 ~]# sinfo -o %C
# CPUS(A/I/O/T)
# 10/0/0/10

# Sinfo
# %F
# sinfo -o %F
# NODES(A/I/O/T)
# 4/0/0/4

# Sdiag
# No options.

slurm_output = {}


commandlist = {
    "squeue": 'squeue -h -a -r -o %P,%A,%j,%u,%t,%C --states=all',
    "sinfo_cpus": 'sinfo -h -o %C',
    "sinfo_nodes": 'sinfo -h -o %F',
    "sdiag": 'sdiag'

}

def process_sdiag(checkcommand,output):
    print(type(output))
    print(output)

def exec_slurm(checkcommand,checkname):
    try:
        process_output = subprocess.check_output(checkcommand,shell=True,stderr=subprocess.STDOUT,universal_newlines=True)
    except subprocess.CalledProcessError as e:
        print("Failure to execute command" + e.output)
        sys.exit(2)
    return checkname, process_output


# Loop through the commands. Then update the dictionary as 'command' -> 'output'

for checkname, checkcommand in commandlist.items():
    process_output = exec_slurm(checkcommand,checkname)
    slurm_output.update([process_output])

# Loop through command and process the output.
for check, output in slurm_output.items():
    if check == "sdiag":
        for line in output.split('\n'):
            if "Jobs pending" in line:
                jobs_pending = line.split(':')[1].lstrip(' ')
            if "Jobs running" in line:
                jobs_running = line.split(':')[1].lstrip(' ')
        lineprotocol += "sdiag,{} jobs_pending={},jobs_running={} {}\n".format(tagline,jobs_pending,jobs_running,checktime)
    if check == "sinfo_cpus":
        cpu_a, cpu_i, cpu_o, cpu_t = output.rstrip('\n').split('/')
        lineprotocol += "sinfo_cpus,{} cpu_allocated={},cpu_idle={},cpu_other={},cpu_total={} {}\n".format(tagline, cpu_a, cpu_i, cpu_o, cpu_t, checktime)
    if check == "sinfo_nodes":
        node_a, node_i, node_o, node_t = output.rstrip('\n').split('/')
        lineprotocol += "sinfo_nodes,{} nodes_allocated={},nodes_idle={},nodes_other={},nodes_total={} {}\n".format(tagline, node_a, node_i, node_o, node_t, checktime)
    if check == "squeue":
        slurm_partition = {}
        partition_id = 0
        for line in output.split('\n'):
             if line:
                 part,jobid,jobname,user,state,cpus = line.split(',')
             else:
                 # Invalid line or incomplete line
                 break

             if not part in slurm_partition:
                 # A new partition encountered, set all metrics
                 slurm_partition[part] = {}
                 slurm_partition[part]["running"] = 0
                 slurm_partition[part]["pending"] = 0
                 slurm_partition[part]["suspended"] = 0
                 slurm_partition[part]["cancelled"] = 0
                 slurm_partition[part]["completing"] = 0
                 slurm_partition[part]["completed"] = 0
                 slurm_partition[part]["configuring"] = 0
                 slurm_partition[part]["failed"] = 0
                 slurm_partition[part]["timeout"] = 0
                 slurm_partition[part]["preempted"] = 0
                 slurm_partition[part]["node_fail"] = 0

             if state == "R":
                 slurm_partition[part]["running"] += 1
             if state == "PD":
                 slurm_partition[part]["pending"] += 1
             if state == "S":
                 slurm_partition[part]["suspended"] += 1
             if state == "CA":
                 slurm_partition[part]["cancelled"] += 1
             if state == "CD":
                 slurm_partition[part]["completed"] += 1
             if state == "CG":
                 slurm_partition[part]["completing"] += 1
             if state == "CF":
                 slurm_partition[part]["configuring"] += 1
             if state == "F":
                 slurm_partition[part]["failed"] += 1
             if state == "TO":
                 slurm_partition[part]["timeout"] += 1
             if state == "PR":
                 slurm_partition[part]["preempted"] += 1
             if state == "NF":
                 slurm_partition[part]["node_fail"] += 1

        for partition in slurm_partition.items():
            queuename = partition[0]
            kev = ''
            for key,value in partition[1].items():
                kev += "{}={},".format(key,value)
            lineprotocol += "squeue,{},part={} {} {}\n".format(tagline, queuename, kev.rstrip(','), checktime)

if lineprotocol:
     try:
         r = requests.post(url, data=lineprotocol)
         print(r.status_code)
     except requests.exceptions.ConnectionError:
         print("Database seems offline")
     print(lineprotocol)

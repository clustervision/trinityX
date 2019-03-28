#!/usr/bin/python
import os
import sys
import json
import time
import syslog
import hostlist
import requests
import subprocess

import libcloud.compute.base

from libcloud.compute.types import Provider
from libcloud.compute.providers import get_driver

from argparse import ArgumentParser
from ConfigParser import SafeConfigParser


def parse_section(section):
    log(LOG_DEBUG, 'Parsing configuration section "%s"' % section)

    if not powerconfig.has_option(section, 'type'):
        log(LOG_WARN, 'Section "%s" does not have a type option, skipping.' % section)
        return False

    section_type = powerconfig.get(section, 'type').upper()
    log(LOG_DEBUG, 'Section "%s" is of type "%s"' %
                   (section, section_type))

    if section_type == 'CUSTOM':
        # If we are in the default section we need to parse the PowerTypes
        # section otherwise we return.
        # If we do not return here then the if statement completes and we
        # only need to write the code once rather than in every parser
        res = parse_custom_section(section)

        if section != 'default':
            return res

    elif section_type == 'ELASTIC-CLOUD':
        res = parse_elastic_cloud_section(section)

        if section != 'default':
            return res

    elif section_type == '':
        if section != 'default':
            log(LOG_WARN, 'No type specified for section "%s", skipping.' % section)
            return False

    else:
        log(LOG_WARN, 'Unsupported section type "%s", skipping. Valid values are "%s"' %
                      (section_type, supportedTypes))
        return False

    # if we have got here then we have successfully parsed the current section
    # and we should be in the default section. one last thing to check to see
    # if we are in the default section and if there are more sections to check,
    # if so we parse them
    if section == 'default' and powerconfig.has_option(section, 'PowerTypes'):
        types = powerconfig.get(section, 'PowerTypes').split(',')
        log(LOG_DEBUG, 'Section "default" has the following power management types "%s"' % types)

        for t in types:
            result = parse_section(t)

            if result is not True:
                return result

    return True


def parse_custom_section(section):
    log(LOG_DEBUG, 'Parsing custom section "%s"' % section)

    if section != 'default':
        if powerconfig.has_option(section, 'Nodes'):
            nodes = powerconfig.get(section, 'Nodes')
        else:
            log(LOG_WARN, '"Nodes" option not defined in section "%s"' % section)
            return False

        # expand the node list using the hostlist python module
        try:
            hosts = hostlist.expand_hostlist(nodes)
        except hostlist.BadHostlist as e:
            log(LOG_ERR, 'Bad hostlist "%s" - "%s"' % (nodes, e))
            sys.exit(1)

    else:
        hosts = ['default']

    for option in ['CustomPowerOnScript', 'CustomPowerOffScript',
                   'CustomRebootScript', 'CustomPowerStatusScript']:
        if not powerconfig.has_option(section, option):
            log(LOG_WARN, '"%s" not found in section "%s"' % (option, section))
            return False

    conf = {'type': 'CUSTOM'}
    conf['ON'] = powerconfig.get(section, 'CustomPowerOnScript')
    conf['OFF'] = powerconfig.get(section, 'CustomPowerOffScript')
    conf['REBOOT'] = powerconfig.get(section, 'CustomRebootScript')
    conf['STATUS'] = powerconfig.get(section, 'CustomPowerStatusScript')

    for host in hosts:
        if host in host_remap:
            hostname = host_remap[host]
        else:
            hostname = host

        host_config[hostname] = conf

    log(LOG_DEBUG, 'Parsed Custom Section "%s"' % section)

    return True


def parse_elastic_cloud_section(section):
    log(LOG_DEBUG, 'Parsing elastic-cloud section "%s"' % section)

    if section != 'default':
        if powerconfig.has_option(section, 'Nodes'):
            nodes = powerconfig.get(section, 'Nodes')
        else:
            log(LOG_WARN, '"Nodes" option not defined in section "%s"' % section)
            return False

        # expand the node list using the hostlist python module
        try:
            hosts = hostlist.expand_hostlist(nodes)
        except hostlist.BadHostlist as e:
            log(LOG_ERR, 'Bad hostlist "%s" - "%s"' % (nodes, e))
            sys.exit(1)

    else:
        hosts = ['default']

    for option in ['provider', 'CloudConfigFile']:
        if not powerconfig.has_option(section, option):
            log(LOG_WARN, '"%s" not found in section "%s"' % (option, section))
            return False

    path = powerconfig.get(section, 'CloudConfigFile')

    if path in cloudconfigfiles:
        log(LOG_DEBUG, 'Cloud config file "%s" already parsed' % path)
    else:
        result = parse_cloud_config(path)
        if result is not True:
            return result

    conf = {'type': 'ELASTIC-CLOUD'}
    conf['provider'] = powerconfig.get(section, 'provider')
    conf['config_file'] = os.path.realpath(path)

    for host in hosts:
        host_config[host] = conf

    log(LOG_DEBUG, 'Parsed ElastiCloud "%s"' % section)
    return True


def parse_cloud_config(path):
    log(LOG_NOTICE, 'Parsing cloud config file "%s"' % path)
    cloudconfigfiles.append(path)

    conf = {'queues': {}, 'nodetypes': {}}
    creds = {}

    parser = SafeConfigParser()
    parser.read(path)

    if parser.has_option('GENERAL', 'ClusterDNSSuffix'):
        conf['ClusterDNSSuffix'] = parser.get('GENERAL', 'ClusterDNSSuffix')
    else:
        conf['ClusterDNSSuffix'] = 'cluster'

    if parser.has_option('GENERAL', 'ControllerIPAddress'):
        conf['ControllerIPAddress'] = parser.get('GENERAL', 'ControllerIPAddress')
    else:
        conf['ControllerIPAddress'] = '10.141.255.254'

    if parser.has_option('GENERAL', 'CACert'):
        conf['CACert'] = parser.get('GENERAL', 'CACert')
    else:
        log(LOG_ERR, '"CACert" must be defined in the config file "%s"' % path)
        sys.exit(1)

    if parser.has_option('GENERAL', 'CloudTTL'):
        conf['CloudTTL'] = parser.get('GENERAL', 'CloudTTL')
    else:
        conf['CloudTTL'] = '3600'

    if parser.has_option('GENERAL', 'DNSKey'):
        conf['DNSKey'] = parser.get('GENERAL', 'DNSKey')
    else:
        log(LOG_ERR, '"DNSKey" must be defined in the config file "%s"' % path)
        sys.exit(1)

    queues = parser.get('GENERAL', 'usequeues').split(',')
    log(LOG_NOTICE, 'Found the following queues "%s"' % queues)

    for q in queues:
        q_conf = {}
        nodetypes = parser.get(q, 'NodeTypes').split(',')
        q_conf['nodetypes'] = nodetypes
        log(LOG_NOTICE, 'Found the following node types "%s" in queue "%s"' % (nodetypes, q))

        for t in nodetypes:
            t_conf = {}

            if parser.has_option(t, 'provider'):
                provider = parser.get(t, 'provider')
            else:
                log(LOG_ERR, 'Section "%s" in file "%s" is missing the provider option' % (t, path))
                return False

            if not parser.has_section(provider):
                log(LOG_ERR, ('Section "%s" in "%s" refers to provider "%s". '
                              'This requires a separate "%s" section with '
                              'the CloudDriver, access_key and secret_key '
                              'options defined' %
                              (t, path, provider, provider)))
                return False

            if parser.has_option(provider, 'CloudDriver'):
                creds['CloudDriver'] = parser.get(provider, 'CloudDriver')
            else:
                log(LOG_ERR, 'Provider "%s" in file "%s" is missing the "CloudDriver" option' %
                             (provider, path))
                return False

            use_aws_role = False
            if parser.has_option(provider, 'IamRole'):
                iam_role = parser.get(provider, 'IamRole')

                if iam_role:
                    use_aws_role = True
                    url = 'http://169.254.169.254/latest/meta-data/iam/security-credentials/'
                    url += iam_role
                    creds.update(requests.get(url=url).json())

                    log(LOG_NOTICE, 'Using an IAM supplied temporary credentials')

            if not use_aws_role:
                for key in ['AccessKeyId', 'SecretAccessKey']:
                    if parser.has_option(provider, key):
                        creds[key] = parser.get(provider, key)
                    else:
                        log(LOG_ERR, 'Provider "%s" in file "%s" is missing the "%s" option' %
                                     (provider, path, key))
                        return False

            if creds['CloudDriver'] not in supportedClouds:
                log(LOG_ERR, 'Driver "%s" in section "%s" in file "%s" is not supported. Valid values are "%s"' %
                             (creds['CloudDriver'], provider, path, supportedClouds))
                return False

            if provider not in provider_creds:
                provider_creds[provider] = creds

            for key in ['VPC', 'KeyName', 'Image', 'Subnet', 'StackName',
                        'ComputeInstancesMaxNumber', 'ComputeInstanceType',
                        'SecurityGroups', 'NodeBaseName',
                        'AvailabilityZone']:
                if parser.has_option(t, key):
                    t_conf[key] = parser.get(t, key)
                else:
                    log(LOG_ERR, 'Section "%s" in file "%s" is missing the "%s" option' % (t, path, key))
                    return False

            if parser.has_option(t, 'highestnode'):
                t_conf['highestnode'] = parser.get(t, 'highestnode')
            else:
                t_conf['highestnode'] = '9999'

            if parser.has_option(t, 'TerminteOnShutdown'):
                t_conf['TerminteOnShutdown'] = parser.get(t, 'TerminteOnShutdown')
            else:
                t_conf['TerminteOnShutdown'] = 'True'

            conf['nodetypes'][t] = t_conf
            log(LOG_DEBUG, 'NodeType config "%s" successfully parsed' % t)

        conf['queues'][q] = q_conf
        log(LOG_DEBUG, 'Queue config "%s" successfully parsed' % q)

    cloud_config[path] = conf
    return True


def reversezone(ip):
    # note this assumes IPv4 and will return False if given a IPV6 address
    # this returns a list [reversezone, PTR]
    iplist = ip.split(".")

    if (len(iplist) == 4):
        # 0.168.192.in-addr.arpa.
        return [iplist[2] + '.' + iplist[1] + '.' + iplist[0] + '.in-addr.arpa.', iplist[3]]
    else:
        return False


def addDNSEntry(server, key, hostname, ip, TTL):
    log(LOG_DEBUG, 'Adding DNS record for (%s, %s) with a TTL of "%s"' %
                   (hostname, ip, TTL))

    # This uses nsupdate with the cluster key files 'key' to update
    # the cluster DNS server. assumes IPV4 needs work for IPv6
    updatescript = ('server %s\n'
                    'update delete %s\n\n'
                    'update add %s %s A %s\n\n' %
                    (server, hostname, hostname, TTL, ip))

    result = reversezone(ip)
    if result is not False:
        updatescript += ('update delete %s.%s\n\n'
                         'update add %s.%s %s IN PTR %s\n\n' %
                         (result[1], result[0],
                          result[1], result[0], TTL, hostname))

    updatescript += 'send\n'
    cmd = 'nsupdate -k %s' % key

    log(LOG_DEBUG2, 'Will apply DNS update script "%s"' % updatescript)
    log(LOG_DEBUG, 'Running command "%s"' % cmd)

    nsupdate = subprocess.Popen(cmd.split(' '), stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE, stdin=subprocess.PIPE)
    out, err = nsupdate.communicate(updatescript)
    ret = nsupdate.wait()

    if ret == 0 and err == '':
        log(LOG_NOTICE, 'DNS record added successfully')
        return True

    else:
        log(LOG_ERR, 'Failed to add DNS record: "%s"' % err)
        return False


def deleteDNSEntry(server, key, hostname, ip):
    log(LOG_DEBUG, 'Removing DNS record for (%s, %s)' % (hostname, ip))

    # This uses nsupdate with the cluster key files 'key' to update
    # the cluster DNS server. assumes IPV4 needs work for IPv6
    updatescript = ('server %s\n'
                    'update delete %s\n\n' % (server, hostname))

    result = reversezone(ip)
    if result is not False:
        updatescript += ('update delete %s.%s\n\n' % (result[1], result[0]))

    updatescript += 'send\n'
    cmd = 'nsupdate -k %s' % key

    log(LOG_DEBUG2, 'Will apply DNS update script "%s"' % updatescript)
    log(LOG_DEBUG, 'Running command "%s"' % cmd)

    nsupdate = subprocess.Popen(cmd.split(' '), stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE, stdin=subprocess.PIPE)
    out, err = nsupdate.communicate(updatescript)
    ret = nsupdate.wait()

    if ret == 0 and err == '':
        log(LOG_NOTICE, 'DNS record removed successfully')
        return True

    else:
        log(LOG_ERR, 'Failed to remove DNS record: "%s"' % err)
        return False


def elasticCloudActionEC2(hostname, action):
    log(LOG_DEBUG, 'Executing command "%s" on node "%s"' % (action, hostname))

    log(LOG_DEBUG, "building basenamelookups:")
    basenamelookup = {}

    for path in cloud_config:
        for t in cloud_config[path]['nodetypes']:
            data = {}
            data['path'] = path
            data['type'] = t
            data['highestnode'] = cloud_config[path]['nodetypes'][t]['highestnode']
            data['max_instances'] = cloud_config[path]['nodetypes'][t]['ComputeInstancesMaxNumber']
            basenamelookup[cloud_config[path]['nodetypes'][t]['NodeBaseName']] = data

    log(LOG_DEBUG2, json.dumps(basenamelookup, indent=4, sort_keys=True))

    log(LOG_DEBUG, 'finding ' + hostname + ' in the nodetypes')
    basnamematch = False
    for base in basenamelookup:
        log(LOG_DEBUG, 'Trying basename "%s"' % base)

        host_base = hostname[:-len(basenamelookup[base]['highestnode'])]
        host_suffix = hostname[-len(basenamelookup[base]['highestnode']):]

        if base == host_base:
            log(LOG_DEBUG, 'Using "%s" config for host "%s"' %
                           (base, hostname))
            if int(host_suffix) <= int(basenamelookup[base]['max_instances']):
                basnamematch = True
            else:
                log(LOG_ERR, 'Host "%s" out of range. Max allowed is "%s-1"' %
                             (hostname, basenamelookup[base]['max_instances']))

            break

    if not basnamematch:
        # hostname not matched in any availiable node type.
        # Check for range mismatches between the slurm-power config file
        # and specified cloudconfig file
        log(LOG_ERR, '"%s" not matched in any available node type.' % hostname)
        return False

    # some of these vars are horribly burried in our structure
    # lets make them local for ones we use a few times
    provider = host_config[lookuphost]['provider']

    fqdn = hostname + '.' + cloud_config[path]['ClusterDNSSuffix']

    path = basenamelookup[base]['path']
    ntype = basenamelookup[base]['type']
    ntype_conf = cloud_config[path]['nodetypes'][ntype]

    log(LOG_DEBUG, "Getting ready to create the EC2 driver")
    cls = get_driver(Provider.EC2)

    if 'Token' in provider_creds[provider]:
        token = provider_creds[provider]['Token']
    else:
        token = None

    try:
        driver = cls(provider_creds[provider]['AccessKeyId'],
                     provider_creds[provider]['SecretAccessKey'],
                     token=token,
                     region=ntype_conf['AvailabilityZone'])
    except Exception as e:
        log(LOG_ERR, 'Could not connect to AWS - "%s"' % e)
        sys.exit(1)

    # before we do anything we can grab some details from the driver
    # as we should check if subnets and instances already exist
    # for this node no matter what
    try:
        image = driver.get_image(ntype_conf['Image'])
    except Exception as e:
        log(LOG_ERR, 'Could not get AMI "%s" - "%s"' % (ntype_conf['Image'], e))
        sys.exit(1)

    try:
        keypair = driver.ex_describe_keypair(ntype_conf['KeyName'])
    except Exception as e:
        log(LOG_ERR, 'Could not get keypair "%s" - "%s"' % (ntype_conf['KeyName'], e))
        sys.exit(1)

    size = None
    subnet = None
    security_groups = []
    sizes = driver.list_sizes()
    subnets = driver.ex_list_subnets()
    all_security_groups = driver.ex_get_security_groups()

    for s in subnets:
        if s.id == ntype_conf['Subnet']:
            subnet = s

    for s in sizes:
        if s.id == ntype_conf['ComputeInstanceType']:
            size = s

    for sg_id in ntype_conf['SecurityGroups'].split(','):
        for sg in all_security_groups:
            if sg.id == sg_id:
                security_groups.append(sg.id)

    # check we have a valid subnet, log an error and exit if not
    if subnet is None:
        log(LOG_ERR, '"%s" is not a valid subnet' % ntype_conf['Subnet'])
        sys.exit(1)

    # check we have a valid size, log an error and exit if not
    if size is None:
        log(LOG_ERR, '"%s" is not a supported instance type' %
                     ntype_conf['ComputeInstanceType'])
        sys.exit(1)

    if security_groups is []:
        log(LOG_ERR, 'Supplied security groups were not found')
        sys.exit(1)
    else:
        log(LOG_NOTICE, 'Using security group "%s"' % security_groups)

    filters = {}
    filters['tag:Name'] = hostname
    filters['tag:ElasticSlurmStackname'] = ntype_conf['StackName']
    log(LOG_DEBUG2, 'Checking if an instance exists using the tags "%s"' %
                    json.dumps(filters, indent=4, sort_keys=True))
    filterednodes = driver.list_nodes(ex_filters=filters)

    if action == 'ON':
        log(LOG_NOTICE, 'Powering on instance: %s' % filterednodes)

        runningnodes = 0
        pendingnodes = 0
        startednodes = 0

        for node in filterednodes:
            if node.state != 'terminated':
                if node.state == 'running':
                    runningnodes += 1
                    startednodes += 1
                elif node.state == 'pending':
                    pendingnodes += 1
                    startednodes += 1
                else:
                    startednodes += 1

        if runningnodes == 0 and pendingnodes == 0:
            tags = {}
            tags['ElasticSlurmStackname'] = ntype_conf['StackName']
            tags['NodeType'] = ntype

            ctrl_pubkey = ''
            ssh_dir = '/root/.ssh/'

            for pk in ['id_ed25519.pub', 'id_rsa.pub', 'id_ecdsa.pub']:
                if os.path.isfile(ssh_dir + pk):
                    with open(ssh_dir + pk, 'r') as pubkey:
                        ctrl_pubkey = pubkey.read()
                    break

            if ctrl_pubkey is '':
                log(LOG_ERR, 'Could not get controller\'s public key.')
                sys.exit(1)

            ca_cert = ''
            if os.path.isfile(cloud_config[path]['CACert']):
                with open(cloud_config[path]['CACert'], 'r') as cert:
                    import base64
                    ca_cert = base64.b64encode(bytes(cert.read()))

            if ca_cert is '':
                log(LOG_ERR, 'Could not read CA cert file.')
                sys.exit(1)

            userdata = ('#cloud-config\n'
                        'preserve_hostname: false\n'
                        'fqdn: %s\n'
                        'hostname: %s\n'
                        'users:\n'
                        '  - name: root\n'
                        '    ssh_authorized_keys:\n'
                        '      - %s\n'
                        'write_files:\n'
                        '  - encoding: b64\n'
                        '    content: %s\n'
                        '    path: %s\n'
                        '    owner: root:root\n'
                        '    permissions: 644\n'
                        'runcmd:\n'
                        '  - mount %s:/opt/trinityX/site /mnt\n'
                        '  - ssh-keygen -t ed25519 -N "" -f /root/.ssh/id_ed25519\n'
                        '  - cat /root/.ssh/id_ed25519.pub >> /root/.ssh/authorized_keys\n'
                        '  - ssh-keyscan -H %s >> /root/.ssh/known_hosts\n'
                        '  - cd /mnt; ansible-playbook -l %s cloud-compute.yml -t hostname,chrony,sssd,nfs-mounts,slurm,rsyslog,zabbix_agent\n'
                        % (fqdn, 
                           hostname,
                           ctrl_pubkey, 
                           ca_cert,
                           cloud_config[path]['CACert'],
                           cloud_config[path]['ControllerIPAddress'],
                           hostname,
                           hostname))

            log(LOG_DEBUG, 'Using user-data for new instance: %s' %
                           userdata)

            metadata = {}
            log(LOG_DEBUG, 'Using metadata for new instance: %s' %
                           json.dumps(metadata, indent=4, sort_keys=True))

            try:
                nodes = driver.create_node(name=hostname,
                                           image=image,
                                           size=size,
                                           ex_keyname=keypair['keyName'],
                                           ex_subnet=subnet,
                                           ex_security_group_ids=security_groups,
                                           ex_terminate_on_shutdown=ntype_conf['TerminteOnShutdown'],
                                           ex_userdata=userdata,
                                           ex_metadata=metadata)
            except Exception as e:
                nodes = None
                log(LOG_ERR, 'Could not create instance "%s" - "%s"' % (hostname, e))

            # make sure we have just one node returned
            if isinstance(nodes, (list,)):
                # if not something went very wrong destroy them all and report an error and exit with no zero exit code
                log(LOG_ERR, 'Failed to create instance "%s". libcloud returned a list of instances, not just one. Destroying them before we stop' % hostname)

                for node in nodes:
                    log(LOG_WARN, 'destroying unwanted node instance UUID %s' % node.uuid)
                    node.destroy()

                # now exit the script here
                sys.exit(1)

            # now make sure that we have a node class (not a failure)
            elif isinstance(nodes, libcloud.compute.base.Node):
                driver.ex_create_tags(nodes, tags)

                log(LOG_NOTICE, 'Instance "%s" created successfully!' %
                                nodes.uuid)

                ip = nodes.private_ips[0]
                res = addDNSEntry(cloud_config[path]['ControllerIPAddress'],
                                  cloud_config[path]['DNSKey'],
                                  fqdn, ip, cloud_config[path]['CloudTTL'])
                if res is not True:
                    log(LOG_WARN, 'Failed to add DNS record')

                cmd = ('scontrol update NodeName=%s NodeAddr=%s' %
                       (hostname, ip))
                log(LOG_DEBUG, 'Updating slurm using command %s' % cmd)

                scontrol = subprocess.Popen(cmd.split(' '),
                                            stdout=subprocess.PIPE,
                                            stderr=subprocess.PIPE)
                out, err = scontrol.communicate()

                if err != '':
                    log(LOG_ERR, 'Slurm update failed: %s' % err)
                    return False

                log(LOG_NOTICE, 'Slurm update succeeded')

            else:
                log(LOG_ERR, 'Failed to create instance "%s". No nodes returned' % hostname)
                return False

            return True

        # if we get here then we strongly suspect that this node has been
        # started already we do NOT want to recreate it. if this is wrong
        # then this node will go down and the sysadmin will need to intervene
        log(LOG_NOTICE, 'Node is already start(ed|ing) doing nothing')
        return True

    elif action == 'OFF':
        log(LOG_NOTICE, 'Powering off instance: %s' % filterednodes)

        for node in filterednodes:
            if node.state != 'terminated':
                log(LOG_NOTICE, 'Destroying instance %s' % node.uuid)

                result = node.destroy()
                if result:
                    res = deleteDNSEntry(cloud_config[path]['ControllerIPAddress'],
                                         cloud_config[path]['DNSKey'],
                                         fqdn, node.private_ips[0])

                    if res is not True:
                        log(LOG_WARN, 'Failed to delete DNS record')

                    log(LOG_NOTICE, 'Sucessfully destroyed instance %s' %
                                    node.uuid)
                    return True

                else:
                    log(LOG_ERR, 'Failed to destroy instance %s' %
                                 node.uuid)
                    return False

        # it's possible to get here if there are no nodes to termiate,
        # actually this is fine!
        log(LOG_WARN, 'No instances match the name "%s" in the stack "%s"' %
                      (hostname, ntype_conf['StackName']))
        return True

    elif action == 'REBOOT':
        log(LOG_NOTICE, 'Rebooting instance: %s' % filterednodes)

        for node in filterednodes:
            if node.state != 'terminated':
                log(LOG_NOTICE, 'Rebooting instance %s' % node.uuid)

                result = node.reboot()
                if result:
                    log(LOG_NOTICE, 'Sucessfully rebooted instance %s' %
                                    node.uuid)
                    return True
                else:
                    log(LOG_ERR, 'Failed to reboot instance %s' %
                                 node.uuid)
                    return False
        # it's possible to get here if there are no nodes to reboot.
        # THIS is NOT ok as something has terminated our nodes unexpectedly
        log(LOG_ERR, 'No instances match the name "%s" in the stack "%s"' %
                     (hostname, ntype_conf['StackName']))
        return False

    elif action == 'STATUS':
        # non trivial as there maybe an instance is terminating AND running
        # check for running first then see if any are in another
        # non-terminated state
        print(filterednodes)
        log(LOG_NOTICE, 'Retrieved instance status for "%s": %s' %
                        (hostname, filterednodes))
        return True

    else:
        log(LOG_ERR, '"%s" is not a valid action for the EC2 provider' % action)
        return False


def elasticCloudAction(hostname, action):
    if provider_creds[host_config[lookuphost]['provider']]['CloudDriver'] == 'EC2':
        log(LOG_NOTICE, 'Using EC2 driver for instance "%s"' % hostname)
        return elasticCloudActionEC2(hostname, action)

    else:
        log(LOG_ERR, '"%s" is an unsupported cloud driver' %
                     host_config[lookuphost]['provider'])
        return False


#
# Defaults #
#

# host_remap is a 1:1 mapping of a slurm hostname into a special name,
# e.g. a VM ID for a set of statically defined VMs
host_remap = {}

# host_config is the end result of parsing the config file format=slurm-hostnam
host_config = {}

actions = ['ON', 'OFF', 'REBOOT', 'STATUS']

# cloudconfigfiles is a list of imported cloudconfig files to make sure
# we only read each once
cloudconfigfiles = []

# cloud_config is a dictionalry containing all of the config settings
# for all cloud providers. this could be one file of many but fewer is better
cloud_config = {}

# provider_creds is a dictionary of all providers
# with our security keys which is never printed in debug info
provider_creds = {}

# a list of Cloud drivers we have implemented support for from libcloud
supportedClouds = ['EC2']

# a list of node types we have implemented support for
supportedTypes = ['CUSTOM', 'ELASTIC-CLOUD']

# Log sepcific defaults
LOG_ERR = 0
LOG_WARN = 1
LOG_NOTICE = 2
LOG_DEBUG = 3
LOG_DEBUG2 = 4

LOG_LEVEL = LOG_NOTICE
LOG_TARGET = 'STDOUT'

LOG_LEVELS = ['ERR', 'WARN', 'NOTICE', 'DEBUG', 'DEBUG2']
LOG_TARGETS = ['SYSLOG', 'STDOUT', 'BOTH']


def log(level, message):
    # if the global loglevel is higher than the requested level
    # then we ouptut a log to the right place(s)
    if LOG_LEVEL >= level:
        # check LOG_TARGET to see if we send to syslog, stdout ot both
        if LOG_TARGET == 'SYSLOG':
            syslog.syslog(level, message)

        elif LOG_TARGET == 'STDOUT':
            print('%s\t%s' % (LOG_LEVELS[level], message))

        elif LOG_TARGET == 'BOTH':
            syslog.syslog(level, message)
            print('%s\t%s' % (LOG_LEVELS[level], message))


# Arguments
parser = ArgumentParser(prog='slurm-power',
                        description='power manage slurm nodes.')

parser.add_argument('action', help='Operation to be performed: on|off|reboot|status',
                    choices=['on', 'off', 'reboot', 'status'])
parser.add_argument('hostlist', help='a valid hostlist definition')

if __name__ == '__main__':
    # Load configuration file
    foundconfig = False
    configpaths = ['/etc/slurm/slurm-power.ini',
                   '/root/slurm-power.ini']

    for configpath in configpaths:
        if os.path.isfile(configpath):
            foundconfig = True
            break

    # This Script has to power on and off nodes using different methods according
    # to the definitions in slurm-power.ini. The script takes an opeartion which
    # is "ON|OFF|REBOOT|STATUS" (case insensitive) and a slurm node list definition.
    if foundconfig:
        powerconfig = SafeConfigParser()
        powerconfig.read(configpath)
    else:
        log(LOG_ERR, 'Could not find any of the config files "%s"' % configpaths)
        sys.exit(1)

    args = vars(parser.parse_args())
    action = args['action'].upper()
    host_list = args['hostlist']

    if not powerconfig.has_section('default'):
        log(LOG_ERR, '"default" section is missing in the config file')
        sys.exit(1)

    # check we have a valid action
    if action not in actions:
        log(LOG_ERR, 'First argument (action) must be one of "%s"' % actions)
        sys.exit(1)

    # process hostnames
    # expand the hostnames using hostlist modue
    try:
        hosts = hostlist.expand_hostlist(host_list)
    except hostlist.BadHostlist as e:
        log(LOG_ERR, 'Bad hostlist "%s" - "%s"' % (host_list, e))
        sys.exit(1)

    # get log settings
    # check for logType first and default to syslog if not set
    if (powerconfig.has_option('default', 'LogTarget')):
        LOG_TARGET = powerconfig.get('default', 'LogTarget').upper()

        if LOG_TARGET not in LOG_TARGETS:
            log(LOG_ERR, 'LogTarget has unknown value. Supported values are "%s"' % LOG_TARGETS)

        elif LOG_TARGET == 'SYSLOG' or LOG_TARGET == 'BOTH':
            syslog.openlog(ident='slurm-power', facility=syslog.LOG_SYSLOG)

    # check for LOG_LEVEL and default to NOTICE if not set
    if (powerconfig.has_option('default', 'LogLevel')):
        LOG_LEVEL = powerconfig.get('default', 'LogLevel').upper()

        if LOG_LEVEL not in LOG_LEVELS:
            log(LOG_ERR, 'LogLevel unknown. Supported values are "%s"' % LOG_LEVELS)

    # OK we now have out list of hostnames. we need to parse the config file
    # to find out what to do with them.
    # first check for a hostname remap and populate the dictionary as this is easy
    if (powerconfig.has_section('host-remap')):
        for host in hosts:
            if (powerconfig.has_option('host-remap', host)):
                host_remap[host] = powerconfig.get('host-remap', host)

    # now we have to parse the bulk of the config file, this is a recursive
    # call to parseSection which then calls the relevant parse<Type> function
    # if we have written it yet. each parse<type> routine should return True
    # on success or an error string which will be propogated back here and printed.
    # first check for the required default setion and complain if it's not there
    result = parse_section('default')

    if result is not True:
        log(LOG_ERR, 'Config parsing failed')
        sys.exit(1)

    # We should now have a config dictionary with all the nodes we have defined in it
    log(LOG_DEBUG, "Config File parsed")

    # now we can do something
    log(LOG_DEBUG2, 'Using the following configuration "%s"' %
                    json.dumps(host_config, indent=4, sort_keys=True))
    log(LOG_DEBUG2, 'Using the following cloud provider configuration "%s"' %
                    json.dumps(cloud_config, indent=4, sort_keys=True))

    # loop through all hostnames and lets perform the requested action
    for host in hosts:
        # this is a little more complicated than it looks
        # as we have 3 type of hostnames:
        #
        # 1) the slurm hostname (host)
        # 2) the special "default" entry we fallback onto if the node
        #    is not explicily linked to a special section in the config
        #    lookup (lookuphost)
        # 3) the hostname we optionally defined in the host_remap lookup
        #    to use in the output only (cmdhost) this is needed mainly
        #    for custom scripts

        # make the derived hostnames from slurm hostname
        if host in host_remap:
            cmdhost = host_remap[host]
        else:
            cmdhost = host

        if host in host_config:
            lookuphost = host
        else:
            lookuphost = 'default'

        if host_config[lookuphost]['type'] == 'CUSTOM':
            # now we can dig out the right command and replace $hostname if it exists in the output
            cmd = host_config[lookuphost][action].replace('$hostname', cmdhost)
            log(LOG_NOTICE, 'Running "%s"' % cmd)

            # create the pipe
            process = subprocess.Popen(cmd.split(' '),
                                       stdout=subprocess.PIPE,
                                       stderr=subprocess.PIPE)
            out, err = process.communicate()
            if err != '':
                log(LOG_WARN, 'Power %s failed with error: %s' % (action, err))

            if action == 'STATUS':
                log(LOG_NOTICE, 'Power status = %s' % out)

        elif host_config[lookuphost]['type'] == 'ELASTIC-CLOUD':
            # because there will eventually be multiple drivers we farm
            # this out to a function which will do the right thing for each cloud
            result = elasticCloudAction(host, action)

            if result is not True:
                log(LOG_WARN, '%s' % result)
                sys.exit(1)

        else:
            log(LOG_ERR, '"%s" is not implemented yet' % host_config[lookuphost]['type'])
            sys.exit(1)

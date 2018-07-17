#!/bin/bash

set -e
set -x

HELP="
####################################################
# export VM=name_of_the_vm_where_iso_will_be_built
# export SNAPSHOT=vm_snapshot_to_speed_up_build_time
# export HOST_IP=ip_of_the_vm
# export SSH_PASS=some_pass
# export GATEWAY_IP=gateway_to_acess_internet
# export DVD_DEV=/dev/sr0
# export DVD_PATH=/mnt
# ./$0
####################################################
"

for VAR in VM SNAPSHOT HOST_IP SSH_PASS GATEWAY_IP DVD_DEV DVD_PATH; do
    if [[ -z ${!VAR} ]]; then
        echo "Variable \${${VAR}} should be defined"
        echo
        echo "${HELP}"
        exit 1
    fi
done

export VIRSH_DEFAULT_CONNECT_URI=qemu+ssh://jenkins@localhost/system?no_tty=1

virsh snapshot-revert ${VM} --snapshotname ${SNAPSHOT}
virsh start ${VM}

TRIES=30
while ! sshpass -p ${SSH_PASS} ssh-copy-id root@${HOST_IP}; do
        sleep 5
    TRIES=$(( ${TRIES}-1 ))
    if [ ${TRIES} -le 0 ]; then
        echo "Timeout setting up VM ${VM1}"
        exit 255
    fi
done

cat << EOF >> hosts
buildhost ansible_host=${HOST_IP}
EOF

ansible-playbook -i hosts -u root testing/iso/controller.yml

ssh root@${HOST_IP} mkdir -p /root/trinityX

/usr/bin/rsync -avz \
    -e "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" \
    ./ root@${HOST_IP}:/root/trinityX/

ssh root@${HOST_IP} "\
    export CENTOS_CONTENT=${DVD_PATH}; \
    cd /root/trinityX; \
    make\
"

scp root@${HOST_IP}:/root/trinityX/packaging/rpm/RPMS/x86_64/trinityx-*.el7.x86_64.rpm ./
scp root@${HOST_IP}:/root/trinityX/packaging/iso/TrinityX-*.iso ./

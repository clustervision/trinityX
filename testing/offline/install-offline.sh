#!/bin/bash

# export TRIX_ISO=./TrinityX-10*.iso        - where to get iso file
# export VM1=test-ctrl01                    - name of he VMs
# export VM2=test-ctrl02
# export VM_NODE=test-node001               - name of the test compute node
# export SNAPSHOT1=01-clean                 - names of the snapshots of the VMs
# export SNAPSHOT2=01-clean
# export BOOT_DIR=/some/path                - path where libvirt can get kernel and initrd files to boot
#                                           - should be accessible both by libvirt and jenkins
# export KICKSTART_LOCAL_DIR=/some/path     - local path to store kickstart file
# export GATEWAY=10.0.0.1                   - IP of the host where are kickstart files are stored
# export HTTP_PORT=8080                     - port to access KS-file
# export HTTP_PATH="/path/"         - path on HTTP server to acess kickstart file
# export ROOT_PASSWORD=<password>   - root password of the controllers
# export VM1_if1=eth0               - network config
# export VM2_if1=eth0
# export VM1_if2=eth1
# export VM2_if2=eth1
# export VM1_if3=eth2
# export VM2_if3=eth2
# export VM1_if1_ip=10.0.0.11       - 'external' IP. Will be used to download KS-files
# export VM2_if1_ip=10.0.0.12
# export VM1_if2_ip=10.141.255.254
# export VM2_if2_ip=10.141.255.253
# export VM1_if3_ip=10.146.255.254
# export VM2_if3_ip=10.146.255.253
# export NETMASK_if1=255.255.0.0    - network masks
# export NETMASK_if2=255.255.0.0
# export NETMASK_if3=255.255.0.0
# export VM1_HOSTNAME=controller1   - hostname of ctrl1
# export VM2_HOSTNAME=controller2   - hostname of ctrl2
# export DRBD_DISK=/dev/vdb         - disk to use on each ctr for drdb
# export HA=1                       - will it be HA install or not

set -x
set -e

function cleanup() {
    fusermount -u iso
    #rm -f vm1.xml vm2.xml
}

trap cleanup EXIT

SCRIPTDIR=$(
    cd $(dirname "$0")
    pwd
)

export VIRSH_DEFAULT_CONNECT_URI=qemu+ssh://jenkins@localhost/system?no_tty=1

function copy_boot() {
    mkdir -p  iso
    fuseiso ${TRIX_ISO} iso
    cp iso/isolinux/vmlinuz    ${BOOT_DIR}/
    cp iso/isolinux/initrd.img ${BOOT_DIR}/
    cp ${TRIX_ISO} ${BOOT_DIR}/TrinityX.iso
    # Files above will be owned by qemu:qemu avter VMs start.
    # So we need to make it accessible to delete them next time
    chmod ugo+rw  ${BOOT_DIR}/* || true
}

function revert_snapshot() {
    virsh snapshot-revert ${VM1} --snapshotname ${SNAPSHOT1}
    virsh snapshot-revert ${VM2} --snapshotname ${SNAPSHOT2}
}

function modify_boot_options() {
    BOOT_ARGS_VM1="ip=${VM1_if1_ip}::${GATEWAY}:${NETMASK_if1}:${VM1_HOSTNAME}:${VM1_if1}:none inst.ks=http://${GATEWAY}:${HTTP_PORT}${HTTP_PATH}${VM1}.cfg"
    BOOT_ARGS_VM2="ip=${VM2_if1_ip}::${GATEWAY}:${NETMASK_if1}:${VM2_HOSTNAME}:${VM2_if1}:none inst.ks=http://${GATEWAY}:${HTTP_PORT}${HTTP_PATH}${VM2}.cfg"

    virsh dumpxml ${VM1} > vm1.xml
    virsh dumpxml ${VM2} > vm2.xml

    xsltproc --novalid \
        --stringparam kernel  ${BOOT_DIR}/vmlinuz \
        --stringparam initrd  ${BOOT_DIR}/initrd.img \
        --stringparam cmdline "initrd=initrd.img inst.stage2=hd:LABEL=CentOS\x207\x20x86_64 quiet BOOT_IMAGE=vmlinuz ${BOOT_ARGS_VM1}" \
        --stringparam iso  ${BOOT_DIR}/TrinityX.iso \
        ${SCRIPTDIR}/boot-kernel.xsl vm1.xml > vm1-modified.xml

    xsltproc --novalid \
        --stringparam kernel  ${BOOT_DIR}/vmlinuz \
        --stringparam initrd  ${BOOT_DIR}/initrd.img \
        --stringparam cmdline "initrd=initrd.img inst.stage2=hd:LABEL=CentOS\x207\x20x86_64 quiet BOOT_IMAGE=vmlinuz ${BOOT_ARGS_VM2}" \
        --stringparam iso  ${BOOT_DIR}/TrinityX.iso \
        ${SCRIPTDIR}/boot-kernel.xsl vm2.xml > vm2-modified.xml

    virsh define vm1-modified.xml
    virsh define vm2-modified.xml
}

function render_kickstart() {
    VM_HOSTNAME=${VM1_HOSTNAME}
    VM_if1=${VM1_if1}
    VM_if2=${VM1_if2}
    VM_if3=${VM1_if3}
    VM_if1_ip=${VM1_if1_ip}
    VM_if2_ip=${VM1_if2_ip}
    VM_if3_ip=${VM1_if3_ip}
    eval "echo \"$(cat ${SCRIPTDIR}/kickstart-offline-ctrl.templ)\"" > ${KICKSTART_LOCAL_DIR}/${VM1}.cfg

    VM_HOSTNAME=${VM2_HOSTNAME}
    VM_if1=${VM2_if1}
    VM_if2=${VM2_if2}
    VM_if3=${VM2_if3}
    VM_if1_ip=${VM2_if1_ip}
    VM_if2_ip=${VM2_if2_ip}
    VM_if3_ip=${VM2_if3_ip}
    eval "echo \"$(cat ${SCRIPTDIR}/kickstart-offline-ctrl.templ)\"" > ${KICKSTART_LOCAL_DIR}/${VM2}.cfg
}


function install_from_iso() {

    virsh start ${VM1}
    virsh start ${VM2}

    sleep 10

    # wait for installation finishes
    # According to template VM should be off

    TRIES=360
    while ! virsh domstate ${VM1} | grep -q 'shut off'; do
        sleep 10
        TRIES=$(( ${TRIES}-1 ))
        if [ ${TRIES} -le 0 ]; then
            echo "Timeout installing ${VM1}"
            exit 255
        fi
    done

    TRIES=30
    while ! virsh domstate ${VM2} | grep -q 'shut off'; do
        sleep 10
        TRIES=$(( ${TRIES}-1 ))
        if [ ${TRIES} -le 0 ]; then
            echo "Timeout installing ${VM2}"
            exit 255
        fi
    done

    # redefine XML for VM to boot from disk
    xsltproc --novalid \
        --stringparam iso  ${BOOT_DIR}/TrinityX.iso \
        ${SCRIPTDIR}/mount-iso.xsl vm1.xml > vm1-modified.xml

    xsltproc --novalid \
        --stringparam iso  ${BOOT_DIR}/TrinityX.iso \
        ${SCRIPTDIR}/mount-iso.xsl vm2.xml > vm2-modified.xml

    virsh define vm1-modified.xml
    virsh define vm2-modified.xml

    virsh start ${VM1}
    virsh start ${VM2}

}

function configure_passwordless_auth() {
    sshpass -p ${ROOT_PASSWORD} ssh-copy-id -o UserKnownHostsFile=/dev/null root@${VM1_if1_ip}
    sshpass -p ${ROOT_PASSWORD} ssh-copy-id -o UserKnownHostsFile=/dev/null root@${VM2_if1_ip}

    cat <<EOF > ssh-config
Host 10.*
    StrictHostKeyChecking no
    LogLevel ERROR
    UserKnownHostsFile /dev/null
EOF
    scp ssh-config root@${VM1_if1_ip}:/root/.ssh/config
    scp ssh-config root@${VM2_if1_ip}:/root/.ssh/config

    ssh -o UserKnownHostsFile=/dev/null root@${VM1_if1_ip} \
        "[ -f /root/.ssh/id_rsa ] || ssh-keygen -q -t rsa -f /root/.ssh/id_rsa -N ''"

    ssh -o UserKnownHostsFile=/dev/null root@${VM2_if1_ip} \
        "[ -f /root/.ssh/id_rsa ] || ssh-keygen -q -t rsa -f /root/.ssh/id_rsa -N ''"

    ssh -o UserKnownHostsFile=/dev/null root@${VM1_if1_ip} \
        "sshpass -p ${ROOT_PASSWORD} ssh-copy-id root@${VM1_if2_ip}"

    ssh -o UserKnownHostsFile=/dev/null root@${VM1_if1_ip} \
        "sshpass -p ${ROOT_PASSWORD} ssh-copy-id root@${VM2_if2_ip}"

    ssh -o UserKnownHostsFile=/dev/null root@${VM2_if1_ip} \
        "sshpass -p ${ROOT_PASSWORD} ssh-copy-id root@${VM2_if2_ip}"

    ssh -o UserKnownHostsFile=/dev/null root@${VM2_if1_ip} \
        "sshpass -p ${ROOT_PASSWORD} ssh-copy-id root@${VM1_if2_ip}"
}

function pre_install() {

cat > pre-install-script.sh << EOF
dd if=/dev/zero of=${DRBD_DISK} bs=4k count=262144
EOF
scp pre-install-script.sh root@${VM1_if1_ip}:/root/
scp pre-install-script.sh root@${VM2_if1_ip}:/root/
ssh root@${VM1_if1_ip} chmod +x /root/pre-install-script.sh
ssh root@${VM2_if1_ip} chmod +x /root/pre-install-script.sh
ssh root@${VM1_if1_ip} /root/pre-install-script.sh
ssh root@${VM2_if1_ip} /root/pre-install-script.sh
}

function install() {
    cat > install-script.sh <<EOF
#!/bin/bash
set -e
set -x
export ANSIBLE_HOST_KEY_CHECKING=False
cd /opt/clustervision/trinityx/
sed -i -e "s|/dev/sdb|${DRBD_DISK}|" group_vars/all
# sed -i -e 's|- eth2|- eth2_tmp|' controller.yml
# sed -i -e '/- eth0/d' controller.yml
# sed -i -e 's|- eth2_tmp|- eth0|' controller.yml
sed -i -e "s|local_install: false|local_install: true|" group_vars/all
if [ $HA -eq 0 ]; then
    sed -i -e "s|ha: true|ha: false|" group_vars/all
    sed -i -e "s|trix_ctrl1_hostname: controller1|trix_ctrl1_hostname: controller|" group_vars/all
fi
if [ $HA -eq 0 ]; then
cat > hosts <<EOF2
[controllers]
controller ansible_host=${VM1_if2_ip}
EOF2
else
cat > hosts <<EOF2
[controllers]
controller1 ansible_host=${VM1_if2_ip}
controller2 ansible_host=${VM2_if2_ip}
EOF2
fi
ansible-playbook -i hosts controller.yml
ansible-playbook compute.yml
EOF

    scp install-script.sh root@${VM1_if1_ip}:/root/
    ssh root@${VM1_if1_ip} chmod +x /root/install-script.sh
    ssh root@${VM1_if1_ip} /root/install-script.sh
}

function run_client_node() {
    VM_NODE_MAC=$(
        virsh domiflist ${VM_NODE} | awk '/network/{print $NF}'
    )

    cat > configure-node001.sh <<EOF
#!/bin/bash
set -e
set -x
luna group add -n compute -N cluster -o compute
luna node add -g compute
luna node change node001 --mac ${VM_NODE_MAC}
luna cluster makedns
EOF

    cat > check-node001.sh << EOF
#!/bin/bash
set -e
set -x
TRIES=120
while ! ssh -o ConnectTimeout=1 -o StrictHostKeyChecking=no root@10.141.0.1 hostname; do
    sleep 5
    TRIES=\$(( \${TRIES}-1 ))
    if [ \${TRIES} -le 0 ]; then
        echo 'Timeout connecting to node001'
        exit 255
    fi
done
EOF

    scp {configure-node001.sh,check-node001.sh} root@${VM1_if1_ip}:/root/
    ssh root@${VM1_if1_ip} chmod +x /root/{configure-node001.sh,check-node001.sh}
    ssh root@${VM1_if1_ip} /root/configure-node001.sh

    virsh destroy ${VM_NODE} || true
    virsh start ${VM_NODE}

    ssh root@${VM1_if1_ip} /root/check-node001.sh

    virsh destroy ${VM_NODE}

}


function main() {
    copy_boot
    revert_snapshot
    modify_boot_options
    render_kickstart
    install_from_iso
    configure_passwordless_auth
    pre_install
    install
    run_client_node
}

main

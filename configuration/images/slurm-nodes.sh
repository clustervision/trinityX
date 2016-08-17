#!/bin/bash

echo_info "Setting up slurm config symlinks"

rm -rf /etc/slurm && ln -s ${TRIX_SHARED}/etc/slurm /etc/slurm

echo_info "Update munge and slurmd unit files"

if [[ ! -d /etc/systemd/system/munge.service.d ]]; then
    mkdir -p /etc/systemd/system/munge.service.d

    cat > /etc/systemd/system/munge.service.d/remote-fs.conf <<-EOF 
		[Unit]
		After=remote-fs.target
		Requires=remote-fs.target
		EOF

    cat > /etc/systemd/system/munge.service.d/customexec.conf <<-EOF
		[Service]
		ExecStart=
		ExecStart=/usr/sbin/munged --key-file ${TRIX_SHARED}/etc/munge/munge.key
		EOF
fi

if [[ ! -d /etc/systemd/system/slurmd.service.d ]]; then
    mkdir -p /etc/systemd/system/slurmd.service.d

    cat > /etc/systemd/system/slurmd.service.d/customexec.conf <<-EOF
		[Unit]
		After=munge.service
		Requires=munge.service
		
		[Service]
		Restart=always
		EOF
fi 

echo_info "Enable munge and slurmd services"

systemctl enable munge.service
systemctl enable slurmd.service


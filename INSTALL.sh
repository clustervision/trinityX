#!/bin/bash

echo
echo "+------------------------------------------------------------+"
echo "|  Welcome to TrinityX                                       |"
echo "|  The system will now be prepared first...                  |"
echo "+------------------------------------------------------------+"
sleep 5
bash prepare.sh
cd site
./tui_configurator
if [ ! "$(grep 'yml check' group_vars/all.yml)" ]; then
    grep 'yml check' group_vars/all.yml.example >> group_vars/all.yml
fi
echo
echo "+------------------------------------------------------------+"
echo "|  Ansible Playbooks will now run                            |"
echo "+------------------------------------------------------------+"
sleep 5
ansible-playbook controller.yml compute*.yml

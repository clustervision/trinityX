#!/bin/bash

function add_message() {
  echo -e "$1" | fold -w70 -s >> /tmp/mesg.$$.dat
}

function show_message() {
  echo "+---------------------------------- X -------------------------------------+"
  echo "|                                                                          |"
  while read -r LINE
  do
    printf '|  %-70s  |\n' "$LINE"
  done < /tmp/mesg.$$.dat
  echo "|                                                                          |"
  echo "+--------------------------------------------------------------------------+"
  truncate -s0 /tmp/mesg.$$.dat
}

echo
add_message "Welcome to TrinityX"
add_message "The system will now be prepared first..."
show_message
echo
sleep 5
bash prepare.sh
cd site
./tui_configurator
if [ ! "$(grep 'yml check' group_vars/all.yml)" ]; then
    grep 'yml check' group_vars/all.yml.example >> group_vars/all.yml
fi
cp hosts.example hosts
echo
add_message "Ansible Playbooks will now run"
show_message
sleep 5
ansible-playbook controller.yml compute*.yml

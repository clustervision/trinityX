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

function count_down() {
  tel=$1
  while [ "$tel" -gt "0" ]; do
    echo -n "[$tel]  "
    sleep 1
    printf "\r"
    tel=$[tel-1]
  done
  echo
}

echo
add_message "Welcome to TrinityX"
add_message "The system will now be prepared first..."
show_message
count_down 10
bash prepare.sh
cd site
TRIX_VER=$(grep 'trix_version' group_vars/all.yml.example 2> /dev/null | grep -oE '[0-9\.]+' || echo '14.1')
wget https://updates.clustervision.com/revproxy/updates/trinityx/${TRIX_VER}/install/tui_configurator
./tui_configurator
TUI_RET=$?
if [ "$TUI_RET" != "0" ]; then
    add_message "The TUI configurator exited because of a problem."
    add_message "Please correct the problem and try again."
    show_message
    exit
fi
if [ ! "$(grep 'yml check' group_vars/all.yml)" ]; then
    grep 'yml check' group_vars/all.yml.example >> group_vars/all.yml
fi
cp hosts.example hosts
echo
add_message "Ansible Playbooks will now run"
show_message
count_down 5
ansible-playbook controller.yml compute*.yml

#!/bin/bash

# BIND (DNS server) configuration

echo_info 'Make named listen for requests on all interfaces'
sed -i -e 's/\(.*listen-on port 53 { \).*\( };\)/\1any;\2/' /etc/named.conf

echo_info 'Make named accept queries from all nodes that are not blocked by the firewall'
sed -i -e 's,\(.*allow-query\s.*{ \).*\( };\),\1any;\2,' /etc/named.conf

echo_info 'Enable and start named service'
systemctl enable named
systemctl start named


#!/bin/bash

display_var TRIX_CTRL{1,2}_IP

# BIND (DNS server) configuration

echo_info 'Make named listen for requests on all interfaces'
sed -i -e 's/\(.*listen-on port 53 { \).*\( };\)/\1any;\2/' /etc/named.conf

echo_info 'Make named accept queries from all nodes that are not blocked by the firewall'
sed -i -e 's,\(.*allow-query\s.*{ \).*\( };\),\1any;\2,' /etc/named.conf


echo_info "Use this DNS server as the default resolver"

sed -i "s,^\(search .*\),# \1,g" /etc/resolv.conf
sed -i "s,^\(nameserver .*\),# \1,g" /etc/resolv.conf

append_line /etc/resolv.conf "search cluster ipmi"

for RESOLVER in TRIX_CTRL{1,2}_IP; do
    if [[ -v $RESOLVER ]] ; then
        append_line /etc/resolv.conf "nameserver "${!RESOLVER}""
    fi
done


echo_info 'Setting up dhclient to avoid overwriting our configuration'

cp "${POST_FILEDIR}/dhclient-enter-hooks" /etc/dhcp


if flag_is_set BIND_FORWARDERS ; then
    echo_info 'Setting up the DNS forwarders'

    # Create a forwarders files that we will include in the main config file
    (
    echo '// ICS BIND DNS forwarders'
    echo 'forwarders {'
    for i in $BIND_FORWARDERS ; do
        echo -e "\t${i};"
    done
    echo -e '};'
    ) | tee /etc/named.forwarders.conf

    # And include it
    if ! grep -q /etc/named.forwarders.conf /etc/named.conf ; then
        sed -i '/recursion yes/a \\tinclude "/etc/named.forwarders.conf";' /etc/named.conf
    fi
fi


echo_info 'Enabling and starting the named service'
systemctl enable named
systemctl start named


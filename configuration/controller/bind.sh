#!/bin/bash

######################################################################
# TrinityX
# Copyright (c) 2016  ClusterVision B.V.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License (included with the sources) for more
# details.
######################################################################

# BIND (DNS server) configuration

function create_links_to_trix_local() {
    echo_info "Create links to to /trinity/local"
    /usr/bin/rm -rf /var/named || /usr/bin/true
    /usr/bin/rm -rf /etc/named.conf || /usr/bin/true
    /usr/bin/rm -rf /etc/named.forwarders.conf || /usr/bin/true
    /usr/bin/ln -fs /trinity/local/var/named /var/named
    /usr/bin/ln -fs /trinity/local/etc/named.conf /etc/named.conf
    /usr/bin/ln -fs /trinity/local/etc/named.forwarders.conf /etc/named.forwarders.conf
}


function move_config_to_trix_local(){
    echo_info "Move config to /trinity/local"

    if [ ! -h /etc/named.conf ]; then
        /usr/bin/rm -rf /trinity/local/etc/named.conf || /usr/bin/true
        /usr/bin/mkdir -p /trinity/local/etc
        /usr/bin/mv /etc/named.conf /trinity/local/etc/
    fi
    if [ ! -h /etc/named.forwarders.conf ]; then
        /usr/bin/rm -rf /trinity/local/etc/named.forwarders.conf || /usr/bin/true
        /usr/bin/mv /etc/named.forwarders.conf /trinity/local/etc/
    fi
    if [ ! -h /var/named ]; then
        /usr/bin/rm -rf /trinity/local/var/named || /usr/bin/true
        /usr/bin/mkdir -p /trinity/local/var
        /usr/bin/mv /var/named /trinity/local/var/
    fi
}

function basic_named_configuration(){

    echo_info 'Make named listen for requests on all interfaces'
    /usr/bin/sed -i -e 's/\(.*listen-on port 53 { \).*\( };\)/\1any;\2/' /etc/named.conf

    echo_info 'Make named accept queries from all nodes that are not blocked by the firewall'
    /usr/bin/sed -i -e 's,\(.*allow-query\s.*{ \).*\( };\),\1any;\2,' /etc/named.conf

}

function configure_resolv_conf() {

    echo_info "Use this DNS server as the default resolver"

    /usr/bin/sed -i "s,^\(search .*\),# \1,g" /etc/resolv.conf
    /usr/bin/sed -i "s,^\(nameserver .*\),# \1,g" /etc/resolv.conf

    append_line /etc/resolv.conf "search cluster ipmi"

    for RESOLVER in $TRIX_CTRL_IP $BIND_FORWARDERS; do
        append_line /etc/resolv.conf "nameserver "${RESOLVER}""
    done

}

function apply_dhcclien_hooks() {
    echo_info 'Setting up dhclient to avoid overwriting our configuration'

    /usr/bin/cp "${POST_FILEDIR}/dhclient-enter-hooks" /etc/dhcp
}

function configure_forwarders() {

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
        ) | /usr/bin/tee /etc/named.forwarders.conf

        # And include it
        if ! /usr/bin/grep -q /etc/named.forwarders.conf /etc/named.conf ; then
            /usr/bin/sed -i '/recursion yes/a \\tinclude "/etc/named.forwarders.conf";' /etc/named.conf
        fi
    fi

}

function configure_dnssec() {

    if flag_is_set BIND_DISABLE_DNSSEC ; then
        echo_info 'Disabling DNSSEC'
        /usr/bin/sed -i 's/^\([[:space:]]\+\)\(dnssec-enable.*\)/\1\/\/\2/g' /etc/named.conf
    fi

}

function configure_pacemaker() {
    echo_info 'Configure pacemaker.'
    TMPFILE=$(/usr/bin/mktemp -p /root pacemaker_named.XXXX)
    /usr/sbin/pcs cluster cib ${TMPFILE}
    /usr/sbin/pcs -f ${TMPFILE} resource delete named 2>/dev/null || /usr/bin/true
    /usr/sbin/pcs -f ${TMPFILE} resource create named systemd:named --force
    /usr/sbin/pcs -f ${TMPFILE} constraint colocation add named with Trinity
    /usr/sbin/pcs -f ${TMPFILE} constraint order start trinity-fs then start named
    /usr/sbin/pcs cluster cib-push ${TMPFILE}
}

function install_standalone() {
    basic_named_configuration
    configure_forwarders
    configure_dnssec
    if ! /usr/bin/systemctl restart named; then
        echo_error "Unable to start named."
        exit 1
    fi
    /usr/bin/systemctl enable named
    configure_resolv_conf
    apply_dhcclien_hooks
}

function install_primary() {
    install_standalone
    /usr/bin/systemctl disable named
    move_config_to_trix_local
    create_links_to_trix_local
    if ! /usr/bin/systemctl restart named; then
        echo_error "Unable to start named."
        exit 1
    fi
    configure_pacemaker
}
function install_secondary() {
    /usr/bin/systemctl disable named
    configure_resolv_conf
    apply_dhcclien_hooks
    create_links_to_trix_local
}

display_var TRIX_CTRL{1,2}_IP BIND_{FORWARDERS,DISABLE_DNSSEC}

if flag_is_unset HA; then
    install_standalone
else
    if flag_is_set PRIMARY_INSTALL; then
        install_primary
    else
        install_secondary
    fi
fi

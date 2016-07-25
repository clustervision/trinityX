echo_info "Configure firewalld."

if /usr/bin/firewall-cmd --state >/dev/null ; then
    /usr/bin/firewall-cmd --permanent --add-port=7789/tcp
    /usr/bin/firewall-cmd --reload
else
    echo_warn "Firewalld is not running. 7789/tcp should be open if you enable it later."
fi




display_var POST_FILEDIR FWD_HTTPS_PUBLIC

if flag_is_set FWD_HTTPS_PUBLIC ; then
    echo_info 'Enabling HTTPS in the public zone'
    
    # firewalld isn't running as we are inside a chroot, so we can't use
    # firewall-cmd to modify the configuration. So copy a basic zone definition.
    
    mkdir -p /etc/firewalld/zones
    cp "${POST_FILEDIR}"/public.xml /etc/firewalld/zones
fi


echo_info 'Enabling firewalld'

systemctl enable firewalld

echo_warn 'Remember to configure the zones of your interfaces via the provisioning tool!'


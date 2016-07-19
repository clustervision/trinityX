
# Chrony (time server) configuration

source "$POST_CONFIG"

modified=0


if [[ "$CHRONY_UPSTREAM" ]] ; then
    
    echo_info 'Setting up upstream time servers'
    
    # disable existing servers
    sed -i 's/^server \(.*\)/#server \1/g' /etc/chrony.conf
    
    # and add our own
    for i in ${CHRONY_UPSTREAM[@]} ; do
        echo "server $i iburst" | tee -a /etc/chrony.conf
    done
    
    modified=1
fi


if [[ "$CHRONY_SERVER" ]] && ! [[ "$CHRONY_SERVER" == 0 ]] ; then
    
    echo_info 'Enabling client access'
    
    if [[ "$CHRONY_SERVER" == 1 ]] ; then
        sed -i 's/^#allow.*/allow/g' /etc/chrony.conf
    else
        for i in ${CHRONY_SERVER[@]} ; do
            echo "allow $i" | tee -a /etc/chrony.conf
        done
    fi
    
    modified=1
fi


if (( $modified )) && ! flag_on CHROOT_INSTALL ; then
    
    echo_info 'Restarting the service'
    systemctl restart chronyd
else
    
    echo_warn 'No change requested'
fi


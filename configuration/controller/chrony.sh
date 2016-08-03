
# Chrony (time server) configuration

source "$POST_CONFIG"
source /etc/trinity.sh


display_var CHRONY_{UPSTREAM,SERVER} TRIX_CTRL{1,2}_HOSTNAME


if flag_is_set CHRONY_UPSTREAM ; then
    
    echo_info 'Setting up upstream time servers'
    
    # disable existing servers
    sed -i 's/^\(server .*\)/#\1/g' /etc/chrony.conf
    
    append_line /etc/chrony.conf '#  ----  Trinity machines  ----'
    
    # if no server was specified, this is client mode so use the controllers
    if ! [[ "$CHRONY_UPSTREAM" ]] ; then
        CHRONY_UPSTREAM="$TRIX_CTRL1_HOSTNAME $TRIX_CTRL2_HOSTNAME"
    fi
    
    # and add our own
    for i in ${CHRONY_UPSTREAM[@]} ; do
        echo "server $i iburst" | tee -a /etc/chrony.conf
    done
    
    modified=1
fi


if flag_is_set CHRONY_SERVER ; then
    
    echo_info 'Enabling client access'
    
    # start with disabling what may be leftovers from a previous installation
    sed -i 's/^\(allow.*\)/#\1/g' /etc/chrony.conf
    
    append_line /etc/chrony.conf '#  ----  Trinity machines  ----'
    
    if [[ "$CHRONY_SERVER" == 1 ]] ; then
        append_line /etc/chrony.conf "allow"
    else
        for i in ${CHRONY_SERVER[@]} ; do
            echo "allow $i" | tee -a /etc/chrony.conf
        done
    fi
fi


echo_info 'Enabling and restarting chronyd'

systemctl enable chronyd
flag_is_unset CHROOT_INSTALL && systemctl restart chronyd || true


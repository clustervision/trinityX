
# Set up the NFS mount from the nodes

display_var TRIX_{CTRL_HOSTNAME,SHARED,HOME} HOME_ON_NFS


# The shared directory is always mounted, the home dir is conditional

append_line /etc/fstab '#  ----  Trinity machines  ----'

common="nfs    defaults,rsize=32768,wsize=32768    0    0"

append_line /etc/fstab "${TRIX_CTRL_HOSTNAME}:${TRIX_SHARED}    $TRIX_SHARED    $common"

if flag_is_set HOME_ON_NFS ; then
    append_line /etc/fstab "${TRIX_CTRL_HOSTNAME}:${TRIX_HOME}    $TRIX_HOME    $common"
fi


# TrinityX shared disk resource file

resource trinity_disk {
    net {
        # Default policies after split brain is detected. This is the safe
        # behaviour, i.e. it will not destroy data and will disconnect the disks
        # if it cannot resync cleanly.
        
        after-sb-0pri discard-zero-changes;
        after-sb-1pri consensus;
        after-sb-2pri disconnect;
    }
    
    on ${TRIX_CTRL1_HOSTNAME} {
        device    ${SHARED_FS_DRBD_DEVICE};
        disk      ${SHARED_FS_DEVICE};
        address   ${SHARED_FS_CTRL1_IP:-$TRIX_CTRL1_IP}:7789;
        meta-disk internal;
    }
    
    on ${TRIX_CTRL2_HOSTNAME} {
        device    ${SHARED_FS_DRBD_DEVICE};
        disk      ${SHARED_FS_DEVICE};
        address   ${SHARED_FS_CTRL2_IP:-$TRIX_CTRL2_IP}:7789;
        meta-disk internal;
    }
}


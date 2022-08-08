{{ ansible_managed | comment }}

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

    on {{ trix_ctrl1_hostname }} {
        device    {{ drbd_ctrl1_device }};
        disk      {{ drbd_ctrl1_disk }};
        address   {{ drbd_ctrl1_ip }}:7789;
        meta-disk internal;
    }

    on {{ trix_ctrl2_hostname }} {
        device    {{ drbd_ctrl2_device }};
        disk      {{ drbd_ctrl2_disk }};
        address   {{ drbd_ctrl2_ip }}:7789;
        meta-disk internal;
    }
}


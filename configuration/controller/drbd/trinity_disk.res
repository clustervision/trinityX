resource trinity_disk {
       net {
         after-sb-0pri discard-younger-primary;
         after-sb-1pri discard-secondary;
         after-sb-2pri disconnect;
       }
       on {{ DRBD_LOCAL_HOSTNAME }} {
         device    /dev/drbd1;
         disk      {{ DRBD_DEVICE }};
         address   {{ DRBD_LOCAL_IP }}:7789;
         meta-disk internal;
       }
       on {{ DRBD_PARTNER_HOSTNAME }} {
         device    /dev/drbd1;
         disk      {{ DRBD_DEVICE }};
         address   {{ DRBD_PARTNER_IP }}:7789;
         meta-disk internal;
       }
}


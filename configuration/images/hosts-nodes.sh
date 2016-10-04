
# Setup the hosts files on the nodes
# The base Trinity X setup must have been done, and we're using /etc/trinity.sh
# for the IPs of the controllers.

display_var TRIX_CTRL{1,2,}_{HOSTNAME,IP}
flag_is_set OS_CTRL_HOSTNAME && display_var OS_CTRL_{HOSTNAME,IP}


append_line /etc/hosts '#  ----  Trinity machines  ----'

for i in TRIX_CTRL{1,2,_} OS_CTRL; do

    ctrlname=${i}_HOSTNAME

    if flag_is_set $ctrlname ; then
        ctrlname=${!ctrlname}
        ctrlip=${i}_IP ; ctrlip=${!ctrlip}

        append_line /etc/hosts "$ctrlip  $ctrlname"
    fi
done



# Setup the hosts files on the nodes
# The base Trinity X setup must have been done, and we're using /etc/trinity.sh
# for the IPs of the controllers.

display_var TRIX_CTRL{1,2,}_{HOSTNAME,IP}


append_line /etc/hosts '#  ----  Trinity machines  ----'

for i in TRIX_CTRL{1,2,_} ; do

    ctrlname=${i}_HOSTNAME

    if flag_is_set $ctrlname ; then
        ctrlname=${!ctrlname}
        ctrlip=${i}_IP ; ctrlip=${!ctrlip}

        append_line /etc/hosts "$ctrlip  $ctrlname"
    fi
done


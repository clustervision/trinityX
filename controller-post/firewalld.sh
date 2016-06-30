#!/bin/bash

# Basic configuration of firewalld, with rock 'n roll TUI!

shopt -s expand_aliases


# All the messages that we will display:
msg1='
            **** trinityX firewalld configuration ****

The default configuration of the interfaces on the controller is:

- one interface on the "public" zone, only SSH and dhclient6 allowed;
- all other interfaces in the "trusted" zone, with everything open.

For any other configuration, please tune the zones and assign the
interfaces by hand.

On all following screens, selecting "Cancel" will restart from zero.

Select "Yes" to continue with the setup, or "No" to exit.'

msg2='
Current configuration:
'

msg3='

Current zone: '

msg3X='
Current permanent zone: '

msg4='

Is this configuration correct?

'

msg5='

Should IP Masquerading / NAT be enabled in the public zone?
'


#---------------------------------------

#MYLINES=$($LINES - 3)
#MYCOLS=$($COLUMNS - 3)
# Dynamic screen sizing can lead to pretty unreadable displays, so hardcode it
# for a normal VGA terminal:
MYLINES=21
MYCOLS=77

alias mywhip="whiptail --title 'trinityX firewalld configuration'"


#---------------------------------------

# Let the user bail out if the configuration is not what (s)he wants:

mywhip --yesno "$msg1" $MYLINES $MYCOLS

(( $? )) && exit


#---------------------------------------

# Ask user input for all interfaces

iflist=$(ls /sys/class/net | grep -v lo)

while true ; do

    rm -f /tmp/ifzones.tmp && touch /tmp/ifzones.tmp
    
    for i in $iflist ; do
        
        ifdata="$(ip a show dev $i | grep 'link\|inet' | fold -w 75)"
        ifzone="$(firewall-cmd --get-zone-of-interface=${i})"
        ifpzone="$(firewall-cmd --permanent --get-zone-of-interface=${i})"
        msg="\n** INTERFACE $i\n\n${msg2}${ifdata}${msg3}${ifzone}${msg3X}${ifpzone}"
        
        mywhip --menu "$msg" $MYLINES $MYCOLS 2 \
            public "Assign to public zone" \
            trusted "Assign to trusted zone" 2>> /tmp/ifzones.tmp
        ret=$?
        
        echo

        # If ret is non-zero, the user cancelled and we go back to the beginning
        # of the while true loop
        (( $ret )) && continue 2
        # otherwise we continue looping
        
        echo " ${i}" >> /tmp/ifzones.tmp
    done
    
    # Confirm that the configuration is correct
    
    mywhip --yesno "${msg4}$(cat /tmp/ifzones.tmp)" $MYLINES $MYCOLS
    
    # if the user says yes, break out of the loop
    (( $? )) || break
done



#---------------------------------------

# Assign the zones as requested by the user

echo -e '** Assigning zones to interfaces:\n'

while read -a idata ; do
    echo "${idata[1]} -> ${idata[0]}"
    firewall-cmd --zone=${idata[0]} --change-interface=${idata[1]}
    firewall-cmd --permanent --zone=${idata[0]} --change-interface=${idata[1]}
done < /tmp/ifzones.tmp



#---------------------------------------

# Set up masquerading

if mywhip --yesno "$msg5" $MYLINES $MYCOLS ; then
    echo -e '** Enabling IP masquerading on the public interface:\n'
    firewall-cmd --zone=public --add-masquerade
    firewall-cmd --permanent --zone=public --add-masquerade
fi

echo -e '\n** Reloading firewalld'
firewall-cmd --reload


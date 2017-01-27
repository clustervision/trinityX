
######################################################################
# TrinityX
# Copyright (c) 2016  ClusterVision B.V.
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License (included with the sources) for more
# details.
######################################################################


# Check basic name configuration and setup the /etc/hosts file

# The CentOS installer doesn't update the hosts file for some reason (maybe
# because of multiple interfaces?). We have to do it ourselves or nothing will
# resolve and lots o' stuff will break.


display_var HA CTRL{1,2,}_{HOSTNAME,IP} HOSTNAME



# Are we running in an HA pair?
# Are all the values set?

if flag_is_unset HA ; then

    echo_info 'Non-HA configuration, adjusting the hostname and IP variables'
    HA=0

    if flag_is_unset CTRL1_HOSTNAME || flag_is_unset CTRL1_IP; then
        echo_error 'Fatal error: missing hostname or IP value!'
        exit 1
    fi

    CTRL_HOSTNAME=$CTRL1_HOSTNAME
    CTRL_IP=$CTRL1_IP

    unset CTRL2_HOSTNAME CTRL2_IP

else

    echo_info 'HA setup selected'

    if flag_is_unset CTRL_HOSTNAME  || flag_is_unset CTRL_IP  || \
       flag_is_unset CTRL1_HOSTNAME || flag_is_unset CTRL1_IP || \
       flag_is_unset CTRL2_HOSTNAME || flag_is_unset CTRL2_IP ; then
        
        echo_error 'Fatal error: missing hostname or IP value(s)!'
        exit 1
    fi

    if [[ "$CTRL_HOSTNAME"  == "$CTRL1_HOSTNAME" || \
          "$CTRL_HOSTNAME"  == "$CTRL2_HOSTNAME" || \
          "$CTRL1_HOSTNAME" == "$CTRL2_HOSTNAME" || \
          "$CTRL_IP"        == "$CTRL1_IP" || \
          "$CTRL_IP"        == "$CTRL2_IP" || \
          "$CTRL1_IP"       == "$CTRL2_IP" ]] ; then
          
        echo_error 'Fatal error: some of the hostnames or IPs are identical!'
        exit 1
    fi
fi


#---------------------------------------

# Get some information about the current host

mydomain="$DOMAIN"

if ! ( [[ "$mydomain" ]] ) ; then
    echo_error "Domain name not set in $POST_CONFIG"
    exit 1
fi


# Strip the hostname of the domain, if set

CTRL_HOSTNAME="${CTRL_HOSTNAME%%.*}"
CTRL1_HOSTNAME="${CTRL1_HOSTNAME%%.*}"
flag_is_set CTRL2_HOSTNAME && \
    CTRL2_HOSTNAME="${CTRL2_HOSTNAME%%.*}"


# List of active interface / IP pairs

ifips="$(ip -o -4 addr show | awk -F '[ :/]+' '/scope global/ {print $2, $4}')"

#---------------------------------------

# Identify which controller the script is running on at the moment

while read ifname myip; do
    if [ "$myip" == "$CTRL1_IP" ] ; then
        myhname=$CTRL1_HOSTNAME
        break
    elif [ "$myip" == "$CTRL2_IP" ] ; then
        myhname=$CTRL2_HOSTNAME
        break
    fi
done <<< "$ifips"     

if [ -z "$myhname" ] ; then
    echo_error "Fatal error: none of the IPs found on this node matches the configuration in $POST_CONFIG!"
    exit 1
fi

# When identified, set the hostname

echo "$myhname" > /etc/hostname
/usr/bin/hostname --file /etc/hostname

# At that point we know that:
# - we are one of the two controllers
# - one of our interfaces has the right IP
# - the floating hostname and IP are not the same as those two

# It might be the case that we have another interface up and with the floating
# IP. Should we detect that and exit? There is a valid case for not doing so: an
# engineer might have set up HA already using a separate interface, and it's up
# and running with the floating IP on our machine. It is very much a corner
# case, but let's assume that the engineer knows what (s)he's doing.


#---------------------------------------

# Loop on the pairs and write to the hosts file

append_line /etc/hosts "$TRIX_CONFIG_START"
append_line /etc/hosts "$TRIX_CONFIG_WARNING"
append_line /etc/hosts "$TRIX_CONFIG_END"

for i in CTRL{1,2} ; do

    # The CTRL2_* were unset earlier for non-HA setups
    if flag_is_set ${i}_HOSTNAME ; then

        # The joys of indirection in Bash
        # The controller names have already been stripped of their domain
        tmpname=${i}_HOSTNAME ; tmpname=${!tmpname}
        tmpip=${i}_IP ; tmpip=${!tmpip}

        if [[ "$myhname" == "$tmpname" ]] ; then

            # that's the current machine, so better put in all the interfaces
            while read -a ifip ; do

                if [[ "$myip" == "${ifip[1]}" ]] ; then
                    append_line /etc/hosts "${ifip[1]}  ${myhname}.${mydomain} ${myhname} ${myhname}-${ifip[0]}"
                else
                    append_line /etc/hosts "${ifip[1]}  ${myhname}-${ifip[0]}"
                fi
            done <<< "$ifips"

        else

            # not our machine, just write the data from the env variables
            append_line /etc/hosts "$tmpip  ${tmpname}.${mydomain} ${tmpname}"
        fi
    fi
done


# And if we're HA, we need to add the floating IP too

if flag_is_set HA ; then
    append_line /etc/hosts "$CTRL_IP  ${CTRL_HOSTNAME}.${mydomain} ${CTRL_HOSTNAME}"
else
    true    # otherwise it picks up the non-zero return of the if...
fi



# Setup the /etc/hosts file

# The CentOS installer doesn't update the hosts file for some reason (maybe
# because of multiple interfaces?). We have to do it ourselves or nothing will
# resolve and lots o' stuff will break.

source "$POST_CONFIG"


# Where are we running?

hname=$(hostname -s)
fname=$(hostname)
[[ "$hname" == "$fname" ]] && unset fname


# List of active interface / IP pairs

ifips="$(ip -o -4 addr show | awk -F '[ :/]+' '/scope global/ {print $2, $4}')"


# Did the user pass garbage?

if [[ "$HOSTS_DEFAULT_IP" ]] && ! grep -q " ${HOSTS_DEFAULT_IP}$" <<< "$ifips" ; then
    echo_warn "The IP specified in the conf file does not match any interface: $HOSTS_DEFAULT_IP"
fi


# Loop on the pairs and write to the hosts file

first=1     # are we processing the first interface?

while read -a ifip ; do
    ip="${ifip[1]%/*}"
    
    if [[ "$HOSTS_DEFAULT_IP" == $ip ]] || \
        ( ( ! [[ "$HOSTS_DEFAULT_IP" ]] ) && (( $first )) ) ; then
        echo "$ip $fname $hname ${hname}-${ifip[0]}"
    else
        echo "$ip ${hname}-${ifip[0]}"
    fi
    
    first=0
done <<< "$ifips" | column -t >> /etc/hosts


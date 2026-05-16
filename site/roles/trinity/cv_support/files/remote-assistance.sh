#!/bin/bash

trap exit_requested INT
exit_requested() {
  echo -e "manual exit requested."
  exit
}

if [ $(tput colors) -gt 7 ]
then
  color_reset="\e[0m"
  color_red="\e[31m"
  color_green="\e[32m"
fi

nc_bin=false
curl_bin=false
ssh_bin=false
extra_curl_args=" --insecure "

# check if required packages are available and set binaries accordingly
if type -p ncat 2>&1 >/dev/null
then
  nc_bin=`type -p ncat`
elif type -p nc 2>&1 >/dev/null
then
  nc_bin=`type -p nc`
else
  echo -e "${color_red}netcat not found. please install the package manually if proxy support is required. disabling for now.${color_reset}"
fi
if type -p ssh 2>&1 >/dev/null
then
  ssh_bin=`type -p ssh`
else
  echo -e "${color_red}ssh binary not found. please install the openssh client before running this again.${color_reset}"
  exit
fi
if type -p curl 2>&1 >/dev/null
then
  curl_bin=`type -p curl`
else
  echo -e "${color_red}curl binary not found. please install curl before running this again.${color_reset}"
  exit
fi

# check if default private / public key exist, otherwise prompt
privkey=none
if [ ! -f ~/.ssh/id_rsa ]
then
  echo -e "no private key found. please enter private key path. (e.g. ~/.ssh/id_rsa): "
  while [ ! -f ${privkey} ]
  do
    read privkey
    privkey=$(printf '%s' "$privkey" | sed 's/[^A-Za-z0-9._/-]/_/g')
    pubkey=${privkey}.pub
  done
else
  echo -e "private key found at ~/.ssh/id_rsa using ~/.ssh/id_rsa.pub as public key."
  privkey=~/.ssh/id_rsa
fi
pubkey=${privkey}.pub

# prompt if we want to use a proxy server, if so gather details and test http connection
if [ "$nc_bin" != false ]
then
  read -p "use http proxy server? (y/n): " use_proxy
  if [[ "$use_proxy" == "y" ]]
  then
    read -p "proxy user (empty is none): " proxy_user
    read -p "proxy password (empty is none: " proxy_password
    read -p "proxy server address including port (e.g. proxy.clustervision.com:3128): " proxy_address
    extra_curl_args="$extra_curl_args --proxy http://${proxy_address}"
    if [[ "$proxy_user" != "" ]]
    then
      extra_curl_args="$extra_curl_args --proxy-user ${proxy_user}:${proxy_pass}"
    fi
    if ! ${curl_bin} ${extra_curl_args} -s https://static.clustervision.com 2>&1 >/dev/null
    then
      echo -e "${color_red}failed to connect to https://static.clustervision.com. is the domain whitelisted in the proxy?${color_reset}"
      exit
    fi
  else
    read -p "use alternate ssh port and host (static.clustervision.com:443)? (y/n): " use_alternate_port
    use_proxy=n
  fi
else
  read -p "use alternate ssh port and host (static.clustervision.com:443)? (y/n): " use_alternate_port
  use_proxy=n
fi

# gather basic information
if [ -f /trinity/site ]
then
  projectnumber=$(cat /trinity/site)
fi
if ((BASH_VERSINFO[0] < 4))
then
  read -e -p "clustervision project number (empty if unknown): " projectnumber
  projectnumber=$(printf '%s' "$projectnumber" | sed 's/[^A-Za-z0-9._-]/_/g')
else
  read -e -i "${projectnumber}" -p "clustervision project number (empty if unknown): " projectnumber
  projectnumber=$(printf '%s' "$projectnumber" | sed 's/[^A-Za-z0-9._-]/_/g')
fi
read -n 120 -p "additional information (limited to 120 chars): " info
info=$(printf '%s' "$info" | sed 's/[^A-Za-z0-9._/-]/_/g')

# add additional arguments of connection is proxied
if [[ "$use_proxy" == "y" ]]
then
  ssh_extra_args="-o HostName=45.138.39.102 -o Port=443 -o ProxyCommand=\"${nc_bin} --proxy $proxy_address %h %p\""
elif [[ "$use_alternate_port" == "y" ]]
then
  ssh_extra_args=" -o HostName=45.138.39.102 -o Port=443 "
fi

# add public key to authorized_keys file if not yet present
if ! ${curl_bin} ${extra_curl_args} -s https://static.clustervision.com 2>&1 >/dev/null
then
  echo -e "${color_red}failed to connect to https://static.clustervision.com. is the domain whitelisted in the proxy?${color_reset}"
  exit
fi
cv_pubkey=`${curl_bin} ${extra_curl_args} -s https://static.clustervision.com/support.pub`
if ! grep -s -q "${cv_pubkey}" ~/.ssh/authorized_keys
then
  echo "${cv_pubkey}" >> ~/.ssh/authorized_keys
fi

# retrieve reverse ssh port
while true
do
  port=`${curl_bin} ${extra_curl_args} -s --user "trinityx:trinityx" -X POST -H 'Content-Type: multipart/form-data' -F pub="$(cat ${pubkey})" -F info="${info}" -F trid=${projectnumber} https://sandbox.clustervision.com/cgi-bin/keys.py | grep -E "[0-9]" | sed 's/[^0-9]*//g'`
  if ! [[ "$port" =~ [0-9]{5} ]]
  then
    echo "${color_red}invalid port number received: ${port}${color_reset}"
    exit
  fi
  echo -e "port received from sandbox is $port"
  # build the actual reverse tunnel
  eval ${ssh_bin} sandbox.clustervision.com ${ssh_extra_args} -o ServerAliveInterval=30 -o ServerAliveCountMax=10 -o User=sandbox -o RequestTTY=force -o IdentityFile=${privkey} -R $port:localhost:22
done

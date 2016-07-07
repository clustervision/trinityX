#!/usr/bin/env bash

function please_wait () {
  pid=$1
  text=$2
  delay=0.75
  cspace=$(printf "%0.s." {1..60})
  cgreen="\e[32m"
  creset="\e[0m"
  cred="\e[31m"
  while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
    printf '%-.35s %b\r' "$text $cspace " "[    ]"
    sleep $delay
    printf '%-.35s %b\r' "$text $cspace " "[ .  ]"
    sleep $delay
    printf '%-.35s %b\r' "$text $cspace " "[ .. ]"
    sleep $delay
    printf '%-.35s %b\r' "$text $cspace " "[  . ]"
    sleep $delay
  done
  printf '%-.35s %b\r\n' "$text $cspace " "[$cgreen ok $creset]"
}

function create_repository_file () {
  printf '%b\n' '[zabbix]' \
                'name=Zabbix Official Repository - $basearch' \
                'baseurl=http://repo.zabbix.com/zabbix/3.0/rhel/7/$basearch/' \
                'enabled=1' \
                'gpgcheck=1' \
                "gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-ZABBIX\n"  \
                '[zabbix-non-supported]' \
                'name=Zabbix Official Repository non-supported - $basearch' \
                'baseurl=http://repo.zabbix.com/non-supported/rhel/7/$basearch/' \
                'enabled=1' \
                'gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-ZABBIX' \
                'gpgcheck=1' > /etc/yum.repos.d/zabbix.repo
}

function add_gpg_key () {
  printf '%b\n' '-----BEGIN PGP PUBLIC KEY BLOCK-----' \
              'Version: GnuPG v1.4.5 (GNU/Linux)\n' \
              'mQGiBFCNJaYRBAC4nIW8o2NyOIswb82Xn3AYSMUcNZuKB2fMtpu0WxSXIRiX2BwC' \
              'YXx8cIEQVYtLRBL5o0JdmoNCjW6jd5fOVem3EmOcPksvzzRWonIgFHf4EI2n1KJc' \
              'JXX/nDC+eoh5xW35mRNFN/BEJHxxiRGGbp2MCnApwgrZLhOujaCGAwavGwCgiG4D' \
              'wKMZ4xX6Y2Gv3MSuzMIT0bcEAKYn3WohS+udp0yC3FHDj+oxfuHpklu1xuI3y6ha' \
              '402aEFahNi3wr316ukgdPAYLbpz76ivoouTJ/U2MqbNLjAspDvlnHXXyqPM5GC6K' \
              'jtXPqNrRMUCrwisoAhorGUg/+S5pyXwsWcJ6EKmA80pR9HO+TbsELE5bGe/oc238' \
              't/2oBAC3zcQ46wPvXpMCNFb+ED71qDOlnDYaaAPbjgkvnp+WN6nZFFyevjx180Kw' \
              'qWOLnlNP6JOuFW27MP75MDPDpbAAOVENp6qnuW9dxXTN80YpPLKUxrQS8vWPnzkY' \
              'WtUfF75pEOACFVTgXIqEgW0E6oww2HJi9zF5fS8IlFHJztNYtbQgWmFiYml4IFNJ' \
              'QSA8cGFja2FnZXJAemFiYml4LmNvbT6IYAQTEQIAIAUCUI0lpgIbAwYLCQgHAwIE' \
              'FQIIAwQWAgMBAh4BAheAAAoJENE9WOR56l7UhUwAmgIGZ39U6D2w2oIWDD8m7KV3' \
              'oI06AJ9EnOxMMlxEjTkt9lEvGhEX1bEh7bkBDQRQjSWmEAQAqx+ecOzBbhqMq5hU' \
              'l39cJ6l4aocz6EZ9mSSoF/g+HFz6WYnPAfRaYyfLmZdtF5rGBDD4ysalYG5yD59R' \
              'Mv5tNVf/CEx+JAPMhp6JCBkGRaH+xHws4eBPGkea4rGNVP3L3rA7g+c1YXZICGRI' \
              'OOH7CIzIZ/w6aFGsPp7xM35ogncAAwUD/3s8Nc1OLDy81DC6rGpxfEURd5pvd/j0' \
              'D5Di0WSBEcHXp5nThDz6ro/Vr0/FVIBtT97tmBHX27yBS3PqxxNRIjZ0GSWQqdws' \
              'Q8o3YT+RHjBugXn8CzTOvIn+2QNMA8EtGIZPpCblJv8q6MFPi9m7avQxguMqufgg' \
              'fAk7377Rt9RqiEkEGBECAAkFAlCNJaYCGwwACgkQ0T1Y5HnqXtQx4wCfcJZINKVq' \
              'kQIoV3KTQAIzr6IvbZoAn12XXt4GP89xHuzPDZ86YJVAgnfK' \
              '=+200' \
              '-----END PGP PUBLIC KEY BLOCK-----' > /etc/pki/rpm-gpg/RPM-GPG-KEY-ZABBIX
}

function install_zabbix_controller () {
  yum install zabbix-server-mysql zabbix-web-mysql
}

function main () {
  create_repository_file
  add_gpg_key
  install_zabbix_controller
}

printf '%s\n\n' 'Zabbix installation script:'
main
#!/usr/bin/env bash

readonly cp="/usr/bin/cp"

source "$POST_CONFIG"
source /etc/trinity.sh
source ${TRIX_ROOT}/trinity.shadow

function create_repository_file () {
  printf '%s %s\n' $FUNCNAME $@
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

function add_pgp_key () {
  printf '%s %s\n' $FUNCNAME $@
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

function install_zabbix_packages () {
  printf '%s %s\n' $FUNCNAME $@
  ! [[ -e /etc/pki/rpm-gpg/RPM-GPG-KEY-ZABBIX ]] && add_pgp_key
  ! [[ -e /etc/yum.repos.d/zabbix.repo ]] && create_repository_file
  for package in {zabbix-server-mysql,zabbix-web-mysql,mariadb-server}; do
    if ! yum list -q installed "$package" &>/dev/null; then yum install -q -y "$package"; fi
  done
}

function start_services () {
  printf '%s %s\n' $FUNCNAME $@
  systemctl start mariadb
  systemctl enable mariadb
}

function setup_zabbix_credentials () {
  ZABBIX_MYSQL_PASSWORD=`get_password $ZABBIX_MYSQL_PASSWORD`
  store_password ZABBIX_MYSQL_PASSWORD $ZABBIX_MYSQL_PASSWORD
  echo $ZABBIX_MYSQL_PASSWORD
  _ZABBIX_MYSQL_PASS=`get_password $ZABBIX_MYSQL_PASSWORD`
  store_password ZABBIX_MYSQL_PASSWORD $_ZABBIX_MYSQL_PASSWORD
  echo "
    ${ZABBIX_MYSQL_DB?"Variable ZABBIX_MYSQL_DB was not set"}
    ${ZABBIX_MYSQL_USER?"Variable ZABBIX_MYSQL_USER  was not set"}
    ${ZABBIX_MYSQL_PASSWORD?"Variable ZABBIX_MYSQL_PASSWORD  was not set"}
   "
}

function setup_zabbix_database () {
  printf '%s %s\n' $FUNCNAME $@
  if mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e 'use zabbix' &>/dev/null; then
    printf "Zabbix database detected, you need to erase it to continue.\n"
    read -r -p "Are you sure you want do drop that database? [y/N] " response
    case $response in
      [yY][eE][sS]|[yY])
        mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "drop database zabbix;"
        setup_zabbix_credentials
        ;;
      *)
        printf "Interrupted by user: exiting\n"
        exit 1
        ;;
    esac
  fi
  setup_zabbix_credentials
  mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "create database zabbix character set utf8 collate utf8_bin;"
  mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "grant all privileges on zabbix.* to zabbix@localhost identified by 'foopass';"
  zcat /usr/share/doc/zabbix-server-mysql-3.0.3/create.sql.gz | mysql -uroot zabbix
}

function main () {
  install_zabbix_packages
  #setup_zabbix_credentials
  #start_services
  setup_zabbix_database
}

printf '%s\n\n' 'Zabbix installation script:'
main
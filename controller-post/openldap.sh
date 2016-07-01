#!/bin/bash

# Initialize slapd's local db config and delete default db
cp /usr/share/openldap-servers/DB_CONFIG.example /var/lib/ldap/DB_CONFIG
rm -rf /etc/openldap/slapd.d/cn\=config/olcDatabase*{hdb,monitor}*

# Update configuration files
TMP_DIR=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
mkdir /tmp/$TMP_DIR

HASH=$(slappasswd -s $SLAPD_ROOT_PW)
sed -e "s,{{ rootPW }},$HASH," -e "s,{{ serverID }},$SLAPD_SERVER_ID," openldap/conf/config.ldif > /tmp/$TMP_DIR/config.ldif
sed -e "s,{{ rootPW }},$HASH," openldap/conf/local.ldif > /tmp/$TMP_DIR/local.ldif
sed -e "s,{{ rootPW }},$HASH," openldap/conf/proxy.ldif > /tmp/$TMP_DIR/proxy.ldif

# Accept TLS requests 
cp -r openldap/conf/ssl /etc/openldap/certs/
chown -R ldap. /etc/openldap/certs/ssl
chmod 600 /etc/openldap/certs/ssl/key

sed -i 's,^SLAPD_URLS=.*$,SLAPD_URLS="ldapi:/// ldap:/// ldaps:///",' /etc/sysconfig/slapd

# Start slapd
systemctl enable slapd
systemctl start slapd

# Dynamically load required schemas
# (slapd might take a moment to be fully loaded)
while :; do
    ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/cosine.ldif

    [[ $? == 0 ]] && break;
    sleep 1;
done

ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/inetorgperson.ldif
ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/nis.ldif

# Dynamically configure slapd
ldapmodify -Y EXTERNAL -H ldapi:/// -f /tmp/$TMP_DIR/config.ldif
ldapmodify -Y EXTERNAL -H ldapi:/// -f /tmp/$TMP_DIR/local.ldif
ldapmodify -Y EXTERNAL -H ldapi:/// -f /tmp/$TMP_DIR/proxy.ldif

# Setup initial local database
ldapadd -D cn=manager,dc=local -w $SLAPD_ROOT_PW -f openldap/conf/schema.ldif

# Setup obol
cp openldap/obol /usr/local/bin
chmod +x /usr/local/bin

# Cleanup
rm -rf /tmp/$TMP_DIR

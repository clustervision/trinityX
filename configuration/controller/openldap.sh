#!/bin/bash

source "$POST_CONFIG"

# Initialize slapd's local db config and delete default db
cp -v /usr/share/openldap-servers/DB_CONFIG.example /var/lib/ldap/DB_CONFIG
rm -rf /etc/openldap/slapd.d/cn\=config/olcDatabase*{hdb,monitor}*

# Update configuration files
TMP_DIR=$(mktemp -d)

SLAPD_ROOT_PW="$(get_password "$SLAPD_ROOT_PW")"

HASH=$(slappasswd -s "$SLAPD_ROOT_PW")
sed -e "s,{{ rootPW }},$HASH," -e "s,{{ serverID }},$SLAPD_SERVER_ID," "${POST_FILEDIR}"/conf/config.ldif > $TMP_DIR/config.ldif
sed -e "s,{{ rootPW }},$HASH," "${POST_FILEDIR}"/conf/local.ldif > $TMP_DIR/local.ldif
sed -e "s,{{ rootPW }},$HASH," "${POST_FILEDIR}"/conf/proxy.ldif > $TMP_DIR/proxy.ldif


# Accept TLS requests 
cp -rv "${POST_FILEDIR}"/conf/ssl /etc/openldap/certs/
chown -R ldap. /etc/openldap/certs/ssl
chmod 600 /etc/openldap/certs/ssl/key

sed -i 's,^SLAPD_URLS=.*$,SLAPD_URLS="ldapi:/// ldap:/// ldaps:///",' /etc/sysconfig/slapd

# Start slapd
systemctl enable slapd
systemctl restart slapd

# Dynamically load required schemas
# (slapd might take a moment to be fully loaded)
while true ; do
    ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/cosine.ldif

    [[ $? == 0 ]] && break;
    sleep 1;
done

ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/inetorgperson.ldif
ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/nis.ldif

# Dynamically configure slapd
ldapmodify -Y EXTERNAL -H ldapi:/// -f $TMP_DIR/config.ldif
ldapmodify -Y EXTERNAL -H ldapi:/// -f $TMP_DIR/local.ldif
ldapmodify -Y EXTERNAL -H ldapi:/// -f $TMP_DIR/proxy.ldif

# Setup initial local database
ldapadd -D cn=manager,dc=local -w $SLAPD_ROOT_PW -f "${POST_FILEDIR}"/conf/schema.ldif

# Setup obol
cp -v "${POST_FILEDIR}"/obol /usr/local/bin
chmod +x /usr/local/bin/obol

# Store the password

store_password "SLAPD_ROOT_PW" "$SLAPD_ROOT_PW"

# Cleanup
rm -rf "$TMP_DIR"


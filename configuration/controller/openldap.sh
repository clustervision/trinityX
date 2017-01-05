#!/bin/bash

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

if flag_is_set HA && flag_is_unset PRIMARY_INSTALL; then
    SLAPD_SERVER_ID=2
else
    SLAPD_SERVER_ID=1
fi

display_var HA PRIMARY_INSTALL SLAPD_SERVER_ID TRIX_CTRL{,1,2}_HOSTNAME

TMP_DIR=$(mktemp -d)

# --------------------------------------

# Backup any previous openldap setup

echo_info "Backup the current openldap setup"

mkdir -p /etc/openldap/backups
systemctl stop slapd || true

slapcat -n0 > /etc/openldap/backups/config-$(date +%F-%H-%M).ldif
slapcat -n1 > /etc/openldap/backups/localdb-$(date +%F-%H-%M).ldif 2>/dev/null

# --------------------------------------

# Flush any previous openldap setup retaining only the core config

echo_info "Flush openldap's databases and delete schemas and modules from the config"

slapcat -n0 > $TMP_DIR/stripped_conf.ldif

awk "/dn: cn=(.*,cn=schema|module.*),cn=config/ {f=1} !f; !NF {f=0}" $TMP_DIR/stripped_conf.ldif > $TMP_DIR/tmp
awk "/dn: cn=\{.\}core,cn=schema,cn=config/ {f=1} f; !NF {f=0}" $TMP_DIR/stripped_conf.ldif >> $TMP_DIR/tmp
awk "/dn: .*olcDatabase={[^0]}.*,cn=config/ {f=1} !f; !NF {f=0}" $TMP_DIR/tmp > $TMP_DIR/stripped_conf.ldif

rm -rf /var/lib/ldap/* /etc/openldap/slapd.d/*

slapadd -F /etc/openldap/slapd.d -n0 -l $TMP_DIR/stripped_conf.ldif

cp /usr/share/openldap-servers/DB_CONFIG.example /var/lib/ldap/DB_CONFIG

chown -R ldap. /etc/openldap/slapd.d/
chown -R ldap. /var/lib/ldap/

# --------------------------------------

# Prepare trinity's openldap configuration 

echo_info "Update slapd's configuration files"

SLAPD_ROOT_PW="$(get_password "$SLAPD_ROOT_PW")"
HASH=$(slappasswd -s "$SLAPD_ROOT_PW")

sed -e "s,{{ rootPW }},$HASH," "${POST_FILEDIR}"/conf/config.ldif > $TMP_DIR/config.ldif
sed -e "s,{{ rootPW }},$HASH," "${POST_FILEDIR}"/conf/local.ldif > $TMP_DIR/local.ldif
sed -e "s,{{ rootPW }},$HASH," "${POST_FILEDIR}"/conf/proxy.ldif > $TMP_DIR/proxy.ldif
sed -i "s,{{ serverID }},$SLAPD_SERVER_ID," $TMP_DIR/config.ldif

if flag_is_set HA; then

    sed -e "s,{{ rootPW }},$SLAPD_ROOT_PW," "${POST_FILEDIR}"/conf/syncrepl.ldif > $TMP_DIR/syncrepl.ldif

    if [[ "x$SLAPD_SERVER_ID" == "x1" ]]; then
        sed -i "s,{{ syncProvider }},${TRIX_CTRL2_HOSTNAME}.${TRIX_DOMAIN}," $TMP_DIR/syncrepl.ldif
    else
        sed -i "s,{{ syncProvider }},${TRIX_CTRL1_HOSTNAME}.${TRIX_DOMAIN}," $TMP_DIR/syncrepl.ldif
    fi

fi

# --------------------------------------

# Generate certificates to enable ldap over SSL

if flag_is_unset HA || flag_is_set PRIMARY_INSTALL; then

    echo_info "Generating a certificate authority for this cluster"

    mkdir -p ${TRIX_LOCAL}/certs

    openssl genrsa -out ${TRIX_LOCAL}/certs/cluster-ca.key 2048
    openssl req -x509 -new -nodes -days 5475 \
                -key ${TRIX_LOCAL}/certs/cluster-ca.key \
                -out ${TRIX_LOCAL}/certs/cluster-ca.crt \
                -subj "/C=NL/L=Amsterdam/O=ClusterVision BV./CN=clustervision.com"

fi

FQDN=$(hostname --fqdn)
echo_info "Generating and signing a certificate for ${FQDN}"

openssl req -new -nodes \
            -keyout ${TRIX_LOCAL}/certs/${FQDN}.key \
            -out ${TRIX_LOCAL}/certs/${FQDN}.csr \
            -subj "/C=NL/L=Amsterdam/O=ClusterVision BV./CN=${FQDN}"

openssl x509 -req -days 5475 \
            -in ${TRIX_LOCAL}/certs/${FQDN}.csr \
            -CA ${TRIX_LOCAL}/certs/cluster-ca.crt \
            -CAkey ${TRIX_LOCAL}/certs/cluster-ca.key \
            -out ${TRIX_LOCAL}/certs/${FQDN}.crt \
            -set_serial ${SLAPD_SERVER_ID:-1}

echo_info "Setting up certificate permissions"

chmod 600 ${TRIX_LOCAL}/certs/*.key
rm -f ${TRIX_LOCAL}/certs/*.csr
cp -f ${TRIX_LOCAL}/certs/* /etc/openldap/certs/

chown -R ldap. /etc/openldap/certs

# --------------------------------------

# Enable ldap over SSL and start the service

sed -i "s,{{ fqdn.key }},${FQDN}.key," $TMP_DIR/config.ldif
sed -i "s,{{ fqdn.crt }},${FQDN}.crt," $TMP_DIR/config.ldif

echo_info "Configuring slapd and ldap clients to use SSL"

append_line /etc/openldap/ldap.conf "TLS_CACERT   /etc/openldap/certs/cluster-ca.crt"

sed -i 's,^SLAPD_URLS=.*$,SLAPD_URLS="ldapi:/// ldaps:///",' /etc/sysconfig/slapd

echo_info "Enable and start slapd service"

systemctl enable slapd
systemctl restart slapd

# --------------------------------------

# Load trinity's openldap configuration

echo_info "Load required schemas (cosine, inetorgperson, rfc2307bis)"

# (slapd might take a moment to be fully loaded)
while true ; do
    ldapadd -Y EXTERNAL -H ldapi:/// -Q -f /etc/openldap/schema/cosine.ldif

    [[ $? == 0 ]] && break;
    sleep 1;
done

ldapadd -Y EXTERNAL -H ldapi:/// -Q -f /etc/openldap/schema/inetorgperson.ldif
ldapadd -Y EXTERNAL -H ldapi:/// -Q -f "${POST_FILEDIR}"/conf/rfc2307bis.ldif

echo_info "Load configuration into slapd"

ldapmodify -Y EXTERNAL -H ldapi:/// -Q -f $TMP_DIR/config.ldif
ldapmodify -Y EXTERNAL -H ldapi:/// -Q -f $TMP_DIR/local.ldif
ldapmodify -Y EXTERNAL -H ldapi:/// -Q -f $TMP_DIR/proxy.ldif
ldapmodify -Y EXTERNAL -H ldapi:/// -Q -f "${POST_FILEDIR}"/conf/memberof.ldif
flag_is_set HA && ldapmodify -Y EXTERNAL -H ldapi:/// -Q -f $TMP_DIR/syncrepl.ldif

echo_info "Setup the local directory's schema"

ldapadd -x -H ldaps:// -D "cn=manager,dc=local" -w $SLAPD_ROOT_PW -f "${POST_FILEDIR}"/conf/local_schema.ldif

# Store the openldap password

store_password "SLAPD_ROOT_PW" "$SLAPD_ROOT_PW"

# --------------------------------------

# Install and configure obol

echo_info "Add obol to the system"

cp "${POST_FILEDIR}"/obol /usr/local/bin
cp "${POST_FILEDIR}"/obol.conf /etc/
chmod +x /usr/local/bin/obol
chmod 600 /etc/obol.conf

sed -i "s,{{ rootPW }},$SLAPD_ROOT_PW," /etc/obol.conf

if [[ $TRIX_HOME ]]; then
    echo_info 'Update the user homes location'

    sed -i "s,# \(home =\),\1 $TRIX_HOME," /etc/obol.conf
fi

# --------------------------------------

# Cleanup the system

echo_info "Cleanup temporary files"

rm -rf "$TMP_DIR"


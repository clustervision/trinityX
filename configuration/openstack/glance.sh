#!/bin/bash

display_var TRIX_CTRL_HOSTNAME

function error {
    mysqladmin -uroot -p$MYSQL_ROOT_PASSWORD drop glance || true
    systemctl kill -s SIGKILL openstack-glance-api.service || true
    systemctl kill -s SIGKILL openstack-glance-registry.service || true
    exit 1
}

trap error ERR

source /root/.admin-openrc

GLANCE_PW="$(get_password "$GLANCE_PW")"
GLANCE_DB_PW="$(get_password "$GLANCE_DB_PW")"

echo_info "Setting up a glance database"

mysql -u root -p$MYSQL_ROOT_PASSWORD <<EOF
CREATE DATABASE glance;
GRANT ALL PRIVILEGES ON glance.* TO "glance"@"localhost" \
  IDENTIFIED BY "${GLANCE_DB_PW}";
GRANT ALL PRIVILEGES ON glance.* TO "glance"@"%" \
  IDENTIFIED BY "${GLANCE_DB_PW}";
EOF

echo_info "Creating the glance service and endpoints"
openstack user create --domain default --password $GLANCE_PW glance
openstack role add --project service --user glance admin

openstack service create --name glance   --description "OpenStack Image" image

openstack endpoint create --region RegionOne  image public http://${TRIX_CTRL_HOSTNAME}:9292
openstack endpoint create --region RegionOne  image internal http://${TRIX_CTRL_HOSTNAME}:9292
openstack endpoint create --region RegionOne  image admin http://${TRIX_CTRL_HOSTNAME}:9292

echo_info "Setting up glance configuration files"
openstack-config --set /etc/glance/glance-api.conf database connection "mysql+pymysql://glance:${GLANCE_DB_PW}@127.0.0.1/glance"
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken auth_uri http://${TRIX_CTRL_HOSTNAME}:5000
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken auth_url http://${TRIX_CTRL_HOSTNAME}:35357
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken memcached_servers ${TRIX_CTRL_HOSTNAME}:11211
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken auth_type password
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken project_domain_name default
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken user_domain_name default
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken project_name service
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken username glance
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken password $GLANCE_PW
openstack-config --set /etc/glance/glance-api.conf paste_deploy flavor keystone
openstack-config --set /etc/glance/glance-api.conf glance_store stores file,http
openstack-config --set /etc/glance/glance-api.conf glance_store default_store file
openstack-config --set /etc/glance/glance-api.conf glance_store filesystem_store_datadir /var/lib/glance/images/

openstack-config --set /etc/glance/glance-registry.conf database connection "mysql+pymysql://glance:${GLANCE_DB_PW}@127.0.0.1/glance"
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken auth_uri http://${TRIX_CTRL_HOSTNAME}:5000
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken auth_url http://${TRIX_CTRL_HOSTNAME}:35357
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken memcached_servers ${TRIX_CTRL_HOSTNAME}:11211
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken auth_type password
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken project_domain_name default
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken user_domain_name default
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken project_name service
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken username glance
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken password $GLANCE_PW
openstack-config --set /etc/glance/glance-registry.conf paste_deploy flavor keystone

echo_info "Initializing the glance database"
su -s /bin/sh -c "glance-manage db_sync" glance

echo_info "Starting glance services"
systemctl enable openstack-glance-api.service
systemctl enable openstack-glance-registry.service

systemctl start openstack-glance-api.service
systemctl start openstack-glance-registry.service

echo_info "Saving passwords"
store_password GLANCE_PW $GLANCE_PW
store_password GLANCE_DB_PW $GLANCE_DB_PW

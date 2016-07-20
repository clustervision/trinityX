#!/bin/bash

source /etc/trinity.sh
source "$POST_CONFIG"
source "${TRIX_SHADOW}"

echo_info "Configuring horizon"
CONF_FILE="/etc/openstack-dashboard/local_settings"

if [[ $(grep -cE "^OPENSTACK_HOST" $CONF_FILE) -ne 0 ]]; then
    sed -i "s,^\(OPENSTACK_HOST =\).*,\1 \"${TRIX_CTRL_HOSTNAME}\"," $CONF_FILE;
else
    echo "OPENSTACK_HOST = \"controller\"" >> $CONF_FILE;
fi

if [[ $(grep -cE "^ALLOWED_HOSTS" $CONF_FILE) -ne 0 ]]; then
    sed -i "s%^\(ALLOWED_HOSTS =\).*%\1 ${HORIZON_ALLOWED_HOSTS}%" $CONF_FILE;
else
    echo "ALLOWED_HOSTS = ${HORIZON_ALLOWED_HOSTS}" >> $CONF_FILE;
fi

if [[ $(grep -cE "^SESSION_ENGINE" $CONF_FILE) -ne 0 ]]; then
    sed -i "s,^\(SESSION_ENGINE =\).*,\1 'django.contrib.sessions.backends.cache'," $CONF_FILE;
else
    echo "SESSION_ENGINE = 'django.contrib.sessions.backends.cache'" >> $CONF_FILE;
fi

if [[ $(grep -cE "^OPENSTACK_KEYSTONE_URL" $CONF_FILE) -ne 0 ]]; then
    sed -i "s,^\(OPENSTACK_KEYSTONE_URL =\).*,\1 \"http://%s:5000/v3\" % OPENSTACK_HOST," $CONF_FILE;
else
    echo "OPENSTACK_KEYSTONE_URL = \"http://%s:5000/v3\" % OPENSTACK_HOST" >> $CONF_FILE;
fi

if [[ $(grep -cE "^OPENSTACK_KEYSTONE_MULTIDOMAIN_SUPPORT" $CONF_FILE) -ne 0 ]]; then
    sed -i "s,^\(OPENSTACK_KEYSTONE_MULTIDOMAIN_SUPPORT =\).*,\1 True," $CONF_FILE;
else
    echo "OPENSTACK_KEYSTONE_MULTIDOMAIN_SUPPORT = True" >> $CONF_FILE;
fi

if [[ $(grep -cE "^OPENSTACK_KEYSTONE_DEFAULT_DOMAIN" $CONF_FILE) -ne 0 ]]; then
    sed -i "s,^\(OPENSTACK_KEYSTONE_DEFAULT_DOMAIN =\).*,\1 'default'," $CONF_FILE;
else
    echo "OPENSTACK_KEYSTONE_DEFAULT_DOMAIN = 'default'" >> $CONF_FILE;
fi

if [[ $(grep -cE "^OPENSTACK_KEYSTONE_DEFAULT_ROLE" $CONF_FILE) -ne 0 ]]; then
    sed -i "s,^\(OPENSTACK_KEYSTONE_DEFAULT_ROLE =\).*,\1 'user'," $CONF_FILE;
else
    echo "OPENSTACK_KEYSTONE_DEFAULT_ROLE = 'user'" >> $CONF_FILE;
fi

cat >> /etc/openstack-dashboard/local_settings <<EOF
CACHES = {
    'default': {
         'BACKEND': 'django.core.cache.backends.memcached.MemcachedCache',
         'LOCATION': '${TRIX_CTRL_HOSTNAME}:11211',
    }
}

OPENSTACK_API_VERSIONS = {
    "identity": 3,
    "image": 2,
    "volume": 2,
}
EOF

echo_info "Restarting httpd and memcached"
systemctl restart httpd.service memcached.service


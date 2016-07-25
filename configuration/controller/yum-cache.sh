
# Post script to configure yum

source "$POST_CONFIG"


echo_info 'Configuring yum to keep all downloaded RPMs'

store_system_variable /etc/yum.conf keepcache 1


# Do we need to clear everything first?

if flag_is_set YUM_CLEAR_CACHE ; then

    echo_info 'Clearing the yum cache'

    yum clean all
    yum makecache
fi


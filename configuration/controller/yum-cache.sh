
# Post script to configure yum

display_var YUM_PERSISTENT_CACHE YUM_CLEAR_CACHE


# Do we want to keep all downloaded RPMs?

if flag_is_set YUM_PERSISTENT_CACHE ; then

    echo_info 'Configuring yum to keep all downloaded RPMs'

    store_system_variable /etc/yum.conf keepcache 1
fi


# Do we need to clear everything first?

if flag_is_set YUM_CLEAR_CACHE ; then

    echo_info 'Clearing the yum cache'

    yum clean all
    yum makecache fast
fi


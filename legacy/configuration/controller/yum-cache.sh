
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


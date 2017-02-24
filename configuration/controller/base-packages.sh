
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


# Base package configuration

# Exclude some packages from all future installations and updates
# Either they get in our way for the configuration, or they are plain useless

echo_info "Excluding selected packages from yum"

store_system_variable /etc/yum.conf exclude 'NetworkManager* plymouth*'


# We can't remove SELinux, but we can disable it

echo_info "Disabling SELinux"

sed -i 's/\(^SELINUX=\).*/\1disabled/g' /etc/sysconfig/selinux /etc/selinux/config
sestatus | grep -q '^SELinux status.*disabled$' || setenforce 0


echo_info "Make screen mode user-friendly"

append_line /etc/screenrc 'log on'
append_line /etc/screenrc 'termcapinfo xterm* ti@:te@'

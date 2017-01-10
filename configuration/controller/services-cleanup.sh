
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


# Cleanup unneeded services that were installed at some point or other

STOPME=( \
        wpa_supplicant \
       )


echo_info "Stopping unnecessary services"

for i in ${STOPME[@]} ; do
    systemctl stop $i
    systemctl disable $i
done

# ausidtd needs special procedure
# https://bugzilla.redhat.com/show_bug.cgi?id=973697
# https://access.redhat.com/solutions/1240243
#
/usr/bin/systemctl disable auditd
/usr/sbin/service auditd stop

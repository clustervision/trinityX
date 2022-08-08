
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


display_var POST_FILEDIR

echo_info 'Copying the custom fail2ban rules'

cp "${POST_FILEDIR}"/trinityx.conf /etc/fail2ban/jail.d/

echo_info 'Enabling and starting fail2ban'

systemctl enable fail2ban
flag_is_unset POST_CHROOT && systemctl restart fail2ban || true


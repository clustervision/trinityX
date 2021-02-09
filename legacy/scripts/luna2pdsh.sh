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


# ======================
# Luna to PDSH converter
# ======================
# This script creates the PDSH group files matching the current groups and nodes
# of Luna.
# The files matching existing groups are overwritten.

mkdir -p /etc/dsh/group

for grp in $(python -c "import luna; print ' '.join(luna.list('group'))") ; do
    echo -e "\nGroup: $grp"
    python -c "import luna; print ' '.join([i['name'] for i in luna.Group(name='${grp}').get_back_links(resolve=True) if i['collection'] == 'node'])" | \
        tr ' ' '\n' | tee /etc/dsh/group/${grp}
done

echo '
################################################################################
If you have added nodes recently you may get an error message like this:
"ssh: Could not resolve hostname nodeXXX: : No address associated with hostname"

This means that the nodes are known to Luna, but have not been discovered yet
and Luna does not know their MAC addresses (check "luna node list").

To fix it, start the nodes and make sure that they are correctly discovered by
Luna, then run "luna cluster makedns" followed by this script again.
################################################################################
'


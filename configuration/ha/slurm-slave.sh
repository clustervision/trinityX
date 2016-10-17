
######################################################################
# Trinity X
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


echo_info "Set symlink to /trinity/shared/etc/slurm"
pushd /etc
[ -d /etc/slurm.orig ] && ( echo_error "/etc/slurm.orig exists! Stopping!"; exit 1 )
/usr/bin/mv slurm{,.orig}
/usr/bin/ln -s /trinity/shared/etc/slurm slurm
popd

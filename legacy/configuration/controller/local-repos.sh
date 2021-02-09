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


# Post-installation script to set up a local RPM repository with all the
# packages required for installation.

# This is used for sites where there is no internet access, in which case all
# packages dependencies are needed, as well as for custom-built packages.


echo_info 'Copying packages and setting up the local repositories'

# TRIX_ROOT will be defined when creating images but not when installing the
# controllers. This way when installing the controllers we can use the temporary
# /root/shared/packages dir to store the local-repos. Keep in mind that this
# temporary dir will be cleaned up when critical-section-end.sh runs.

TRIX_ROOT=${TRIX_ROOT:-/root}

# On a node, those are made available via bind mount at installation time, and
# NFS later.

if  flag_is_unset POST_CHROOT ; then
    # Copy the whole tree with all local repos
    mkdir -p "${TRIX_ROOT}/shared"
    cp -pur "${POST_TOPDIR}/packages" "${TRIX_ROOT}/shared/"
fi


# For each repo file present, check that there is actually a matching repo...

for repo in "${POST_FILEDIR}"/*.repo ; do

    bname="$(basename "$repo" .repo)"

    cp "${repo}" /etc/yum.repos.d/
    sed -i "s#TRIX_ROOT#${TRIX_ROOT}#g" "/etc/yum.repos.d/${bname}.repo"

    if ! ls "${POST_TOPDIR}/packages/${bname}/repodata/"*primary.sqlite.* >/dev/null 2>&1 ; then
        echo_warn "Repository \"${bname}\" is empty, disabling the repo file."
        sed -i 's/^\(enabled=\).*/\10/g' "/etc/yum.repos.d/${bname}.repo"
    fi
done


# Disable remote repositories if requested

flag_is_set REPOS_DISABLE_REMOTE && disable_remote_repos || true


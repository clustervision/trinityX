
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



display_var HA PRIMARY_INSTALL STDCFG_TRIX_{VERSION,ROOT,HOME,IMAGES,SHARED} \
            CTRL{1,2,}_{HOSTNAME,IP}


#---------------------------------------
# Shared functions
#---------------------------------------

function setup_trinity_files {

    echo_info 'Creating the Trinity shell environment file'
    render_template "${POST_FILEDIR}"/trinity.sh > /etc/trinity.sh
    chmod 600 /etc/trinity.sh

    echo_info 'Creating the Trinity shadow files'
    install -m 600 "${POST_FILEDIR}"/trinity.shadow /etc/trinity.shadow
}



function setup_trinity_dirs {

    echo_info 'Creating the main Trinity directories'
    mkdir -p $TRIX_{HOME,IMAGES,LOCAL,SHARED}
}



function setup_local_shfile {

    echo_info 'Creating the Trinity controller-local environment file'
    cat "${POST_FILEDIR}"/trinity.local.sh /etc/trinity.local.sh | sponge /etc/trinity.local.sh
    chmod 600 /etc/trinity.local.sh
}



#---------------------------------------
# Environment variables
#---------------------------------------

TRIX_ROOT="${STDCFG_TRIX_ROOT:-/trinity}"
TRIX_VERSION="${STDCFG_TRIX_VERSION:-$(git describe --tags)}"

TRIX_HOME="${STDCFG_TRIX_HOME:-${TRIX_ROOT}/home}"
TRIX_IMAGES="${STDCFG_TRIX_IMAGES:-${TRIX_ROOT}/images}"
TRIX_LOCAL="${TRIX_ROOT}/local"
TRIX_LOCAL_APPS="${TRIX_LOCAL}/applications"
TRIX_LOCAL_MODFILES="${TRIX_LOCAL}/modulefiles"
TRIX_SHARED="${STDCFG_TRIX_SHARED:-${TRIX_ROOT}/shared}"
TRIX_SHARED_TMP="${TRIX_SHARED}/tmp"
TRIX_SHARED_APPS="${TRIX_SHARED}/applications"
TRIX_SHARED_MODFILES="${TRIX_SHARED}/modulefiles"

TRIX_SHADOW="/etc/trinity.shadow"
TRIX_SHFILE="/etc/trinity.sh"
TRIX_LOCAL_SHFILE="/etc/trinity.local.sh"

# The hosts PS checked the hostname and domain name. They are assumed to be set
# correctly.

TRIX_DOMAIN="$DOMAIN"
TRIX_CTRL1_HOSTNAME="$(basename ${CTRL1_HOSTNAME} ${TRIX_DOMAIN})"
TRIX_CTRL1_IP="${CTRL1_IP}"
TRIX_CTRL2_HOSTNAME="$(basename ${CTRL2_HOSTNAME} ${TRIX_DOMAIN})"
TRIX_CTRL2_IP="${CTRL2_IP}"
TRIX_CTRL_HOSTNAME="$(basename ${CTRL_HOSTNAME} ${TRIX_DOMAIN})"
TRIX_CTRL_IP="${CTRL_IP}"



#---------------------------------------
# Non-HA
#---------------------------------------

if flag_is_unset HA ; then

    unset {TRIX_,}CTRL2_{HOSTNAME,IP}
    TRIX_CTRL_HOSTNAME="$CTRL1_HOSTNAME"
    TRIX_CTRL_IP="$CTRL1_IP"

    setup_trinity_files

    # Make sure that we won't be picking up background noise
    sed -i 's/^TRIX_CTRL2_.*/unset {TRIX_,}CTRL2_{HOSTNAME,IP}/g' /etc/trinity.sh

    setup_trinity_dirs



#---------------------------------------
# HA primary
#---------------------------------------

elif flag_is_set PRIMARY_INSTALL ; then

    setup_trinity_files
    setup_trinity_dirs
    setup_local_shfile

    echo_info 'Setting up the base files for the secondary install'

    mkdir -p /root/secondary
    chmod 700 /root/secondary
    cp "$POST_FILEDIR"/README.txt /root/secondary



#---------------------------------------
# HA secondary
#---------------------------------------

else

    if ! ( [[ -r /root/secondary/trinity.sh ]] && \
           [[ -r /root/secondary/trinity.shadow ]] ) ; then

        # The required data isn't there already, so we need to get it over NFS

        mkdir -p /root/secondary
        chmod 700 /root/secondary

        # We'll try the floating IP, then the primary IP. If it doesn't work,
        # life is tough.

        mntdir=$(mktemp -d)

        echo_info 'Mounting the primary NFS export'

        if mount -v -t nfs ${CTRL_IP}:"${STDCFG_TRIX_LOCAL:-/trinity/local}" "$mntdir" || \
           mount -v -t nfs ${CTRL1_IP}:"${STDCFG_TRIX_LOCAL:-/trinity/local}" "$mntdir" ; then

            echo_info 'Copying secondary data from primary mount'
            rsync -ra "${mntdir}/secondary/" /root/secondary/
            umount "$mntdir"
            rm -fr "$mntdir"

        else
            echo_error 'Error mounting the primary NFS export, exiting.'
            rm -fr "$mntdir"
            exit 1
        fi
    fi


    echo_info 'Installing files from the primary installation'

    if ! install -m 600 /root/secondary/trinity.sh /etc/trinity.sh || \
       ! install -m 600 /root/secondary/trinity.shadow /etc/trinity.shadow ; then

        echo_error 'Failed installing the files, exiting.'
        exit 1
    fi


    # Make sure that the data we got from the primary isn't overloaded by the
    # variable definitions earlier in this script
    source /etc/trinity.sh
    setup_trinity_dirs
    setup_local_shfile
fi


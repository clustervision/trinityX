
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



display_var HA PRIMARY_INSTALL CTRL{,1,2}_IP \
            TRIX_{ROOT,VERSION,HOME,IMAGES,LOCAL,SHARED}


#---------------------------------------
# Shared functions
#---------------------------------------

function setup_trinity_files {

    if flag_is_unset HA ; then
        unset CTRL2_{HOSTNAME,IP}
        CTRL_HOSTNAME=CTRL1_HOSTNAME
        CTRL_IP=CTRL1_IP
    fi


    echo_info 'Creating the Trinity shell environment file'
    render_template "${POST_FILEDIR}"/trinity.sh > "$TRIX_SHFILE"
    chmod 600 "$TRIX_SHFILE"


    echo_info 'Creating the Trinity shadow files'
    install -m 600 "${POST_FILEDIR}"/trinity.shadow "$TRIX_SHADOW"
}



function setup_trinity_dirs {

    echo_info 'Creating the main Trinity directories'
    mkdir -p TRIX_{HOME,IMAGES,LOCAL,SHARED}
}



function setup_local_shfile {

    echo_info 'Creating the Trinity controller-local environment file'
    install -m 600 "${POST_FILEDIR}"/trinity.local.sh /etc/trinity.local.sh
}



#---------------------------------------
# Non-HA
#---------------------------------------

if flag_is_unset HA ; then

    setup_trinity_files
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

    setup_trinity_dirs
    setup_local_shfile


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
fi



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



display_var HA PRIMARY_INSTALL \
            TRIX_{HOME,IMAGES,LOCAL,LOCAL_APPS,LOCAL_MODFILES} \
            TRIX_{SHARED,SHARED_TMP,SHARED_APPS,SHARED_MODFILES}



#---------------------------------------
# Shared functions
#---------------------------------------

function create_trinity_tree {

    echo_info 'Creating the Trinity directory tree'

    mkdir -p $TRIX_{HOME,IMAGES,LOCAL,LOCAL_APPS,LOCAL_MODFILES} \
             $TRIX_{SHARED,SHARED_TMP,SHARED_APPS,SHARED_MODFILES}
}



function fix_trinity_files {

    echo_info 'Fixing the environment and shadow files'

    mv /etc/trinity.sh "${TRIX_SHARED}/trinity.sh"
    mv /etc/trinity.shadow "${TRIX_LOCAL}/trinity.shadow"

    ln -f -s "${TRIX_SHARED}/trinity.sh" /etc/trinity.sh

    store_variable /etc/trinity.sh TRIX_SHFILE "${TRIX_SHARED}/trinity.sh"
    store_variable /etc/trinity.sh TRIX_SHADOW "${TRIX_LOCAL}/trinity.shadow"
}



#---------------------------------------
# Non-HA, HA primary
#---------------------------------------

if flag_is_unset HA ; then

    create_trinity_tree
    fix_trinity_files



#---------------------------------------
# HA primary
#---------------------------------------

elif flag_is_set PRIMARY_INSTALL ; then

    create_trinity_tree

    echo_info 'Preparing the data for the secondary install'
    cp /etc/trinity.sh{,adow} /root/secondary
    mv /root/secondary "${TRIX_LOCAL}"

    fix_trinity_files



#---------------------------------------
# HA secondary
#---------------------------------------

else

    echo_info 'Fixing the environment and shadow files'

    rm -fr /etc/trinity.sh /etc/trinity.shadow
    ln -f -s "${TRIX_SHARED}/trinity.sh" /etc/trinity.sh


    echo_info 'Cleaning up the data from the primary installation'
    rm -fr /root/secondary
fi


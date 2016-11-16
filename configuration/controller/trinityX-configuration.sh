
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


# TrinityX standard controller post-installation script
# This sets up the Trinity tree, the shared Trinity files.


display_var HA PRIMARY_INSTALL TRIX_{ROOT,VERSION,HOME,IMAGES,LOCAL,SHARED}


# Fallback values for configuration parameters

TRIX_ROOT="${STDCFG_TRIX_ROOT:-/trinity}"
TRIX_VERSION="${STDCFG_TRIX_VERSION:-unknown}"

# All the paths and locations

TRIX_HOME="${STDCFG_TRIX_HOME:-${TRIX_ROOT}/home}"
TRIX_IMAGES="${STDCFG_TRIX_IMAGES:-${TRIX_ROOT}/images}"
TRIX_LOCAL="${STDCFG_TRIX_LOCAL:-${TRIX_ROOT}/local}"
TRIX_LOCAL_APPS="${TRIX_LOCAL}/applications"
TRIX_LOCAL_MODFILES="${TRIX_LOCAL}/modulefiles"
TRIX_SHARED="${STDCFG_TRIX_SHARED:-${TRIX_ROOT}/shared}"
TRIX_SHARED_TMP="${TRIX_SHARED}/tmp"
TRIX_SHARED_APPS="${TRIX_SHARED}/applications"
TRIX_SHARED_MODFILES="${TRIX_SHARED}/modulefiles"

TRIX_SHADOW="${TRIX_ROOT}/trinity.shadow"
TRIX_SHFILE="${TRIX_SHARED}/trinity.sh"
TRIX_LOCAL_SHFILE="/etc/trinity.local.sh"



#---------------------------------------
# HA secondary
#---------------------------------------

if ( flag_is_set HA && flag_is_unset PRIMARY_INSTALL ) ; then

    echo_info "Creating the symlink to the Trinity shell environment file"
    ln -f -s "$TRIX_SHFILE" /etc/trinity.sh

    exit
fi



#---------------------------------------
# Non-HA and HA primary
#---------------------------------------

echo_info "Creating the Trinity directory tree"

for i in TRIX_{HOME,IMAGES,LOCAL,LOCAL_APPS,LOCAL_MODFILES} \
         TRIX_{SHARED,SHARED_TMP,SHARED_APPS,SHARED_MODFILES} ; do
    mkdir -p "${!i}"
done


#---------------------------------------

echo_info "Creating the Trinity shell environment file"

cat > "$TRIX_SHFILE" << EOF
# TrinityX environment file
# Do not modify!

TRIX_VERSION="$TRIX_VERSION"
TRIX_ROOT="$TRIX_ROOT"

TRIX_HOME="${TRIX_HOME}"
TRIX_IMAGES="${TRIX_IMAGES}"
TRIX_LOCAL="${TRIX_LOCAL}"
TRIX_LOCAL_APPS="${TRIX_LOCAL_APPS}"
TRIX_LOCAL_MODFILES="${TRIX_LOCAL_MODFILES}"
TRIX_SHARED="${TRIX_SHARED}"
TRIX_SHARED_TMP="${TRIX_SHARED_TMP}"
TRIX_SHARED_APPS="${TRIX_SHARED_APPS}"
TRIX_SHARED_MODFILES="${TRIX_SHARED_MODFILES}"

TRIX_SHADOW="${TRIX_SHADOW}"
TRIX_SHFILE="${TRIX_SHFILE}"
TRIX_LOCAL_SHFILE="${TRIX_LOCAL_SHFILE}"

EOF
    
chmod 600 "$TRIX_SHFILE"
ln -f -s "$TRIX_SHFILE" /etc/trinity.sh


#---------------------------------------

echo_info "Creating the Trinity shadow file"

echo '# TrinityX shadow file' > "$TRIX_SHADOW"
chmod 600 "$TRIX_SHADOW"


#---------------------------------------

# And finally, write the controller host names and IP to trinity.sh

echo_info 'Writing controller IP and hostnames to the environment file'

if flag_is_unset HA ; then
    unset CTRL2_{HOSTNAME,IP}
    CTRL_HOSTNAME=CTRL1_HOSTNAME
    CTRL_IP=CTRL1_IP
fi

for i in CTRL{,1,2}_{HOSTNAME,IP} ; do
    if flag_is_set $i ; then
        store_variable "${TRIX_SHFILE}" "TRIX_$i" "${!i}"
    else
        # make sure that we're not picking up background noise
        append_line "${TRIX_SHFILE}" "unset $i TRIX_$i"
    fi
done


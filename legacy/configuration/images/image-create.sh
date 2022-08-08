
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


# Create the initial compute image

display_var NODE_{IMG_NAME,INITIAL_RPM,IMG_CONFIG,HOST_REPOS,HOST_CACHE}


#---------------------------------------

# Are we dealing with an absolute path here?

if [[ "$NODE_IMG_NAME" =~ ^/.* ]] ; then
    TARGET="$NODE_IMG_NAME"
else
    TARGET="${TRIX_IMAGES}/${NODE_IMG_NAME:-unknown-$(date +%F-%H-%M)}"
fi

TARGET_BASE="$(basename "$TARGET")"
TARGET_SHADOW="${TARGET}.shadow"


echo_info 'Creating the compute image directory'

mkdir -p "$TARGET"


echo_info 'Creating the shadow file for the image'

cat > "$TARGET_SHADOW" << EOF
# Trinity image shadow file
# $TARGET_BASE
EOF

chmod 600 "$TARGET_SHADOW"

echo_info "Creating the local Trinity directory tree"

for i in TRIX_{LOCAL,LOCAL_APPS,LOCAL_MODFILES,SHARED} ; do
    mkdir -p "${TARGET}/${!i}"
done


echo_info 'Setting up the /etc/trinity.sh symlink'

mkdir -p "${TARGET}/etc"
ln -s "$TRIX_SHFILE" "${TARGET}/etc/trinity.sh"


#---------------------------------------

echo_info 'Initializing the RPM dabatase in the target directory'

rpm --root "$TARGET" --initdb
rpm --root "$TARGET" -ivh "${POST_FILEDIR}/${NODE_INITIAL_RPM:-centos-release\*.rpm}"


if flag_is_set NODE_HOST_CACHE ; then
    echo_info 'Using the host cache'
    cp "${POST_FILEDIR}/yum.conf" "${TARGET}/etc"
    NODE_HOST_CACHE=1
else
    echo_info 'Not using the host cache'
    NODE_HOST_CACHE=0
fi

export NODE_HOST_{CACHE,REPOS}


#---------------------------------------

# If we have a a configuration to apply to the image, do it.


if flag_is_set NODE_IMG_CONFIG ; then
    echo_info "Applying configuration to the new image: $NODE_IMG_CONFIG"

    "$CONFIGSCRIPT" ${VERBOSE+-v} ${QUIET+-q} ${DEBUG+-d} ${NOCOLOR+--nocolor} \
        --chroot "$TARGET" "${NODE_IMG_CONFIG}"

else
    echo_error 'No image configuration file specified!'
    exit 1
fi


#---------------------------------------

echo_info 'Setting the root password'

# Hack to work around an open issue between SELinux and chpasswd -R
# https://bugzilla.redhat.com/show_bug.cgi?id=1321375

if grep -q 'selinuxfs.*rw' /etc/mtab ; then
    mount -o ro,remount /sys/fs/selinux/
    remount_selinuxfs=1
fi

root_pw="$(get_password "$NODE_ROOT_PW")"
echo "root:$root_pw" | chpasswd -R "${TARGET}"

# must be remounted rw or sshd doesn't work anymore!
if flag_is_set remount_selinuxfs ; then
    mount -o rw,remount /sys/fs/selinux/
fi

# And save the password to the image's shadow file
ALT_SHADOW="$TARGET_SHADOW" store_password "IMG_ROOT_PW" "$root_pw"


#---------------------------------------

echo_info 'Setting the timezone'

cp -P /etc/localtime "${TARGET}/etc"


#---------------------------------------

# And a final bit of cleanup

if flag_is_unset NODE_HOST_CACHE ; then
    command yum -q --installroot "$TARGET" clean all
fi

echo_info "Path of the new image: \"$TARGET\""

unset NODE_HOST_{CACHE,REPOS}


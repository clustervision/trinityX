
# Create the initial compute image

display_var NODE_{IMG_NAME,INITIAL_RPM,HOST_REPOS,YUM_UPDATE,IMG_CONFIG}


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

echo_info 'Setting up the yum configuration'

cp "${POST_FILEDIR}/yum.conf" "${TARGET}/etc"


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

echo_info "Path of the new image: \"$TARGET\""


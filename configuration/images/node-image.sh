
# Create the initial compute image

# Adaptation of the upstream Luna readme
# https://github.com/dchirikov/luna

source /etc/trinity.sh
source "$POST_CONFIG"


#---------------------------------------

# Are we dealing with an absolute path here?

if [[ "$NODE_IMG_NAME" =~ ^/.* ]] ; then
    TARGET="$NODE_IMG_NAME"
else
    TARGET="${TRIX_IMG_ROOT:-/trinity/images}/${NODE_IMG_NAME:-unknown-$(date +%F-%H-%M)}"
fi


echo_info 'Creating the compute image directories'

mkdir -p "$TARGET"


#---------------------------------------

echo_info 'Initializing the RPM dabatase in the target directory'

rpm --root "$TARGET" --initdb
rpm --root "$TARGET" -ivh "${POST_FILEDIR}/centos-release\*.rpm"


echo_info 'Setting up the yum configuration'

cp "${POST_FILEDIR}/yum.conf" "${TARGET}/etc"


#---------------------------------------

# To avoid having to copy a lot of stuff between the host and the chroot image,
# we use filesystem binding. We have a lot of things to bind because we don't
# want to have copies of RPMs in the image -- everything has to go to the host
# so that we can have a copy later if we want. It makes things a bit more
# complex, so hang on.

# "$TRIX_ROOT"      ->  for the local repos + trinity.sh*
# "$POST_TOPDIR"    ->  for the configuration scripts and files
# /var/cache/yum    ->  to keep a copy of all the RPMs on the host, and speed up
#                       installation of multiple images

DIRLIST=( \
            "$TRIX_ROOT" \
            "$POST_TOPDIR" \
            /var/cache/yum \
        )


echo_info 'Binding the host directories'

for dir in "${DIRLIST[@]}" ; do

    mkdir -p "${TARGET}/$dir"
    mount --bind "$dir" "${TARGET}/$dir"
done

[[ "$QUIET" ]] || { echo ; mount | grep "$TARGET" ; }


#---------------------------------------

echo_info 'Installing the core groups'

if [[ -r "${POST_FILEDIR}/target.grplist" ]] ; then 
    yum --installroot="$TARGET" -y groupinstall $(grep -v '^#\|^$' "${POST_FILEDIR}/target.grplist")
fi


echo_info 'Installing additional packages'

if [[ -r "${POST_FILEDIR}/target.pkglist" ]] ; then
    yum --installroot="$TARGET" -y install $(grep -v '^#\|^$' "${POST_FILEDIR}/target.pkglist")
fi


#---------------------------------------

if [[ $"NODE_IMG_CONFIG" ]] ; then
    
    echo_info 'Running the configuration tool on the new image'
    
    chroot "${TARGET}" "${POST_TOPDIR}/configuration/configure.sh" \
            ${VERBOSE+-v}  ${QUIET+-q} ${DEBUG+-d} ${NOCOLOR+--nocolor} \
           "${POST_TOPDIR}/configuration/${NODE_IMG_CONFIG}"
fi

    
#---------------------------------------

echo_info 'Unbinding the host directories'

#############
#  WARNING  #
#############
# They must be unbound in reverse order, or interesting times will ensue.
# Why? Two words: recursive bind.

dirnum=${#DIRLIST[@]}

while (( $dirnum )) ; do
    (( dirnum-- ))
    sleep 1s
    umount "${TARGET}/${DIRLIST[$dirnum]}"
done

[[ "$QUIET" ]] || mount | grep "$TARGET"


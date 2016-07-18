
# Create the initial compute image

# Started as an adaptation of the upstream Luna readme
# https://github.com/dchirikov/luna

source /etc/trinity.sh
source "$POST_CONFIG"


#---------------------------------------

# Are we dealing with an absolute path here?

if [[ "$NODE_IMG_NAME" =~ ^/.* ]] ; then
    TARGET="$NODE_IMG_NAME"
else
    TARGET="${TRIX_IMAGES}/${NODE_IMG_NAME:-unknown-$(date +%F-%H-%M)}"
fi


echo_info 'Creating the compute image directories'

mkdir -p "$TARGET"


#---------------------------------------

echo_info 'Initializing the RPM dabatase in the target directory'

rpm --root "$TARGET" --initdb
rpm --root "$TARGET" -ivh "${POST_FILEDIR}/${NODE_INITIAL_RPM:-centos-release\*.rpm}"


echo_info 'Setting up the yum configuration'

cp "${POST_FILEDIR}/yum.conf" "${TARGET}/etc"


#---------------------------------------

# To avoid having to copy a lot of stuff between the host and the chroot image,
# we use filesystem binding. We have a lot of things to bind because we don't
# want to have copies of RPMs in the image -- everything has to go to the host
# so that we can have a copy later if we want. It makes things a bit more
# complex, so hang on.

# First, some functions to make our life easier


# Bind an arbitrary number of mounts under a common root dir

# Syntax: bind_mounts root_dir dir1 [dir2 ...]

function bind_mounts {

    if (( $# < 2 )) ; then
        echo_warn 'bind_mounts: not enough arguments, no mount done.'
        return 1
    fi

    root_dir="$1"
    shift
    
    for dir in "$@" ; do
        mkdir -p "${root_dir}/${dir}"
        mount --bind "$dir" "${root_dir}/${dir}"
    done
}


# Unbind mounts

#  !!! WARNING !!!
# They must be unbound in reverse order of binding, or interesting times will
# ensue! Why? Two words: recursive bind.

# Syntax: unbind_mounts root_dir dir1 [dir2 ...]
# It will unbind in the order dirN .. dir1

function unbind_mounts {
    
    if (( $# < 2 )) ; then
        echo_warn 'unbind_mounts: not enough arguments, no umount done.'
        return 1
    fi
    
    root_dir="$1"
    shift
    
    for i in $(seq $# -1 1) ; do
        umount "${root_dir}/${@:$i:1}"
    done
}


#---------------------------------------

# Now for the directories themselves

# Used for the duration of the configuration:
# ===========================================
# "$TRIX_ROOT"      ->  for the local repos + trinity.sh*
# "$POST_TOPDIR"    ->  for the configuration scripts and files
# /var/cache/yum    ->  to keep a copy of all the RPMs on the host, and speed up
#                       installation of multiple images

# Used only for the initial package installation:
# ===============================================
# /etc/yum.repos.d  ->  so that we have the same repos until post script setup


DIRLIST=( \
            "$TRIX_ROOT" \
            "$POST_TOPDIR" \
            /var/cache/yum \
        )

DIRTMPLIST=( \
                /etc/yum.repos.d \
           )


echo_info 'Binding the host directories'

bind_mounts "$TARGET" "${DIRLIST[@]}"
bind_mounts "$TARGET" "${DIRTMPLIST[@]}"


#---------------------------------------

echo_info 'Installing the core groups'

if [[ -r "${POST_FILEDIR}/target.grplist" ]] ; then 
    yum --installroot="$TARGET" -y groupinstall $(grep -v '^#\|^$' "${POST_FILEDIR}/target.grplist")
fi


echo_info 'Installing additional packages'

if [[ -r "${POST_FILEDIR}/target.pkglist" ]] ; then
    yum --installroot="$TARGET" -y install $(grep -v '^#\|^$' "${POST_FILEDIR}/target.pkglist")
fi


# And unbind the temporary directories

unbind_mounts "$TARGET" "${DIRTMPLIST[@]}"


#---------------------------------------

if [[ "$NODE_IMG_CONFIG" ]] ; then
    
    echo_info 'Running the configuration tool on the new image'
    
    chroot "${TARGET}" "${POST_TOPDIR}/configuration/configure.sh" \
            ${VERBOSE+-v}  ${QUIET+-q} ${DEBUG+-d} ${NOCOLOR+--nocolor} \
           "${POST_TOPDIR}/configuration/${NODE_IMG_CONFIG}"
fi

    
#---------------------------------------

echo_info 'Unbinding the host directories'

unbind_mounts "$TARGET" "${DIRLIST[@]}"


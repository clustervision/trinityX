
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


# Support functions
# Those do not belong in the common_functions.sh file as they are used only by
# the installer code.


#---------------------------------------

# Directory binding functions
# Bind mounts are used to configure the images. Through bind mount we give
# access to directories that would otherwise be available over NFS, as well as 

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
        (( $? )) && flag_is_set VERBOSE && echo_warn "Failed to bind $dir"
    done
}


# Unbind mounts

#  !!! WARNING !!!
# They must be unbound in reverse order of binding, or interesting times will
# ensue! Why? Two words: recursive bind.

# Syntax: unbind_mounts root_dir dir1 .. dirN
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
        (( $? )) && flag_is_set VERBOSE && echo_warn "Failed to unbind ${@:$i:1}"
    done
}


#---------------------------------------



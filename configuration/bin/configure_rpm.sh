
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


# RPM management functions
# They exist as a workaround for the way RPM and yum behave in some specific
# cases. They are not supposed to be used by any post script, only by the
# installer.


# This file is made to be sourced by the scripts that require it, and not
# executed directly. Exit if executed.

if [[ "$BASH_SOURCE" == "$0" ]] ; then
    echo 'This file must be sourced by another script, not executed.' >&2
    exit 1
fi


#---------------------------------------

# Check if all packages have been installed.
# The names of those that have not been installed are printed on stdout.
# The return code is 0 if all have been installed, something else otherwise.

# Syntax: not_installed <pkg_names ...>

function not_installed {

    ret=0
    for pkg in "$@" ; do
        if ! command rpm -q --quiet ${POST_CHROOT:+--root "${POST_CHROOT}"} "$pkg" ; then
            # OK, not installed. But is it a feature?
            # This is an ugly thing that depends on the output format of yum.
            # When a package is installed, its repo name is @ + the name of the
            # repo from which it was installed. So if any package in the
            # provides list has an @ in the repo name, it's installed and the
            # feature is available.
            if ! command yum -q ${POST_CHROOT:+--installroot "${POST_CHROOT}"} provides "$pkg" | \
                    grep -q '^Repo *: @' ; then
                (( ret++ ))
                echo -n "$pkg "
            fi
        fi
    done

    return $ret
}


#---------------------------------------

# Install packages and check
#
# This is basically a workaround for an annoying behaviour of yum. When
# installing multiple packages, there are cases when some packages fail to
# install but yum doesn't return an error code. I haven't narrowed down the
# exact cause for that behaviour, but the bottom line is: you can't trust yum's
# error code.
#
# So install the packages, then check if they have been installed.

# Syntax: install_packages <pkg_names ...>

function install_packages {

    # if no parameter, return
    (( $# )) || return 0

    pkgs="$@"

    ret=0
    yum -y ${POST_CHROOT:+--installroot "${POST_CHROOT}"} install $pkgs

    echo_info 'Checking if packages were installed correctly'
    pkgs="$(not_installed $pkgs)"
    ret=$?

    # did something fail to install?
    if (( ret )) ; then
        echo_warn 'The following packages failed to install:' $pkgs
    fi

    return $ret
}



#---------------------------------------

# Install package groups and check

# Syntax: install_groups <group_names ...>

function install_groups {

    # if no parameter, return
    (( $# )) || return 0

    # There's no reliable way to manage groups. No way to tell if they were
    # installed, no way to extract their contents easily, etc. So we just
    # install them and hope that it will work...

    yum -y ${POST_CHROOT:+--installroot "${POST_CHROOT}"} groupinstall "$@"
}



#---------------------------------------

# Remove packages

# Syntax: remove_packages <pkg_names ...>

function remove_packages {

    # if no parameter, return
    (( $# )) || return 0

    yum -y ${POST_CHROOT:+--installroot "${POST_CHROOT}"} remove "$@"
}



#---------------------------------------

# Install RPM files and check

# This is a workaround for an annoying behaviour of rpm. If you try to install
# an rpm file that is already installed, it will return an error code.

# This function needs to be exported as it is required to install RPMs that are
# in some post script private directories.

# Syntax: install_rpm_files <rpm_names ...>

function install_rpm_files {

    # if no parameter, return
    (( $# )) || return 0

    # Note: no need to mount the yum repos in the images to install RPM files

    ret=0
    for pkg in "$@" ; do
        if command rpm -U --test ${POST_CHROOT:+--root "${POST_CHROOT}"} "$pkg" ; then
            rpm -Uvh ${POST_CHROOT:+--root "${POST_CHROOT}"} "$pkg"
            (( ret += $? ))
        fi
    done

    return $ret
}


typeset -fx install_rpm_files


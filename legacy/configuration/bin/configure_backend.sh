
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


# Backend helper script for configure.sh
# It requires the environment setup by configure.sh, as well as the common
# functions available. In other words, don't even think of sourcing this file
# from outside of configure.sh


#---------------------------------------

# Go through a single post script
# This function is called by the apply_config code below, once of each of the
# post scripts included in that config.

# Syntax: run_one_script script_name

# All the other parameters are environment variables.

function run_one_script {

    [[ -r "${POSTDIR}/${1}.grplist" ]] && POST_GRPLIST="${POSTDIR}/${1}.grplist"
    [[ -r "${POSTDIR}/${1}.pkglist" ]] && POST_PKGLIST="${POSTDIR}/${1}.pkglist"
    [[ -r "${POSTDIR}/${1}.remlist" ]] && POST_REMLIST="${POSTDIR}/${1}.remlist"
    [[ -r "${POSTDIR}/${1}.sh" ]] && POST_SCRIPT="${POSTDIR}/${1}.sh"
    [[ -x "${POSTDIR}/${1}" ]] && export POST_FILEDIR="${POSTDIR}/${1}"


    # Do we have something? Anything? If not, kick the user.

    if flag_is_unset POST_GRPLIST && flag_is_unset POST_PKGLIST && \
       flag_is_unset POST_REMLIST && flag_is_unset POST_SCRIPT ; then

        echo_error "The name \"${1}\" doesn't match any file in the POSTDIR directory: ${POSTDIR}"
        return 1
    fi


    # First, bind mount the directories for yum
    (( ${#DIRYUMLIST[@]} )) && bind_mounts "$POST_CHROOT" "${DIRYUMLIST[@]}"

    # First install the groups

    if flag_is_set POST_GRPLIST ; then
        echo_progress "Installing package groups: $POST_GRPLIST"
        if ! install_groups $(grep -v '^#\|^$' "$POST_GRPLIST") ; then
            echo_error 'Error during group installation'
            (( ${#DIRYUMLIST[@]} )) && unbind_mounts "$POST_CHROOT" "${DIRYUMLIST[@]}"
            return 1
        fi
    elif flag_is_set VERBOSE; then
        echo_info "No package group file found for post script $1"
    fi

    # If we have a removal list, go through it. We don't check anything here,
    # this is a best effort situation.

    if flag_is_set POST_REMLIST ; then
        echo_progress "Removing packages: $POST_REMLIST"
        remove_packages $(grep -v '^#\|^$' "$POST_REMLIST")
    elif flag_is_set VERBOSE ; then
        echo_info "No removal file found for post script $1"
    fi

    # And finally the single packages

    if flag_is_set POST_PKGLIST ; then
        echo_progress "Installing packages: $POST_PKGLIST"
        if ! install_packages $(grep -v '^#\|^$' "$POST_PKGLIST") ; then
            echo_error 'Error during package installation'
            (( ${#DIRYUMLIST[@]} )) && unbind_mounts "$POST_CHROOT" "${DIRYUMLIST[@]}"
            return 1
        fi
    elif flag_is_set VERBOSE ; then
        echo_info "No package file found for post script $1"
    fi

    # Unbind those directories
    (( ${#DIRYUMLIST[@]} )) && unbind_mounts "$POST_CHROOT" "${DIRYUMLIST[@]}"



    # Then run the script if we have one
    if flag_is_set POST_SCRIPT ; then

        ret=0
        echo_progress "Running post script: $POST_SCRIPT"

        # bind the configuration directories
        (( ${#DIRCFGLIST[@]} )) && bind_mounts "$POST_CHROOT" "${DIRCFGLIST[@]}"

        # We're doing a little hackaroo here.
        # The idea is that some variables in POST_CONFIG may include some
        # variables defined in trinity.sh. They shouldn't, but they may. So load
        # trinity.sh first, then POST_CONFIG.
        # And because some misguided attempt at broken configuration may
        # redefine the trinity.sh variables in POST_CONFIG, re-source trinity.sh
        # afterwards... And because we have no guarantee that trinity.sh exists
        # already, those have to be conditional.
        # Finally, load the local shfile and password file if they exist.
        # We cannot do all of that at a higher level because each script may
        # modify the .sh{,adow} files, and subsequent scripts will need the
        # updated versions in their environment.

        ${POST_CHROOT:+chroot "${POST_CHROOT}"} \
            bash ${DEBUG+-x} ${HARDSTOP+-e -o pipefail} -c "
            [[ -r /etc/trinity.sh ]] && source /etc/trinity.sh
            source \"$POST_CONFIG\"
            [[ -r /etc/trinity.sh ]] && source /etc/trinity.sh
            [[ -r /etc/trinity.local.sh ]] && source /etc/trinity.local.sh
            [[ -r \"\$TRIX_SHADOW\" ]] && source \"\$TRIX_SHADOW\"
            source \"$POST_SCRIPT\" "

        ret=$?

        # unbind the configuration directories
        (( ${#DIRCFGLIST[@]} )) && unbind_mounts "$POST_CHROOT" "${DIRCFGLIST[@]}"

    elif flag_is_set VERBOSE ; then
        echo_info "No shell script found for post script $1"
    fi

    unset POST_{GRPLIST,PKGLIST,REMLIST,SCRIPT,FILEDIR}
    return $ret
}



#---------------------------------------

# Main loop to run for a single configuration file
# It can apply a configuration file as is, or a set of handpicked PS within the
# environment defined in the configuration file.

# Syntax: apply_config configuration_file [handpicked post scripts]

function apply_config {

    echo_header "CONFIGURATION FILE: $1"

    POST_CONFIG="$(readlink -e "$1")"
    POST_CONFDIR="$(dirname "$POST_CONFIG")"

    if [[ -r "$POST_CONFIG" ]] ; then
        source "$POST_CONFIG"
        export POST_CONFIG
        export POST_CONFDIR
    else
        echo_error "Fatal error: configuration file \"$POST_CONFIG\" doesn't exist."
        exit 1
    fi

    # Is a chroot required?

    if flag_is_set CHROOT_REQUIRED && \
       flag_is_unset CHROOT && flag_is_unset POST_CHROOT ; then
        echo_error 'This configuration can only be applied to a chroot image!'
        exit 1
    fi

    # If we're running only handpicked scripts, we need to shift

    if (( $# > 1 )) ; then
        shift
        echo_info "Processing only the following scripts: $@"
        POSTLIST=( "$@" )
    fi

    # Did the user even specify some post scripts?

    if ! (( ${#POSTLIST[@]} )) ; then
        echo_warn 'No post script specified!'
        return 1
    fi

    # Deal with variations in the POSTDIR values:
    # - defined and absolute -> nothing to do
    # - defined and relative -> prepend POST_CONFDIR
    # - undefined -> same as the conf file without extension

    if flag_is_set POSTDIR ; then
        if ! [[ "$POSTDIR" =~ ^/.* ]] ; then
            POSTDIR="${POST_CONFDIR}/${POSTDIR}"
        fi
    else
        POSTDIR="${POST_CONFDIR}/$(basename "$POST_CONFIG" .cfg)"
    fi

    if ! [[ -d "$POSTDIR" && -x "$POSTDIR" ]] ; then
        echo_error "Configuration directory doesn't exist: $POSTDIR"
        exit 1
    fi

    
    # Do we have to install in a chroot? If yes, we have to check a few things.
    # CHROOT is the variable from the configuration file, POST_CHROOT is the one
    # from the command line.

    if flag_is_set CHROOT || flag_is_set POST_CHROOT ; then

        # If POST_CHROOT is defined via the command line, we don't want to
        # override it with the config value: cmd line overrides the config, not
        # the other way around. So:
        POST_CHROOT="${POST_CHROOT:-$CHROOT}"
        POST_CHROOT="$(readlink -e "$POST_CHROOT")"

        if (( $? )) || ! [[ -d "$POST_CHROOT" && -x "$POST_CHROOT" ]] ; then
            echo_error "Chroot directory doesn't exist: $POST_CHROOT"
            exit 1
        else
            echo_info "Using the following directory for chroot: $POST_CHROOT"
            export POST_CHROOT
        fi

        # If we're setting up an image in a chroot, we need to know the path of
        # the existing Trinity install. So we need to load trinity.sh.
        # If the file doesn't exist, this will fail miserably. That's the
        # intended behaviour, as we need a full Trinity controller install.

        source /etc/trinity.sh

        # And we have to set up the directories that need to be bind mounted

        # Used during the shell script execution:
        # =======================================
        # "$TRIX_ROOT"      ->  for the local repos + trinity.sh*
        # "$POST_TOPDIR"    ->  for the configuration scripts and files
        
        # Used only for package installation, if NODE_HOST_REPOS is enabled:
        # ==================================================================
        # /etc/yum.repos.d  ->  so that we have the same repos until post script setup
        # /etc/pki/rpm-gpg  ->  so that the repo keys are available

        # Used for both:
        # ==============
        # /dev              ->  for urandom and such

        # Used for both, if NODE_HOST_CACHE is enabled:
        # =============================================
        # /var/cache/yum    ->  to keep a copy of all the RPMs on the host, and speed up
        #                       installation of multiple images. Because of the
        #                       yum update PS, it must be available for the scripts.


        DIRCFGLIST=( "$TRIX_ROOT" \
                     "$POST_TOPDIR" \
                     /dev )

        DIRYUMLIST=( /dev )

        # those are only bound on request
        if flag_is_set NODE_HOST_REPOS ; then
            DIRYUMLIST+=( /etc/yum.repos.d \
                          /etc/pki/rpm-gpg )
        fi

        if flag_is_set NODE_HOST_CACHE ; then
            DIRCFGLIST+=( /var/cache/yum )
            DIRYUMLIST+=( /var/cache/yum )
        fi

        export DIRCFGLIST DIRYUMLIST
    fi


    # Alright, so at that point we have our config file loaded, and we know
    # where the directory is, we can loop over the list of post scripts.

    for post in "${POSTLIST[@]}" ; do

        # Tweak the environment variables on the fly

        # Defining a new variable
        if [[ "$post" =~ ^\+.* ]] ; then
            tmpvar=${post#+}
            echo_progress "Setting the environment variable: $tmpvar"
            if flag_is_unset $tmpvar ; then
                declare -x -- ${tmpvar}=1
            fi
            continue

        # Unsetting an existing variable, if not set on the command line
        elif [[ "$post" =~ ^-.* ]] ; then
            tmpvar=${post#-}
            echo_progress "Unsetting the environment variable: $tmpvar"
            if flag_is_set $tmpvar && [[ "${!tmpvar}" != "keep" ]] ; then
                unset -- $tmpvar
            fi
            continue
        fi


        while true ; do

            run_one_script "$post"
            ret=$?

            if (( ret == 0 )) ; then
                if flag_is_unset STEP ; then
                    break
                else
                    echo_warn "Stepping mode: please select the next step."
                fi

            else
                echo_error "Error during post script: $post"
            fi

            rce_prompt $ret
            case $? in
                2 )     break       # continue
                        ;;
                3 )     exit 1      # exit
                        ;;
                * )     continue    # retry
            esac
        done
    done

    # Clean up the environment variables to avoid background noise later
    unset POST_CONFIG POST_CONFDIR POSTDIR DIRCFGLIST DIRYUMLIST POST_CHROOT
    echo_footer
}


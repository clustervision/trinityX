
# Backend helper script for configure.sh
# It requires the environment setup by configure.sh, as well as the common
# functions available. In other words, don't even think of sourcing this file
# from outside of configure.sh


#---------------------------------------

# Go through a single post script

# Syntax: run_one_script script_name

# All the other parameters are environment variables.

function run_one_script {

    [[ -r "${POSTDIR}/${1}.grplist" ]] && POST_GRPLIST="${POSTDIR}/${1}.grplist"
    [[ -r "${POSTDIR}/${1}.pkglist" ]] && POST_PKGLIST="${POSTDIR}/${1}.pkglist"
    [[ -r "${POSTDIR}/${1}.sh" ]] && POST_SCRIPT="${POSTDIR}/${1}.sh"
    [[ -x "${POSTDIR}/${1}" ]] && export POST_FILEDIR="${POSTDIR}/${1}"

    # Do we have something? Anything? If not, kick the user.

    if flag_is_unset POST_GRPLIST && flag_is_unset POST_PKGLIST && \
       flag_is_unset POST_SCRIPT ; then

        echo_error "The name \"${1}\" doesn't match any file in the POSTDIR directory: ${POSTDIR}"
        return 1
    fi

    ret=0


    # Start with installing the groups and packages if we have lists

    if flag_is_set POST_GRPLIST ; then
        echo_progress "Installing package groups: $POST_GRPLIST"
        install_groups $(grep -v '^#\|^$' "$POST_GRPLIST")
        ret=$?
    elif flag_is_set VERBOSE; then
        echo_info "No package group file found: $POST_GRPLIST"
    fi

    # Take a break if the installation didn't go right
    if (( $ret )) ; then
        echo_error_wait "Error during package group installation: $POST_GRPLIST"
    fi


    if flag_is_set POST_PKGLIST ; then
        echo_progress "Installing packages: $POST_PKGLIST"
        install_packages $(grep -v '^#\|^$' "$POST_PKGLIST")
        ret=$?
    elif flag_is_set VERBOSE ; then
        echo_info "No package file found: $POST_PKGLIST"
    fi

    # Take a break if the installation didn't go right
    if (( $ret )) ; then
        echo_error_wait "Error during package installation: $POST_PKGLIST"
    fi


    ret=0

    # Then run the script if we have one
    if flag_is_set POST_SCRIPT ; then

        echo_progress "Running post script: $POST_SCRIPT"

        # We're doing a little hackaroo here.
        # The idea is that some variables in POST_CONFIG may include some
        # variables defined in trinity.sh. They shouldn't, but they may. So load
        # trinity.sh first, then POST_CONFIG.
        # And because some misguided attempt at broken configuration may
        # redefine the trinity.sh variables in POST_CONFIG, re-source trinity.sh
        # afterwards... And because we have no guarantee that trinity.sh exists
        # already, those have to be conditional.
        # Finally, load the password file if it exists already.
        # We cannot do all of that at a higher level because each script may
        # modify the .sh{,adow} files, and subsequent scripts will need the
        # updated versions in their environment.

        bash ${DEBUG+-x} ${HARDSTOP+-e -o pipefail} -c "
            [[ -r /etc/trinity.sh ]] && source /etc/trinity.sh
            source \"$POST_CONFIG\"
            [[ -r /etc/trinity.sh ]] && source /etc/trinity.sh
            [[ -r \"\$TRIX_SHADOW\" ]] && source \"\$TRIX_SHADOW\"
            source \"$POST_SCRIPT\" "

        ret=$?

    elif flag_is_set VERBOSE ; then
        echo_info "No post script found: $POST_SCRIPT"
    fi

    # Take a break if the script returned an error code
    if (( $ret )) ; then
        echo_error_wait "Error during post script: $POST_SCRIPT"
    fi

    unset POST_{GRPLIST,PKGLIST,SCRIPT,FILEDIR}
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
        echo_error_wait "Fatal error: configuration file \"$POST_CONFIG\" doesn't exist."
        return 1
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
        echo_error_wait "Configuration directory doesn't exist: $POSTDIR"
        return 1
    fi

    #echo_info "Configuration directory: $POSTDIR"
    #echo_info "List of post scripts: ${POSTLIST[@]}"

    # Do we have to install in a chroot? If yes, we have to check a few things.
    if flag_is_set CHROOT || flag_is_set POST_CHROOT ; then
        # if POST_CHROOT is defined on the command line, we don't want to
        # override it with the config value: cmd line overrides the config, not
        # the other way around. So:
        POST_CHROOT="${POST_CHROOT:-$CHROOT}"
        POST_CHROOT="$(readlink -e "$POST_CHROOT")"

        if (( $? )) || ! [[ -d "$POST_CHROOT" && -x "$POST_CHROOT" ]] ; then
            echo_error_wait "Chroot directory doesn't exist: $POST_CHROOT"
            return 1
        else
            export POST_CHROOT
        fi
    fi

    # Alright, so at that point we have our config file loaded, and we know
    # where the directory is, we can loop over the list of post scripts.

    for post in "${POSTLIST[@]}" ; do
        run_one_script "$post"
    done

    unset POST_CONFIG POST_CONFDIR POSTDIR
    echo_footer
}


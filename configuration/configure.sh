#!/bin/bash

# Trinity X configuration tool


################################################################################
##
## NO ACCESS TO THE SHARED FUNCTIONS YET
##
################################################################################


# Right number of arguments?

function syntax_exit {
    echo "
Syntax:     $0 [options] <config file> [<config file> ...]
Alternate:  $0 [options] --config <config_file> [<post script> ...]

Options:    -v                  be more verbose
            -q                  be quieter
            -d                  run the post scripts in debug mode (bash -x)
            --nocolor           don't use color escape codes in the messages
            --dontstopmenow or --continue
                                don't wait for user input on error
            --bailout or --stop 
                                exit when a post script returns an error code
            --hitthewall or --hardstop
                                exit on any error inside a post script (bash -e)

-v and -q are mutually exclusive.
--dontstopmenow is mutually exclusive with --bailout and --hitthewall.
--hitthewall selects --bailout too.

In the main syntax form, all options are positional: they apply only to the
configuration files after them on the command line. In the alternate syntax
form, all options must be specified *before* --config.

Please refer to the documentation for additional information.
" >&2
    exit 1
}

(( $# )) || syntax_exit


#---------------------------------------

# Set up some environment variables and load the common file, which should
# reside in the same directory as the configuration script.

MYPATH="$(dirname "$(readlink -f "$0")")"

export POST_TOPDIR="$(dirname "${MYPATH}")"
export POST_COMMON="${MYPATH}/common_functions.sh"

source "$POST_COMMON"



################################################################################
##
## SHARED FUNCTIONS ACCESSIBLE
##
################################################################################

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

    if flag_is_unset SKIPPKG ; then

        # Start with installing the groups and packages if we have lists

        if flag_is_set POST_GRPLIST ; then
            echo_progress "Installing package groups: $POST_GRPLIST"
            yum -y groupinstall $(grep -v '^#\|^$' "$POST_GRPLIST")
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
            yum -y install $(grep -v '^#\|^$' "$POST_PKGLIST")
            ret=$?
        elif flag_is_set VERBOSE ; then
            echo_info "No package file found: $POST_PKGLIST"
        fi

        # Take a break if the installation didn't go right
        if (( $ret )) ; then
            echo_error_wait "Error during package installation: $POST_PKGLIST"
        fi
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

# Main loop to run for each configuration file passed in parameter

# Syntax: apply_config configuration_file

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
        echo_info "Running only the following scripts: $@"
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

    # Alright, so at that point we have our config file loaded, and we know
    # where the directory is, we can loop over the list of post scripts.

    for post in "${POSTLIST[@]}" ; do
        run_one_script "$post"
    done

    unset POST_CONFIG POST_CONFDIR POSTDIR
    echo_footer
}


#---------------------------------------

# Prepare the grounds and clean up the environment

echo "Beginning of script: $(date)"

unset QUIET VERBOSE DEBUG NOCOLOR


# Check if stdout is being redirected or piped to something else.
# In both cases, disable the color codes to avoid polluting the output.

if [[ -p /dev/stdout ]] || [[ ! -t 1 && ! -p /dev/stdout ]] ; then
    declare -x NOCOLOR=
fi


#---------------------------------------

# And finally, loop over the parameters

while (( $# )) ; do

    case "$1" in

        -q )
            declare -x QUIET=
            unset VERBOSE
            ;;

        -v )
            declare -x VERBOSE=
            unset QUIET
            ;;

        -d )
            declare -x DEBUG=
            ;;

        --nocolor )
            declare -x NOCOLOR=
            ;;

        --dontstopmenow|--continue )
            declare -x NOSTOP=
            unset HARDSTOP
            unset SOFTSTOP
            ;;

        --hitthewall|--hardstop )
            declare -x HARDSTOP=
            ;&

        --bailout|--stop )
            declare -x SOFTSTOP=
            unset NOSTOP
            ;;

        --skip-pkg )
            declare -x SKIPPKG=
            ;;

        --config )
            # Special case: the user wants to run some hand-picked post scripts
            # Do we have a list of scripts at least?
            if (( $# <= 2 )) ; then
                echo_error '--config used without enough parameters'
                syntax_exit
            else
                shift                   # get rid of the --config
                apply_config "$@"
                shift $(( $# - 1 ))     # leave one for the last shift
            fi
            ;;

        * )
            apply_config "$1"
            ;;
    esac
    shift
done


echo "End of script: $(date)"


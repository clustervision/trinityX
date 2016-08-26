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
            --yum-retry
                                retry installing packages that failed to install

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

source "${MYPATH}/bin/common_functions.sh"



################################################################################
##
## SHARED FUNCTIONS AVAILABLE
##
################################################################################

source "${MYPATH}/bin/rpm_mgmt.sh"
source "${MYPATH}/bin/configure_backend.sh"


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

# Loop over the parameters and apply the configurations

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

        --yum-retry )
            declare -x YUMRETRY=
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


#---------------------------------------

# We must unset POST_CHROOT at the very end, to make sure that it's not carried
# over to the next run. We couldn't do it earlier at it applies to all
# configuration files specified for that run.

unset POST_CHROOT


echo "End of script: $(date)"


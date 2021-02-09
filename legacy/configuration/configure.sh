#!/bin/bash

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


# TrinityX configuration tool

################################################################################
##
## NO ACCESS TO THE SHARED FUNCTIONS YET
##
################################################################################

function syntax_exit {
    echo "
SYNTAX:     $0 [options] <config file> [<config file> ...]
ALTERNATE:  $0 [options] --config <config_file> [<post script> ...]

OPTIONS:
-v                  be more verbose
-q                  be quieter
-d                  run the post scripts in debug mode (bash -x)
--nocolor           don't use color escape codes in the messages
--step              pause and wait for input after every post script
--continue          don't wait for user input on error
--stop              exit when a post script returns an error code
--hardstop          exit on any error inside a post script (bash -e)
--chroot <dir>      apply the configuration inside <dir>
-h, --help          display this help

RULES:
-v and -q are mutually exclusive.
--continue is mutually exclusive with --stop / --hardstop and --step.
--hardstop selects --stop too.

In the main syntax form, all options are positional: they apply only to the
configuration files after them on the command line. In the alternate syntax
form, all options must be specified *before* --config.

Please refer to the documentation for additional information.
" >&2
    exit 1
}


# Right number of arguments?

(( $# )) || syntax_exit

for arg in "$@"; do
    if [ "$arg" == "--help" -o "$arg" == "-h" ] ; then
      syntax_exit
    fi
done


#---------------------------------------

# Set up some environment variables and load the common file, which should
# reside in the same directory as the configuration script.

export CONFIGSCRIPT="$(readlink -f "$0")"
MYPATH="$(dirname "$CONFIGSCRIPT")"

export POST_TOPDIR="$(dirname "${MYPATH}")"

source "${MYPATH}/bin/common_functions.sh"



################################################################################
##
## SHARED FUNCTIONS AVAILABLE
##
################################################################################

source "${MYPATH}/bin/configure_support.sh"
source "${MYPATH}/bin/configure_rpm.sh"
source "${MYPATH}/bin/configure_backend.sh"


#---------------------------------------

# Prepare the grounds and clean up the environment

echo "Beginning of script: $(date)"

unset QUIET VERBOSE DEBUG NOCOLOR {NO,SOFT,HARD}STOP STEP


# Check if stdout is being redirected or piped to something else.
# In both cases, disable the color codes to avoid polluting the output.

if [[ -p /dev/stdout ]] || [[ ! -t 1 && ! -p /dev/stdout ]] ; then
    declare -x NOCOLOR="keep"
else
    echo_warn "The output of this script isn't being redirected to a log file.

If this is the intended behaviour, press Enter to continue.

If you want to keep a log of the installation, exit the script right now by
typing Ctrl+C, and run the following command instead:

$0 $@ |& tee -a trinityX_installation.log"

    flag_is_unset NOSTOP && read
fi


#---------------------------------------

# Loop over the parameters and apply the configurations

while (( $# )) ; do

    case "$1" in

        -q )
            declare -x QUIET="keep"
            unset VERBOSE
            ;;

        -v )
            declare -x VERBOSE="keep"
            unset QUIET
            ;;

        -d )
            declare -x DEBUG="keep"
            ;;

        --nocolor )
            declare -x NOCOLOR="keep"
            ;;

        --step )
            declare -x STEP="keep"
            unset NOSTOP
            ;;

        --dontstopmenow|--continue )
            declare -x NOSTOP="keep"
            unset {HARD,SOFT}STOP STEP
            ;;

        --hitthewall|--hardstop )
            declare -x HARDSTOP="keep"
            ;&

        --bailout|--stop )
            declare -x SOFTSTOP="keep"
            unset NOSTOP
            ;;

        --chroot )
            # Do we apply the config files inside a chroot?
            if (( $# < 2 )) ; then
                echo_error '--chroot used without enough parameters'
                syntax_exit
            else
                shift
                POST_CHROOT="$1"
            fi
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


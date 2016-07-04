#!/bin/bash

# Trinity X configuration tool

# USAGE:
# configure.sh config_file
#
# The configuration file is a valid shell script that contains environment
# variables. It will be sourced later, and then various post-scripts will be
# able to access those variables for their configuration.
#
# At least one configuration file is required. If more than one is specified,
# they will run in that order. It is up to the user to break the installation if
# something goes wrong; the scripts will run regardless of the success of
# failure of previous scripts.



################################################################################
##
## NO ACCESS TO THE SHARED FUNCTIONS YET
##
################################################################################


# Right number of arguments?

if ! (( $# )) ; then
    echo "Syntax: $0 config_file [config_file ...]" >&2
    exit 1
fi


#---------------------------------------

# Set up some environment variables and load the common file, which should
# reside in the same directory as the configuration script.

MYPATH="$(dirname "$(readlink -f "$0")")"

export POST_TOPDIR="$(dirname "${MYPATH}")"
export POST_COMMON="${MYPATH}/common_functions.sh"

if ! source "$POST_COMMON" ; then
    echo "ERROR: cannot source common file \"$POST_COMMON\"" >&2
    exit 1
fi



################################################################################
##
## SHARED FUNCTIONS ACCESSIBLE
##
################################################################################

# Go through a single post script

# Syntax: run_one_script script_name

# All the other parameters are environment variables.

function run_one_script {
    
    echo_progress "Running post script: $1"
    
    export POST_PKGLIST="${POSTDIR}/${1}.pkglist"
    export POST_SCRIPT="${POSTDIR}/${1}.sh"
    export POST_FILEDIR="${POSTDIR}/${1}"

    ret=0
    
    # Start with installing the packages if we have a list
    if [[ -r "$POST_PKGLIST" ]] ; then
        yum -y install $(grep -v '^#\|^$' "$POST_PKGLIST")
        ret=$?
    else
        echo_warn "No package file found: $POST_PKGLIST"
    fi
    
    # Take a break if the installation didn't go right
    if (( $ret )) ; then
        echo_error_wait "Error during package installation: $POST_PKGLIST"
    fi
    
    ret=0
    
    # Then run the script if we have one
    if [[ -r "$POST_SCRIPT" ]] ; then
        bash "$POST_SCRIPT"
        ret=$?
    else
        echo_warn "No post script found: $POST_SCRIPT"
    fi
    
    # Take a break if the script returned an error code
    if (( $ret )) ; then
        echo_error_wait "Error during post script: $POST_SCRIPT"
    fi
    
    unset POST_PKGLIST POST_SCRIPT POST_FILEDIR
}


#---------------------------------------

# Main loop to run for each configuration file passed in parameter

# Syntax: apply_config configuration_file

function apply_config {
    
    CONFFILE="$(readlink -e "$1")"
    CONFDIR="$(dirname "$CONFFILE")"

    if ! source "$CONFFILE" ; then
        echo_error_wait "Cannot source configuration file: $1"
        return
    fi
    
    # Deal with variations in the POSTDIR values:
    # - defined and absolute -> nothing to do
    # - defined and relative -> prepend CONFDIR
    # - undefined -> same as the conf file without extension
    
    if [[ "$POSTDIR" ]] ; then
        if ! [[ "$POSTDIR" =~ ^/.* ]] ; then
            POSTDIR="${CONFDIR}/${POSTDIR}"
        fi
    else
        POSTDIR="$(basename "$CONFFILE" .cfg)"
    fi
    
    POSTDIR=$(readlink -f "$POSTDIR")

    if (( $? )) ; then
        echo_error_wait "Configuration directory doesn't exist: $POSTDIR"
        return
    fi
    
    #echo_info "Configuration directory: $POSTDIR"
    #echo_info "List of post scripts: ${POSTLIST[@]}"
    
    # Alright, so at that point we have our config file loaded, and we know
    # where the directory is, we can loop over the list of post scripts.
    
    for post in "${POSTLIST[@]}" ; do
        run_one_script "$post"
    done
}


#---------------------------------------

# And finally, loop over the parameters

for cfg in "$@" ; do
    echo_header "CONFIGURATION FILE: $cfg"
    apply_config "$cfg"
done


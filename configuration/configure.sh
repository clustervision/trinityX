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

function syntax_exit {
    echo "
Syntax:     $0 [options] <config file> [<config file> ...]
Alternate:  $0 [options] --config <config_file> [<post script> ...]

Options:    -v                  be more verbose
            -q                  be quieter
            -d                  run the post scripts in debug mode (bash -x)
            --nocolor           don't use color escape codes in the messages
            --dontstopmenow     don't wait for user input on error
            --bailout           exit when a post script returns an error code
            --hitthewall        exit on any error inside a post script (bash -e)

-v and -q are mutually exclusive.
--dontstopmenow is mutually exclusive with --bailout and --hitthewall.
--hitthewall selects --bailout too.

In the main syntax form, all options are positional: they apply only to the
configuration files after them on the command line. In the alternate syntax
form, all options must be specified *before* --config.

This alternate syntax is used to run a specific set of post scripts, within the
configuration environment provided by the config file. When the --config
option is encountered in the argument list, the following happens:

- the next argument is the configuration file;
- all the remaining arguments are the names of the scripts to run.

It is possible to mix regular configuration files with chosen scripts, as long
as the chosen scripts are last and the sequence is respected.

Please refer to the documentation for more details.
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
    
    export POST_PKGLIST="${POSTDIR}/${1}.pkglist"
    export POST_SCRIPT="${POSTDIR}/${1}.sh"
    export POST_FILEDIR="${POSTDIR}/${1}"

    ret=0
    
    if flag_is_unset SKIPPKGLIST ; then
        
        # Start with installing the packages if we have a list
        if [[ -r "$POST_PKGLIST" ]] ; then
            echo_progress "Installing packages: $POST_PKGLIST"
            yum -y install $(grep -v '^#\|^$' "$POST_PKGLIST")
            ret=$?
        else
            echo_info "No package file found: $POST_PKGLIST"
        fi
        
        # Take a break if the installation didn't go right
        if (( $ret )) ; then
            echo_error_wait "Error during package installation: $POST_PKGLIST"
        fi
    fi
    

    ret=0
    
    # Then run the script if we have one
    if [[ -r "$POST_SCRIPT" ]] ; then
        echo_progress "Running post script: $POST_SCRIPT"
        bash ${DEBUG+-x} ${HARDSTOP+-e} "$POST_SCRIPT"
        ret=$?
    else
        echo_info "No post script found: $POST_SCRIPT"
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
    
    echo_header "CONFIGURATION FILE: $1"

    POST_CONFIG="$(readlink -e "$1")"
    CONFDIR="$(dirname "$POST_CONFIG")"

    source "$POST_CONFIG"
    export POST_CONFIG
    
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
    # - defined and relative -> prepend CONFDIR
    # - undefined -> same as the conf file without extension
    
    if [[ "$POSTDIR" ]] ; then
        if ! [[ "$POSTDIR" =~ ^/.* ]] ; then
            POSTDIR="${CONFDIR}/${POSTDIR}"
        fi
    else
        POSTDIR="$(basename "$POST_CONFIG" .cfg)"
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
    
    unset POST_CONFIG
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
        
        --dontstopmenow )
            declare -x NOSTOP=
            unset HARDSTOP
            unset SOFTSTOP
            ;;
        
        --hitthewall )
            declare -x HARDSTOP=
            ;&
        
        --bailout )
            declare -x SOFTSTOP=
            unset NOSTOP
            ;;
        
        --skip-pkglist )
            declare -x SKIPPKGLIST=
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


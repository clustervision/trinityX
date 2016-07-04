
# Common functions that can be used by all scripts

shopt -s expand_aliases

alias errcho='>&2 echo'


#---------------------------------------

# This file is made to be sourced by the scripts that require it, and not
# executed directly. Exit if executed.

if [[ "$BASH_SOURCE" == "$0" ]] ; then
    errcho 'This file must be sourced by another script, not executed.'
    exit 1
fi


#---------------------------------------

# Colors!

ESC_SEQ="\x1b["
COL_RESET=$ESC_SEQ"39;49;00m"
COL_RED=$ESC_SEQ"31;01m"
COL_GREEN=$ESC_SEQ"32;01m"
COL_YELLOW=$ESC_SEQ"33;01m"
COL_BLUE=$ESC_SEQ"34;01m"
COL_MAGENTA=$ESC_SEQ"35;01m"
COL_CYAN=$ESC_SEQ"36;01m"


# Display a string in a big fat header in colors

function echo_header {
    echo -e "$COL_GREEN"
    echo -e "################################################################################\n##"
    echo "##  $@"
    echo -e "##\n################################################################################"
    echo -e "$COL_RESET"
}

# Display a standard progress message

function echo_progress {
    echo -e "$COL_CYAN"
    echo " ----->>>  $@"
    echo -e "$COL_RESET"
}


# Display an information message

function echo_info {
    echo -e "$COL_MAGENTA"
    echo "[ info ]   $@"
    echo -e "$COL_RESET"
}

# Display a warning message

function echo_warn {
    echo -e "$COL_YELLOW"
    echo "[ warn ]   $@"
    echo -e "$COL_RESET"
}

# Display an error message

function echo_error {
    echo -e "$COL_RED"
    echo "[ ERROR ]  $@"
    echo -e "$COL_RESET"
}

# Same, and wait for user input

function echo_error_wait {
    echo_error "$@"
    read -p "           Press Enter to continue."
}


#---------------------------------------

# Add a line to a file if it's not there already
# Note that it matches the exact string alone on its line, because otherwise it
# would be just mad to deal with all the corner cases...

# Syntax: append_line string filename

alsyntax="Error: wrong number of parameters.
Syntax: append_line string filename
Current parameters: ${@}
"

function append_line {
    if (( $# != 2 )) ; then
        errcho "$alsyntax"
        exit 1
    fi
    
    if grep -q -- "^${1}$" "$2" ; then
        echo_info "Line already present in destination file: $1"
    else
        echo "$1" | tee -a "$2"
    fi
}


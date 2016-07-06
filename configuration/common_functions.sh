
# Common functions that can be used by all scripts


# This file is made to be sourced by the scripts that require it, and not
# executed directly. Exit if executed.

if [[ "$BASH_SOURCE" == "$0" ]] ; then
    echo 'This file must be sourced by another script, not executed.' >&2
    exit 1
fi


#---------------------------------------

# Colors!

export ESC_SEQ="\x1b["
export COL_RESET=$ESC_SEQ"39;49;00m"
export COL_RED=$ESC_SEQ"31;01m"
export COL_GREEN=$ESC_SEQ"32;01m"
export COL_YELLOW=$ESC_SEQ"33;01m"
export COL_BLUE=$ESC_SEQ"34;01m"
export COL_MAGENTA=$ESC_SEQ"35;01m"
export COL_CYAN=$ESC_SEQ"36;01m"


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
    echo " ----->>>  $@  <<<-----"
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

typeset -fx echo_header
typeset -fx echo_progress
typeset -fx echo_info
typeset -fx echo_warn
typeset -fx echo_error
typeset -fx echo_error_wait


#---------------------------------------

# Add a line to a file if it's not there already
# Note that it matches the exact string alone on its line, because otherwise it
# would be just mad to deal with all the corner cases...

# Syntax: append_line string filename

export alsyntax="Error: wrong number of parameters.
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

typeset -fx append_line


#---------------------------------------

# Generate a random string if the environment variable is unset or empty

# Syntax:  get_password variable
# The output is printed on stdout

function get_password {
    echo ${1:-$(openssl rand -base64 8 | head -c 8)}
}

typeset -fx get_password


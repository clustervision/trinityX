
# Common functions that can be used by all scripts


# This file is made to be sourced by the scripts that require it, and not
# executed directly. Exit if executed.

if [[ "$BASH_SOURCE" == "$0" ]] ; then
    echo 'This file must be sourced by another script, not executed.' >&2
    exit 1
fi


#---------------------------------------

# Simple implementation of the quiet run option
# We have to use functions to delay the evaluation of QUIETRUN, otherwise it's
# done when the file is sourced...

function cp         { command cp ${VERBOSE+-v} "${@}" ; }
function mv         { command mv ${VERBOSE+-v} "${@}" ; }
function yum        { command yum ${QUIET+-q} "${@}" ; }
function mkdir      { command mkdir ${VERBOSE+-v} "${@}" ; }
function mount      { command mount ${VERBOSE+-v} "${@}" ; }
function umount     { command umount ${VERBOSE+-v} "${@}" ; }
function systemctl  { command systemctl ${QUIET+-q} "${@}" ; }

typeset -fx cp
typeset -fx mv
typeset -fx yum
typeset -fx mkdir
typeset -fx mount
typeset -fx umount
typeset -fx systemctl


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
    echo -e "${NOCOLOR-$COL_GREEN}"
    echo -e "################################################################################\n##"
    echo "##  $@"
    echo -e "##\n################################################################################"
    echo -e "${NOCOLOR-$COL_RESET}"
}

# Display a big fat footer in colors

function echo_footer {
    echo -e "${NOCOLOR-$COL_GREEN}"
    echo -e "################################################################################"
    echo -e "${NOCOLOR-$COL_RESET}"
}

# Display a standard progress message

function echo_progress {
    echo -e "${NOCOLOR-$COL_CYAN}"
    echo " ----->>>  $@  <<<-----"
    echo -e "${NOCOLOR-$COL_RESET}"
}


# Display an information message

function echo_info {
    echo -e "${NOCOLOR-$COL_MAGENTA}"
    echo "[ info ]   $@"
    echo -e "${NOCOLOR-$COL_RESET}"
}

# Display a warning message

function echo_warn {
    echo -e "${NOCOLOR-$COL_YELLOW}"
    echo "[ warn ]   $@"
    echo -e "${NOCOLOR-$COL_RESET}"
}

# Display an error message

function echo_error {
    echo -e "${NOCOLOR-$COL_RED}"
    echo "[ ERROR ]  $@"
    echo -e "${NOCOLOR-$COL_RESET}"
    
    if [[ "${SOFTSTOP+x}" == x ]] ; then
        echo 'Stop requested, exiting now.'
        exit 1
    fi
}

# Same, and wait for user input

function echo_error_wait {
    echo_error "$@"
    
    if ! [[ -v NOSTOP ]] ; then
        read -p "           Press Enter to continue."
    fi
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

# Variable management functions

# Store a variable in a file
# The fields are in the form variable="password"
# The variable is updated if it exists already in the file
# The variable names are sanitized.

# Syntax: store_variable file variable value

function store_variable {
    
    if (( $# != 3 )) ; then
        echo_warn "store_variable: usage: store_variable file variable value"
        return 1
    fi

    if ! ( [[ -r "$1" ]] && [[ -w "$1" ]] ); then
        echo_warn "store_variable: destination file not RW: $1"
        return 1
    fi
    
    # Sanitize the variable name
    VARNAME="$(echo -n "$2" | tr -c '[:alnum:]' _)"
    
    # If the variable name already exists, assume that it's an update of the
    # password. Exit with an error if the variable is declared read-only, update
    # it otherwise.

    if grep -q "^declare -r ${VARNAME}=" "$1" ; then
        echo_warn "store_variable: will not overwrite a read-only variable: ${VARNAME}"
        return 1
    else
        # delete the line if it exists, and append the new value
        sed -i '/^'"${VARNAME}"'=/d' "$1"
        echo "${SET_RO+declare -r }${VARNAME}=${SYSTEM-\"}${3}${SYSTEM-\"}" >> "$1"
    fi
}


# Same but without the surrounding quotes, for system config file use

function store_system_variable {
    SYSTEM= store_variable "$@"
}


typeset -fx store_variable
typeset -fx store_system_variable


#---------------------------------------

# Password management functions

# Generate a random string if the parameter is unset or empty

# Syntax: get_password somestring
# The output string is printed on stdout

function get_password {
    echo ${1:-$(openssl rand -base64 8 | head -c 8)}
}


# Save the password to the shadow file

# Syntax: store_password variable_name password

function store_password {
    
    if (( $# != 2 )) ; then
        echo_warn "store_password: usage: store_password variable_name password"
        return 1
    fi

    # we need the installation path, and the calling script may not have sourced
    # it already
    [[ "$TRIX_SHADOW" ]] || source /etc/trinity.sh
    
    SET_RO= store_variable "$TRIX_SHADOW" "$@"
}


typeset -fx get_password
typeset -fx store_password


#---------------------------------------

# Variable testing functions
# Due to the sheer amount of acceptables values for a flag enabled or disabled,
# better have some functions for that.

# Return a single 0/1 value for the state of a variable used as a flag, and a
# -1 if there weren't enough parameters.

# A flag is UNSET or OFF when any of these conditions is met:
# - the variable is unset
# - the variable is set to "0", "n" or "no" (in small or capital letters)
# In all other cases, it's SET or ON.

# Syntax: flag_is_set variable_name
#         flag_is_unset variable_name

function flag_is_set {
    
    if (( $# != 1 )) ; then
        echo_warn 'flag_is_set: wrong number of arguments.'
        return 254
    fi
    
    name="$1"
    value="${!name}"
    
    [[ -v "$name" && ! "${value,,}" =~ ^(0|n|no)$ ]]
}


function flag_is_unset {
    
    if (( $# != 1 )) ; then
        echo_warn 'flag_is_unset: wrong number of arguments.'
        return 254
    fi
    
    name="$1"
    value="${!name}"
    
    [[ ! -v "$name" || "${value,,}" =~ ^(0|n|no)$ ]]
}


typeset -fx flag_is_set
typeset -fx flag_is_unset


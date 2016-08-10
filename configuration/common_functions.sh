
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

# Only export the functions that are available to the post scripts
typeset -fx echo_info
typeset -fx echo_warn
typeset -fx echo_error


#---------------------------------------

# Add a line to a file if it's not there already
# Note that it matches the exact string alone on its line, because otherwise it
# would be just mad to deal with all the corner cases...

# By default the lines are displayed on stdout, except when the environment
# variable QUIET is defined.

# Syntax: append_line filename string

function append_line {
    if (( $# != 2 )) ; then
        echo_warn 'append_line: usage: append_line filename string'
        exit 1
    fi
    
    if [[ -r "$1" ]] && grep -q -- "^${2}$" "$1" ; then
        echo "Line already present in destination file: $2"
    else
        if flag_is_set QUIET ; then
            echo "$2" >> "$1"
        else
            echo "$2" | tee -a "$1"
        fi
    fi
}

typeset -fx append_line


#---------------------------------------

# Variable management functions

# Store a variable in a file
# This is the generic backend that is used by all other functions

# The fields are in the form:
# - variable="password"             (default)
# - variable=password               (flag_is_set SYSTEM_VAR)
# - declare -r variable="password"  (flag_is_set SH_RO_VAR)

# The variable is updated if it exists already in the file
# The variable name is not sanitized, this is left to the other functions

# Syntax: store_variable_backend filename variable value

function store_variable_backend {

    if (( $# != 3 )) ; then
        echo_warn "store_variable_backend: usage: store_variable_backend filename variable value"
        return 1
    fi

    # If the variable name already exists, assume that it's an update of the
    # password. Exit with an error if the variable is declared read-only, update
    # it otherwise.

    if [[ -r "$1" ]] && grep -q "^declare -r $2=" "$1" ; then
        echo_warn "store_variable_backend: will not overwrite a read-only variable: $2"
        return 1
    else
        # delete the line if it exists, and append the new value
        [[ -w "$1" ]] && sed -i --follow-symlinks '/^'"$2"'=/d' "$1"
        line="${SH_RO_VAR+declare -r }${2}=${SYSTEM_VAR-\"}${3}${SYSTEM_VAR-\"}"
        append_line "$1" "$line"
    fi
}



# The default store_variable
# Sanitizes the variable name

function store_variable {

    if (( $# != 3 )) ; then
        echo_warn "store_variable: usage: store_variable filename variable value"
        return 1
    fi

    # Sanitize the variable name
    VARNAME="$(echo -n "$2" | tr -c '[:alnum:]' _)"
    store_variable_backend "$1" "$VARNAME" "$3"
}



# Store a system variable without surrounding quotes
# Sanitizes the variable name but with slightly softer rules

function store_system_variable {

    if (( $# != 3 )) ; then
        echo_warn "store_system_variable: usage: store_system_variable filename variable value"
        return 1
    fi

    # Sanitize the variable name
    VARNAME="$(echo -n "$2" | tr -c '[:alnum:].:-' _)"
    SYSTEM_VAR= store_variable_backend "$1" "$VARNAME" "$3"
}


typeset -fx store_variable_backend
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
# If the environment variable ALT_SHADOW is defined, the password will be saved
# to that file.

# Syntax: store_password variable_name password

function store_password {
    
    if (( $# != 2 )) ; then
        echo_warn "store_password: usage: store_password variable password"
        return 1
    fi

    # We need an existing shadow file. If we have the variable in the
    # environment, then the base install has probably been done.
    if flag_is_unset ALT_SHADOW && ( flag_is_unset TRIX_SHADOW || ! [[ -r "$TRIX_SHADOW" ]] ) ; then
        echo_warn "store_password: the Trinity shadow file doesn't exist: ${TRIX_SHADOW:-\"\"}"
        return 1
    fi

    # We're calling store_variable, not the backend, because we want
    # sanitization of the variable name
    SH_RO_VAR= QUIET= store_variable "${ALT_SHADOW:-$TRIX_SHADOW}" "$@"
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


#---------------------------------------

# Function to display the state of variables
# Mainly used at the beginning of each script to recap the parameters

# Syntax: display_var var1 [var2 ...]

function display_var {

    for i in "$@" ; do
        if flag_is_unset "$i" ; then
            value="(unset)"
        else
            value="${!i:-(empty)}"
        fi

        echo "${i}¦=¦${value}"
    done | column -t -s '¦'
    echo
}


typeset -fx display_var


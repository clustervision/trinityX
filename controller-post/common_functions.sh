
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

# Add a line to a file if it's not there already
# Note that it matches the exact string alone on its line, because otherwise it
# would be just mad to deal with all the corner cases...

# Syntax: append_line string filename

alsyntax="Error: wrong number of parameters.
Syntax: append_line string file
Current parameters: ${@}
"

function append_line {
    if (( $# != 2 )) ; then
        errcho "$alsyntax"
        exit 1
    fi
    
    if grep -q -- "^${1}$" "$2" ; then
        errcho "Line already present in destination file: $1"
    else
        echo "$1" | tee -a "$2"
    fi
}


#!/bin/bash

# Example post script


echo_info "The following parameters are available in the environment:"

echo 'POST_TOPDIR:      '$POST_TOPDIR
echo 'POST_PKGLIST:     '$POST_PKGLIST
echo 'POST_SCRIPT:      '$POST_SCRIPT
echo 'POST_FILEDIR:     '$POST_FILEDIR
echo 'POST_CONFIG:      '$POST_CONFIG


source "$POST_CONFIG"

echo_info "The following parameters come from the specific configuration file (POST_CONFIG):"

echo 'EXAMPLE_VALUE:    '${EXAMPLE_VALUE:no EXAMPLE_VALUE variable defined.}


if [[ -r /etc/trinity.sh ]] ; then
    source /etc/trinity.sh
    
    echo_info "The following parameters come from \"/etc/trinity.sh\":"
    
    echo 'TRIX_VERSION:     '$TRIX_VERSION
    echo 'TRIX_ROOT:        '$TRIX_ROOT
    echo 'TRIX_HOME:        '$TRIX_HOME
    echo 'TRIX_IMAGES:      '$TRIX_IMAGES
    echo 'TRIX_SHARED:      '$TRIX_SHARED
    echo 'TRIX_APPS:        '$TRIX_APPS
    echo 'TRIX_SHFILE:      '$TRIX_SHFILE
    echo 'TRIX_SHADOW:      '$TRIX_SHADOW
    
else
    echo_warn "The file \"/etc/trinity.sh\" does not exist (yet) on this system."
    echo "\"/etc/trinity.sh\" is created during the Trinity X installation."
fi


echo -n -e ${QUIETRUN+"\nIf you read this, then the silent option (-q) is enabled.\n"}
echo -n -e ${VERBOSE+"\nIf you read this, then the verbose option (-v) is enabled.\n"}

echo_progress "That's all folks!"


#!/bin/bash

# Example post script

echo_info "The following parameters are available in the environment:"

display_var POST_TOPDIR \
            POST_PKGLIST \
            POST_SCRIPT \
            POST_FILEDIR \
            POST_CONFIG


echo_info "The following parameters come from the specific configuration file (POST_CONFIG):"

display_var EXAMPLE_VALUE


if [[ -r /etc/trinity.sh ]] ; then

    echo_info "The following parameters come from \"/etc/trinity.sh\":"

    display_var TRIX_VERSION \
                TRIX_ROOT \
                TRIX_HOME \
                TRIX_IMAGES \
                TRIX_SHARED \
                TRIX_APPS \
                TRIX_SHFILE \
                TRIX_SHADOW

else
    echo_warn "The file \"/etc/trinity.sh\" does not exist (yet) on this system."
    echo "\"/etc/trinity.sh\" is created during the Trinity X installation."
fi


echo -n -e ${QUIETRUN+"\nIf you read this, then the silent option (-q) is enabled.\n"}
echo -n -e ${VERBOSE+"\nIf you read this, then the verbose option (-v) is enabled.\n"}

echo_progress "That's all folks!"


#!/bin/bash

#
# Script to add provided application modules to the system
# All modulefiles are located in separate directories usign the format
#
# POST_FILEDIR/GROUP/module/version/modulefile
#
# The script will copy all available modules to their appropriate location
#
# Modulefiles should assume that the application will be installed in:
#
# {{ prefix }}/applications/module/version
# 
# This script will replace {{ prefix }} with the correct value
#

for GROUP in 'CV-standard' 'CV-advanced' 'local'; do

    echo_info "Adding $GROUP module files to the system"

    for MOD in ${POST_FILEDIR}/${GROUP}/*; do
    
        [[ -e "$MOD" ]] || continue;
    
        MODULE=$(basename "$MOD");
        VERSION=$(ls "${POST_FILEDIR}/${GROUP}/${MODULE}");
        echo_info "Adding ${MODULE}/${VERSION} to $GROUP";

        cp -r "$MOD" "${TRIX_SHARED}/modulefiles/${GROUP}/"
        sed -i -e "s,{{ prefix }},$TRIX_SHARED," "${TRIX_SHARED}/modulefiles/${GROUP}/${MODULE}/${VERSION}/modulefile"

    done

done


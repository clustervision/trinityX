#!/bin/bash

# Environment modules setup

if flag_is_unset CHROOT_INSTALL ; then
    
    echo_info 'Creating the shared modules directories'
    
    # Contents of the shared modulefiles directory:
    # /trinity/shared/
    # `-- modulefiles
    #     |-- cv-advanced       advanced CV modules, not available by default
    #     ¦-- cv-standard       standard CV modules, available by default
    #     |-- site-local        site-local modules, available by default
    #      -- modulegroups      modulefiles to load groups (advanced, local, etc)
    
    mkdir -p "${TRIX_SHARED_MODFILES}/modulegroups"
    mkdir -p "${TRIX_SHARED_MODFILES}/cv-standard"
    mkdir -p "${TRIX_SHARED_MODFILES}/cv-advanced"
    mkdir -p "${TRIX_SHARED_MODFILES}/site-local"
    
    
    echo_info 'Adding the group modulefiles'
    
    cp "${POST_FILEDIR}/cv-advanced" "${TRIX_SHARED_MODFILES}/modulegroups"
    
    
    echo_info 'Adjusting the trinityX installation path'
    
    sed -i 's#TRIX_ROOT#'"$TRIX_ROOT"'#g' "${TRIX_SHARED_MODFILES}/modulegroups/"*
fi


echo_info 'Adding the group path to the default configuration'

dest='/usr/share/Modules/init/.modulespath'

append_line "$dest" "${TRIX_SHARED_MODFILES}/modulegroups"
append_line "$dest" "${TRIX_SHARED_MODFILES}/cv-standard"
append_line "$dest" "${TRIX_SHARED_MODFILES}/site-local"

append_line "$dest" "${TRIX_LOCAL_MODFILES}"


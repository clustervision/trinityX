#!/bin/bash

# Environment modules setup

source /etc/trinity.sh

echo '*** Creating the shared modules directories'

# Contents of the modulefiles directory:
# /trinity/shared/
# `-- modulefiles
#     |-- CV-advanced       advanced CV modules, not available by default
#     ¦-- CV-standard       standard CV modules, available by default
#     |-- local             site-local modules, available by default
#      -- modulegroups      modulefiles to load groups (advanced, local, etc)

mkdir -pv "${TRIX_ROOT}/shared/modulefiles"
mkdir -pv "${TRIX_ROOT}/shared/modulefiles/modulegroups"
mkdir -pv "${TRIX_ROOT}/shared/modulefiles/CV-standard"
mkdir -pv "${TRIX_ROOT}/shared/modulefiles/CV-advanced"
mkdir -pv "${TRIX_ROOT}/shared/modulefiles/local"

echo '*** Adding the group path to the default configuration'

function append_path {
    # usage: append_path path
    # the path is appened to the file if and only it's not in there already
    
    dest='/usr/share/Modules/init/.modulespath'
    
    if grep -q "^${1}$" "$dest" ; then
        echo "Path already present: $1"
    else
        echo "$1" | tee -a "$dest"
    fi
}

append_path "${TRIX_ROOT}/shared/modulefiles/modulegroups"
append_path "${TRIX_ROOT}/shared/modulefiles/CV-standard"
append_path "${TRIX_ROOT}/shared/modulefiles/local"

echo '*** Adding the group modulefiles'

cp -v "${POST_FILEDIR}/CV-advanced" "${TRIX_ROOT}/shared/modulefiles/modulegroups"

echo '*** Adjusting the trinityX installation path'

sed -i 's#TRIX_ROOT#'"$TRIX_ROOT"'#g' "${TRIX_ROOT}/shared/modulefiles/modulegroups/"*


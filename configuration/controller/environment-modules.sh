#!/bin/bash

# Environment modules setup

source /etc/trinity.sh


echo_info 'Creating the shared modules directories'

# Contents of the modulefiles directory:
# /trinity/shared/
# `-- modulefiles
#     |-- CV-advanced       advanced CV modules, not available by default
#     ¦-- CV-standard       standard CV modules, available by default
#     |-- local             site-local modules, available by default
#      -- modulegroups      modulefiles to load groups (advanced, local, etc)

mkdir -p${SILENTRUN-v} "${TRIX_ROOT}/shared/modulefiles"
mkdir -p${SILENTRUN-v} "${TRIX_ROOT}/shared/modulefiles/modulegroups"
mkdir -p${SILENTRUN-v} "${TRIX_ROOT}/shared/modulefiles/CV-standard"
mkdir -p${SILENTRUN-v} "${TRIX_ROOT}/shared/modulefiles/CV-advanced"
mkdir -p${SILENTRUN-v} "${TRIX_ROOT}/shared/modulefiles/local"


echo_info 'Adding the group path to the default configuration'

dest='/usr/share/Modules/init/.modulespath'

append_line "${TRIX_ROOT}/shared/modulefiles/modulegroups" "$dest"
append_line "${TRIX_ROOT}/shared/modulefiles/CV-standard" "$dest"
append_line "${TRIX_ROOT}/shared/modulefiles/local" "$dest"


echo_info 'Adding the group modulefiles'

cp ${QUIETRUN--v} "${POST_FILEDIR}/CV-advanced" "${TRIX_ROOT}/shared/modulefiles/modulegroups"


echo_info 'Adjusting the trinityX installation path'

sed -i 's#TRIX_ROOT#'"$TRIX_ROOT"'#g' "${TRIX_ROOT}/shared/modulefiles/modulegroups/"*


#!/bin/bash

# Copy luna's dracut module to the image. The files are supposed to be located at
# ${TRIX_ROOT}/luna/dracut/95luna

echo_info 'Installing luna dracut module'

if [[ -d "${TRIX_ROOT}/luna/dracut/95luna" ]]; then
    cp -pr "${TRIX_ROOT}/luna/dracut/95luna" "${TARGET}/usr/lib/dracut/modules.d/"
else
    echo_error 'Could not find the dracut module in ${TRIX_ROOT}/luna/dracut/95luna'
fi


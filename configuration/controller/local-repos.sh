#!/bin/bash

# Post-installation script to set up a local RPM repository with all the
# packages required for installation.

# This is used for sites where there is no internet access, in which case all
# packages dependencies are needed, as well as for custom-built packages.

# NOTE: the local repository is enabled by default, which will cause problems if
#       you don't use it and the directory is empty. In that case, simply
#       disable the whole post script.

source /etc/trinity.sh


echo_info "Copying packages and setting up the local repository:"


# Always copy the whole tree as it may be required by other local repos
cp -r${QUIETRUN-v} "${POST_TOPDIR}/packages" "${TRIX_ROOT}"


if ls "${POST_TOPDIR}"/packages/local-repo/repodata/*primary.sqlite.* >/dev/null 2>&1 ; then
    cp ${QUIETRUN--v} ${POST_FILEDIR}/trix-local.repo /etc/yum.repos.d/
    sed -i 's#TRIX_ROOT#'"$TRIX_ROOT"'#g' /etc/yum.repos.d/trix-local.repo
else
    echo_warn 'No "local-repo" repository on the installation media.'
fi


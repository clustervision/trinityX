#!/bin/bash

# Add other repositories by default

# It may seem weird to install those repo files from a local directory instead
# of pulling them off of the internet, but again, there is no guarantee that the
# controller has connectivity *during install*. It may have it later on.

ret=0

# Key files
# No reliable naming convention, so they have to be provided

if [[ "$ADDREPOS_KEYS" ]] ; then
    echo_info 'Installing repository GPG keys'
    for i in $ADDREPOS_KEYS ; do
        cp "${POST_FILEDIR}/$i" /etc/pki/rpm-gpg/
        rpm --import "${POST_FILEDIR}/$i"
        (( ret += $? ))
    done
fi


# Repo packages
echo_info 'Installing RPM files'

if ls "${POST_FILEDIR}/"*.rpm >/dev/null 2>&1 ; then
	yum -y install "${POST_FILEDIR}/"*.rpm
	(( ret += $? ))
fi


# Individual repo files
echo_info 'Installing repo files'

if ls "${POST_FILEDIR}/"*.repo >/dev/null 2>&1 ; then
	cp "${POST_FILEDIR}/"*.repo /etc/yum.repos.d
	(( ret += $? ))
fi


# Finally, make sure that the cache is updated
if flag_is_unset CHROOT_INSTALL ; then
    echo_info 'Updating yum cache'

    yum -y makecache fast
    (( ret += $? ))
fi

exit $ret


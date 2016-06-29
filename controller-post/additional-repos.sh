#!/bin/bash

# Add other repositories by default

# It may seem weird to install those repo files from a local directory instead
# of pulling them off of the internet, but again, there is no guarantee that the
# node has connectivity *during install*. It may have it later on.


# Key files
# No reliable naming convention, so list them all
echo "*** Installing key files"
rpm --import "${POST_FILEDIR}/RPM-GPG-KEY-elrepo.org"
echo

# Repo packages
echo "*** Installing RPM files"
if ls "${POST_FILEDIR}/"*.rpm >/dev/null 2>&1 ; then
	rpm -Uvh "${POST_FILEDIR}/"*.rpm
	ret1=$?
else
	ret1=0
fi
echo

# Individual repo files
echo "*** Installing repo files"
if ls "${POST_FILEDIR}/"*.repo >/dev/null 2>&1 ; then
	cp -v "${POST_FILEDIR}/"*.repo /etc/yum.repos.d
	ret2=$?
else
	ret2=0
fi
echo

exit $((ret1 + ret2))


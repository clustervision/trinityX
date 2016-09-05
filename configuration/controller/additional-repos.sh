
# Add other RPM repositories

# It may seem weird to install those repo files from a local directory instead
# of pulling them off of the internet, but again, there is no guarantee that the
# controller has connectivity *during install*. It may have it later on.

ret=0

# Key files

if ls "${POST_FILEDIR}/keys/"* >/dev/null 2>&1 ; then
    echo_info 'Installing repository GPG keys'
    cp "${POST_FILEDIR}/keys/"* /etc/pki/rpm-gpg/
    rpm --import "${POST_FILEDIR}/keys/"*
    (( ret += $? ))
fi


# Repo packages

if ls "${POST_FILEDIR}/"*.rpm >/dev/null 2>&1 ; then
    echo_info 'Installing RPM files'
	install_rpm_files "${POST_FILEDIR}/"*.rpm
	(( ret += $? ))
fi


# Individual repo files

if ls "${POST_FILEDIR}/"*.repo >/dev/null 2>&1 ; then
    echo_info 'Installing repo files'
	cp "${POST_FILEDIR}/"*.repo /etc/yum.repos.d
	(( ret += $? ))
fi


# If the user says that we don't want remote repos, this applies to those too

flag_is_set REPOS_DISABLE_REMOTE && disable_remote_repos


# Finally, make sure that the cache is updated

if flag_is_unset POST_CHROOT ; then
    echo_info 'Updating yum cache'

    yum -y makecache fast
    (( ret += $? ))
fi

exit $ret


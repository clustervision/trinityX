#!/bin/bash

# trinityX
# Optional post-installation scripts


################################################################################
## List of post-installation scripts to run

# Comment out the ones that you don't want, or add yours in the list.
# Warning: there might be hidden dependancies between existing scripts, so don't
#          go around changing the order just for the fun of it!

# Known rules:
# - base-packages goes first
# - packages that don't require post-install scripts go into base-packages


POSTLIST=( \
           local-repo \
           base-packages \
           additional-repos \
           yum-update \
           firewalld \
           environment-modules \
         )



################################################################################
## Let's go

# A bit ugly, but errors in the output are identified much more quickly:
function myecho {
	echo -e "\n################################################################################"
        echo "####  $@"
	echo
}

# Set up a few environment variables that we will need later
MYFNAME="$(readlink -f "$0")"
MYPATH="$(dirname "$MYFNAME")"

#---------------------------------------

# Treat parameters are script names and override the built-in list:
(( $# > 0 )) && POSTLIST=("$@")

myecho "List of post scripts to run:"

echo "${POSTLIST[@]}" | tr ' ' '\n'

#---------------------------------------

export POST_TOPDIR="$(dirname "${MYPATH}")"

for i in "${POSTLIST[@]}" ; do
	
	bname="$(basename "$i" .sh)"
	myecho "Running post script: $bname"
	export POST_PKGLIST="${MYPATH}/${bname}.pkglist"
	export POST_SCRIPT="${MYPATH}/${bname}.sh"
	export POST_FILEDIR="${MYPATH}/${bname}"
	ret=0
	
	# Start with installing the packages if we have a list
	if [[ -r "$POST_PKGLIST" ]] ; then
		yum -y install $(grep -v '^#\|^$' "$POST_PKGLIST")
		ret=$?
	else
		echo "No package file found: $POST_PKGLIST"
		echo
	fi
	
	# Take a break if the installation didn't go right
	if (( $ret )) ; then
		echo
		echo "Error during package installation: $POST_PKGLIST"
		read -p "Press Enter continue."
	fi
	
	# Then run the script if we have one
	if [[ -r "$POST_SCRIPT" ]] ; then
		bash "$POST_SCRIPT"
		ret=$?
	else
		echo "No post script found: $POST_SCRIPT"
		echo
	fi
	
	# Take a break if the script returned an error code
	if (( $ret )) ; then
		echo
		echo "Error during post script: $POST_SCRIPT"
		read -p "Press Enter continue."
	fi
	
	unset POST_PKGLIST POST_SCRIPT POST_FILEDIR
done

unset POST_TOPDIR


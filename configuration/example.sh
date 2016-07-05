
echo 'POST_TOPDIR:      '$POST_TOPDIR
echo 'POST_PKGLIST:     '$POST_PKGLIST
echo 'POST_SCRIPT:      '$POST_SCRIPT
echo 'POST_FILEDIR:     '$POST_FILEDIR
echo 'POST_CONFIG:      '$POST_CONFIG

source "$POST_CONFIG"

echo
echo 'EXAMPLE_VALUE:    '$EXAMPLE_VALUE

source /etc/trinity.sh

echo
echo 'TRIX_VERSION:     '$TRIX_VERSION
echo 'TRIX_ROOT:        '$TRIX_ROOT

echo_progress "That's all folks!"


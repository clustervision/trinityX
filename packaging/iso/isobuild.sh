#!/bin/bash

set -e
set -x

# To download packages
# From one of the controlelrs in HA config
# mkdir -p /root/Packages; rpm -qa | paste -d " " $(printf " -%.0s" {1..50}) | while read L; do yumdownloader --enablerepo="elrepo" --destdir /root/Packages ${L}; done
# for G in base core debugging development hardware-monitoring network-tools performance system-admin-tools system-management; do
#    yumdownloader @${G} --setopt=group_package_types=mandatory,default,optional --resolve --destdir /root/Packages
# done
#

CENTOS_CONTENT=$1
TRIX_PACKAGES=$2

if [ "x${CENTOS_CONTENT}" = "x" ]; then
    echo "Centos content dir should be specified"
    exit 1
fi

if [ "x${TRIX_PACKAGES}" = "x" ]; then
    echo "ThinityX packages source should be specified"
    exit 1
fi

if  ! git describe --tag 2>/dev/null &>/dev/null
then
    VERSION=9999
    BUILD=$(git log --pretty=format:'' | wc -l)
else
    VERSION=$(git describe --tag --long  | sed -r 's/^r([\.0-9]*)-(.*)$/\1/')
    BUILD=$(git describe --tag --long --match r${VERSION}  | sed -r 's/^r([\.0-9]*)-(.*)$/\2/' | tr - .)
fi

ISO_NAME="TrinityX-${VERSION}-${BUILD}_$(date +"%Y-%m-%d_%H-%M").iso"

SCRIPTDIR=$(
    cd $(dirname "$0")
    pwd
)

ISO_DIR=${SCRIPTDIR}/ISO

mkdir -p ${ISO_DIR}/Packages

cp -pr ${CENTOS_CONTENT}/{EFI,GPL,images,isolinux,LiveOS} ${ISO_DIR}/

cp -pr ${TRIX_PACKAGES}/* ${ISO_DIR}/Packages/
echo '<?xml version="1.0" encoding="UTF-8"?>' > ${ISO_DIR}/comps.xml
echo '<!DOCTYPE comps PUBLIC "-//CentOS//DTD Comps info//EN" "comps.dtd">' >> ${ISO_DIR}/comps.xml
echo '<comps>' >> ${ISO_DIR}/comps.xml
xsltproc \
    --novalid ${SCRIPTDIR}/trinity-comps.xsl \
    ${CENTOS_CONTENT}/repodata/*-comps.xml \
    | grep -v '<?xml version="1.0"?>' >> ${ISO_DIR}/comps.xml
cat ${SCRIPTDIR}/trinity-comps.xml >> ${ISO_DIR}/comps.xml
echo '</comps>' >> ${ISO_DIR}/comps.xml

pushd ${ISO_DIR}
createrepo --groupfile ./comps.xml .
repoclosure --repofrompath=0,. -r 0
rmdir 0
popd

pushd ${SCRIPTDIR}/product
find . | cpio -c -o | gzip -9cv > ${ISO_DIR}/images/product.img
popd

pushd ${ISO_DIR}
genisoimage -U -r -v -T -J \
    -joliet-long -V "CentOS 7 x86_64" \
    -volset "CentOS 7 x86_64" \
    -A "CentOS 7 x86_64" \
    -b isolinux/isolinux.bin \
    -c isolinux/boot.cat \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    -eltorito-alt-boot \
    -e images/efiboot.img \
    -no-emul-boot \
    -o ${SCRIPTDIR}/${ISO_NAME} .
popd

# make USB-stick boot possible
isohybrid ${SCRIPTDIR}/${ISO_NAME}

# Chech disk in boot menu should work
implantisomd5 ${SCRIPTDIR}/${ISO_NAME}

#!/bin/bash

set -e
set -x

# To download packages
# Fomr one of the controlelrs in HA config
# mkdir -p /root/Packages; rpm -qa | paste -d " " $(printf " -%.0s" {1..50}) | while read L; do yumdownloader --enablerepo="elrepo" --destdir /root/Packages ${L}; done

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

mkdir -p ${ISO_DIR}

cp -pr ${CENTOS_CONTENT}/{EFI,GPL,images,isolinux,Packages,LiveOS} ${ISO_DIR}/

cp -pr ${TRIX_PACKAGES}/* ${ISO_DIR}/Packages/
xsltproc --novalid ${SCRIPTDIR}/trinity-comps.xsl ${CENTOS_CONTENT}/repodata/*-comps.xml > ${ISO_DIR}/comps.xml

pushd ${ISO_DIR}
createrepo --groupfile ./comps.xml .
popd

#mkdir ${SCRIPTDIR}/tmp-LiveOS

#pushd ${SCRIPTDIR}/tmp-LiveOS
#unsquashfs ${CENTOS_CONTENT}/LiveOS/squashfs.img
#mkdir rootfs
#mount squashfs-root/LiveOS/rootfs.img rootfs
#cp -pr ${SCRIPTDIR}/anaconda/* rootfs/usr/share/anaconda/
#umount rootfs
#popd

#mksquashfs ${SCRIPTDIR}/tmp-LiveOS/squashfs-root/LiveOS ${ISO_DIR}/LiveOS/squashfs.img -comp xz -keep-as-directory

#rm -rf ${SCRIPTDIR}/tmp-LiveOS


#mkisofs -o ${SCRIPTDIR}/${ISO_NAME} -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot  -V "CentOS 7 x86_64" -boot-load-size 4 -boot-info-table -R -J -joliet-long -v -T ${ISO_DIR}

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

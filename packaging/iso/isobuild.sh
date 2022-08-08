#!/bin/bash

set -e
set -x

PLAYBOOKS_DIR="../../site/"
PLAYBOOKS="controller.yml compute.yml"

if [ "x${CENTOS_CONTENT}" = "x" ]; then
    echo "Centos content dir should be specifiedi."
    echo "Please do 'export CENTOS_CONTENT=/path/to/unpacked/iso'"
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

TRINITY_RPM=trinityx-${VERSION}-${BUILD}.el7.x86_64.rpm

pushd ${SCRIPTDIR}/${PLAYBOOKS_DIR}
pwd
for PLB in ${PLAYBOOKS}; do
    ${SCRIPTDIR}/parse-playbook.py \
        --playbook ${PLB} \
        --host controller1
done \
    | sort \
    | uniq > ${ISO_DIR}/pkg.list;
popd

cat ${SCRIPTDIR}/additional-packages.lst >> ${ISO_DIR}/pkg.list

# download all the packages installed not from the repo
cat ${ISO_DIR}/pkg.list \
    | grep -E '^http[s]?://' \
    | while read L; do wget -N -P ${ISO_DIR}/Packages ${L}; done

# copy all local files
cat ${ISO_DIR}/pkg.list \
    | grep -E '^/' \
    | while read L; do cp ${L} ${ISO_DIR}/Packages/; done

# download additional files
cat ${SCRIPTDIR}/additional-files.lst \
    | while read L; do wget -N -P ${ISO_DIR}/Packages ${L}; done

# download all the packages from YAMLs
cat ${ISO_DIR}/pkg.list \
    | grep -v '/' \
    | paste -d " " $(printf " -%.0s" {1..50}) \
    | while read P; do \
        yumdownloader --installroot ${ISO_DIR}/Packages \
            --setopt=releasever=7 \
            --destdir ${ISO_DIR}/Packages --resolve ${P}; \
      done

rm -rf ${ISO_DIR}/Packages/var

# compare desired list and actual downloaded packages
ORPHANED_PACKAGES=$(comm -23 \
    <(cat ${ISO_DIR}/pkg.list | grep -v -E '/|^@' | sort | uniq) \
    <(rpm -qp ${ISO_DIR}/Packages/*.rpm --provides \
        | awk '{print $1}' | sort | uniq)
)

if [[ ! -z ${ORPHANED_PACKAGES} ]]; then
    echo "Packages were not downloaded:"
    echo "${ORPHANED_PACKAGES}"
    exit 1
fi

cp ${SCRIPTDIR}/../rpm/RPMS/x86_64/${TRINITY_RPM} ${ISO_DIR}/Packages/

cp -pr ${CENTOS_CONTENT}/{EFI,GPL,images,isolinux,LiveOS} ${ISO_DIR}/

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
# for reference, some packages are not really good in tracking dependencies
repoclosure --repofrompath=0,. -r 0 || true
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

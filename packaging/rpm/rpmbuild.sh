#!/bin/bash

set -e
set -x

PROD_NAME=trinityx
SPEC_FILE=${PROD_NAME}.spec
SPEC_IN_FILE=${SPEC_FILE}.in

SCRIPTDIR=$(
    cd $(dirname "$0")
    pwd
)

if [ ! -f ${SCRIPTDIR}/${SPEC_IN_FILE} ]; then
    echo "No ${SPEC_IN_FILE} file found"
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

mkdir -p ${SCRIPTDIR}/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

sed -e "s/__VERSION__/$VERSION/" ${SCRIPTDIR}/${SPEC_IN_FILE} > ${SCRIPTDIR}/SPECS/${SPEC_FILE}
sed -i "s/__BUILD__/$BUILD/" ${SCRIPTDIR}/SPECS/${SPEC_FILE}

# git log to rpm's changelog
git log --format="* %cd %aN%n- (%h) %s%d%n" --date=local --no-merges | sed -r 's/[0-9]+:[0-9]+:[0-9]+ //' >>  ${SCRIPTDIR}/SPECS/${SPEC_FILE}

git archive --format=tar.gz --prefix=${PROD_NAME}-${VERSION}-${BUILD}/  -o ${SCRIPTDIR}/SOURCES/v${VERSION}-${BUILD}.tar.gz HEAD

rm -rf ${SCRIPTDIR}/SRPMS/*.rpm
rpmbuild -bs --define "_topdir ${SCRIPTDIR}" ${SCRIPTDIR}/SPECS/${SPEC_FILE}
rm -rf ${SCRIPTDIR}/RPMS/*.rpm
rpmbuild --rebuild --define "_topdir ${SCRIPTDIR}" ${SCRIPTDIR}/SRPMS/*.rpm


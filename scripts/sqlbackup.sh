#!/bin/bash
set -e
trap report_err ERR

function report_err() {
    echo "ERROR: Unsuccessful backup of the sql database."
}
CWD=`pwd`
CURDATE=$(date +%Y-%m-%d_%H-%M-%S)
BKPFILE=${CURDATE}-sql.dump.gz
mysqldump --single-transaction --flush-logs --hex-blob --master-data=2 -A | gzip > ${BKPFILE}
echo "INFO: ${CWD}/${BKPFILE}"


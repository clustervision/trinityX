#!/bin/bash
SLURM_TMPDIR=/tmp/${SLURM_JOB_USER}.${SLURM_JOB_ID}
mkdir -p "${SLURM_TMPDIR}"
chmod -R 777 ${SLURM_TMPDIR}

echo "export SLURM_TMPDIR=${SLURM_TMPDIR}"
echo "export TMPDIR=${SLURM_TMPDIR}"

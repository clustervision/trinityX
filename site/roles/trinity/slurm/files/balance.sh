#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/root/bin
export PATH=${PATH}
if [ ${SLURM_JOB_ID} ]; then
  stdout=`/usr/bin/scontrol show job ${SLURM_JOB_ID} | grep -i stdout | cut -f2 -d '='`
else
  echo "No SLURM JOB ID detected"  | tee -a ${stdout}
fi
if [[ "x${stdout}" == "x" ]]; then
  stdout="/tmp/output"
fi
if [ ${SLURM_JOB_USER} ]; then
  echo "Your remaining balance (at the time of job end)"  | tee -a ${stdout}
  /bin/sbank balance statement -u ${SLURM_JOB_USER}  | tee -a ${stdout}
else
  echo "No SLURM user detected"  | tee -a ${stdout} 
fi
exit 0

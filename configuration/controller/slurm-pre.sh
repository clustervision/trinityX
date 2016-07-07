source "$POST_CONFIG"

source /etc/trinity.sh


echo_info "Creating user"

useradd munge -u $MUNGE_USER_ID -U
useradd slurm -u $SLURM_USER_ID -U
mkdir -p /var/log/slurm
chown slurm:slurm /var/log/slurm
chmod 750 /var/log/slurm


echo_info 'Copying the repository file'

cp ${QUIETRUN--v} ${POST_FILEDIR}/slurm.repo /etc/yum.repos.d/
sed -i 's#TRIX_ROOT#'"$TRIX_ROOT"'#g' /etc/yum.repos.d/slurm.repo


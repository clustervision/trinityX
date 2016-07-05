source "$POST_CONFIG"

source /etc/trinity.sh


echo_info "Creating user"

useradd munge -u $MUNGE_USER_ID -U
useradd slurm -u $SLURM_USER_ID -U
mkdir -p /var/log/slurm
chown slurm:slurm /var/log/slurm
chmod 750 /var/log/slurm


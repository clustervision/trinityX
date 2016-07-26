echo_info "Set symlink to /trinity/shared/etc/slurm"
pushd /etc
[ -d /etc/slurm.orig ] && ( echo_error "/etc/slurm.orig exists! Stopping!"; exit 1 )
/usr/bin/mv slurm{,.orig}
/usr/bin/ln -s /trinity/shared/etc/slurm slurm
popd

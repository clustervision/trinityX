
# Cleanup unneeded services that were installed at some point or other

STOPME=( \
        auditd \
        wpa_supplicant \
       )


echo_info "Stopping unnecessary services"

for i in ${STOPME[@]} ; do
    systemctl stop $i
    systemctl disable $i
done


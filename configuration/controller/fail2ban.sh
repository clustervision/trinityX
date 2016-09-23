
display_var POST_FILEDIR

echo_info 'Copying the custom fail2ban rules'

cp "${POST_FILEDIR}"/trinityx.conf /etc/fail2ban/jail.d/

echo_info 'Enabling and starting fail2ban'

systemctl enable fail2ban
flag_is_unset POST_CHROOT && systemctl restart fail2ban || true


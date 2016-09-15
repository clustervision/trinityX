
# Base package configuration

# Exclude some packages from all future installations and updates
# Either they get in our way for the configuration, or they are plain useless

echo_info "Excluding selected packages from yum"

store_system_variable /etc/yum.conf exclude 'NetworkManager* plymouth*'


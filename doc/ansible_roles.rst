Ansible Roles overview
======================

- init: checks if primary controller, disables SElinux, removes NetworkManager
- cv_support: installs remote assistance script, trinity health package, updates root's bashrc
- packages: installs all required diag packages required on a proper HPC head node. See roles/packages/defaults/main.yml
- tunables: updates limits.conf and sysctl.conf
- hostname: sets hostname and /etc/hosts
- firewalld: installs, configures and enables firewalld
- chrony: installs, configures and enables chrony (NTP sync)
- rdma-centos: installs and enables RDMA
- ssh: configures passwordless SSH between controllers
- fail2ban: installs, configures and enables fail2ban
- pacemaker: installs and configures pacemaker and corosync for HA
- drbd: creates DRBD filesystem, adds resources to pacemaker
- trix-tree: just creates /trinity
- nfs: configures NFS export, adds resources to pacemaker
- environment-modules: prepares module environment and installs a default set of applications, see :ref:`tab_envmodules_role`.
- ssl-cert: generates SSL certs for HTTPS and LDAPS
- openldap: installs OpenLDAP and configures schema
- obol: installs and configures obol (user management tool)
- sssd: installs, configures, and enables sssd
- mariadb: installs, configures MariaDB (MySQL), adds resources to pacemaker
- slurm: installs and configures Slurm, adds resources to pacemaker
- mongodb: installs and configures MongoDB, DB for luna
- bind: installs and configures bind/named, adds resources to pacemaker
- nginx: installs and configures nginx (web server for luna)
- luna: installs and configures luna
- rsyslog: installs and configures syslog
- zabbix: installs and configures Zabbix (monitoring)



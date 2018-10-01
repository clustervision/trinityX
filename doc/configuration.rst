
TrinityX configuration variables
================================


Global variables
~~~~~~~~~~~~~~~~

All global variables in the TrinityX installer are stored in the `site/group_vars/all` file.
All variables have sane defaults that will work out of the box, but care must be taken to make sure the default IPs are actually the IPs used on the controllers.

What follows is a list of those variables together with their descriptions and default values.

.. note:: Due to some roles being called as dependencies of others, their configuration variables have been put alongside the global ones. For their descriptions, please refer to the relevant role's variables table.


.. _tab_global_variables:

.. table:: Global variables
  
  ======================= ============= ================== =============
       Variable               value        default          description
  ======================= ============= ================== =============
  trix_version            -             -                  The TrinityX version number.
                                                           This will be automatically set to the current release version.
  
  project_id              string        000000             Project ID or string that'll show up in the default shell prompt on the controllers.
                                                           A pure esthetical configuration option that gives to shell prompts of the format `000000 hh:mm:ss [root@hostname ~]#`
  
  ha                      boolean       true               This option allows to choose whether to do a highly available setup on two controllers or a single controller setup.
                                                           Set to 'False' to disable HA.
  
  trix_domain             hostname      'cluster'          A domain name to be assigned to the controller(s) and nodes on the internal network.
                                                           This also serves as luna's default provisioning network name.
  
  trix_ctrl1_hostname     hostname      'controller1'      Default hostname for the controller in a single controller setup.
                                                           In HA setups, this is the hostname of the first controller.
  
  trix_ctrl2_hostname     hostname      'controller2'      This option is ignored in a single controller setup.
                                                           In HA setups, this is the hostname of the second controller.
  
  trix_ctrl_hostname      hostname      'controller'       This option is set by the installer to the value of `trix_ctrl1_hostname` in a single controller setup.
                                                           In HA setups, this the controllers' floating hostname that will always resolve to the controller with the primary role.
  
  trix_ctrl1_ip           IP address    '10.141.255.254'   Default IP address of the controller in a single controller setup.
                                                           In HA setups, this is the IP address of the first controller.
  
  trix_ctrl2_ip           IP address    '10.141.255.253'   This option is ignored in a single controller setup.
                                                           In HA setups, this is the IP address of the second controller.
  
  trix_ctrl_ip            IP address    '10.141.255.252'   This option is set by the installer to the value of `trix_ctrl1_ip` in a single controller setup.
                                                           In HA setups, this is the controllers' floating IP address that will always point to the controller with the primary role.
  
  trix_ctrl1_bmcip        IP address    '10.148.255.254'   Only useful in HA setups for fencing purposes.
                                                           This is the IP address of the BMC on the first controller that will be used to enable IPMI LAN fencing.
  trix_ctrl2_bmcip        IP address    '10.148.255.253'   Only useful in HA setups for fencing purposes.
                                                           This is the IP address of the BMC on the second controller that will be used to enable IPMI LAN fencing.
  
  trix_cluster_net        IP address    '10.141.0.0'       Default provisioning network used by luna to allocate IP addresses to provisioned nodes.
                                                           This will be the luna network whose name is defined in `trix_domain`.
  
  trix_cluster_netprefix  Subnet prefix 16                 The subnet prefix of the provisioning network defined in `trix_cluster_net`.
  
  trix_cluster_dhcp_start IP address    '10.141.128.0'     The IP address that marks the start of the DHCP IP range used by the provisioning tool to PXE boot the nodes.
                                                           This IP address must belong to the network defined in `trix_cluster_net`.
  
  trix_cluster_dhcp_end   IP address    '10.141.140.0'     The IP address that marks the end of the DHCP IP range used by the provisioning tool to PXE boot the nodes.
                                                           This IP address must belong to the network defined in `trix_cluster_net`.
  
  trix_root               Path          /trinity           Path to which the standard TrinityX files and directories will be installed.
  
  trix_images             Path          `trix_root`/images The default path where compute node images will be stored.
  
  trix_shared             Path          `trix_root`/shared The default path where everything shared by the controllers to the nodes will be stored.
  
  trix_local              Path          `trix_root`/local  The default path where configuration files specific to each of the controllers will be stored.
  
  trix_home               Path          `trix_root`/home   The default path where the user home directories will be located.
  
  trix_repos              Path          `trix_root`/repos  The default path where the local TrinityX rpm repository will be located.
  
  enable_selinux          boolean       false              Whether or not to enable SELinux throughout the cluster.
  
  enable_slurm_pam        boolean       true               Whether or not to enable Slurm PAM module by default.
                                                           If enabled, sssd's ldap filters will be disabled on the compute nodes.
  
  enable_docker           boolean       false              Whether or not to install docker tools on the cluster
  
  enable_heartbeat_link   boolean       true               Whether or not to configure the secondary corosync heartbeat link between the controllers.
  
  shared_fs_type          String        'drbd'             The type of shared storage used on the controllers in TrinityX.
                                                           Currently the only type supported by the installer is 'drbd'. Other types are planned for future releases.
  
  shared_fs_device        Path          /dev/vdb           A path to the device that will be used as backend for the default 'drbd' storage type.

  additional_env_modules  List          []                 A user-defined list of environment modules to install in addition to the default one.
                                                           See the table `environment-modules role`_.
  
  ======================= ============= ================== =============

Role specific variables
~~~~~~~~~~~~~~~~~~~~~~~

Below is a list of options that each ansible role in TrinityX supports.

The default values for each variable are set in `site/controller.yml`. For the sake of simplicity, not all variables appear in that file. You can find those missing variables and their defaults in the ansible role itself, in defaults directory (`site/roles/trinity/*/defaults/main.yml`).


`bind` role
^^^^^^^^^^^^

=================== ============= ====================== =============
     Variable           value        default              description
=================== ============= ====================== =============
bind_dns_forwarders List          - '8.8.8.8'            A list of the default DNS forwarders to use on the controllers.
                                  - '8.8.4.4'
bind_dnssec_enable  boolean       no                     Whether to enable DNSSEC in Bind9 on the controllers or not.
bind_db_path        Path          `trix_local`/var/named The default path where Bind9 will store is DNS database.
=================== ============= ====================== =============

`chrony` role
^^^^^^^^^^^^^^

======================= ============= ========================= =============
     Variable               value        default                 description
======================= ============= ========================= =============
chrony_upstream_servers List          - '0.centos.pool.ntp.org' A list of upstream NTP servers that will be used by the controller(s) to keep time on the cluster synchronized.
                                      - '1.centos.pool.ntp.org'
                                      - '2.centos.pool.ntp.org'
                                      - '3.centos.pool.ntp.org'

chrony_allow_networks   List          []                        A list of networks that are allowed to query the controller(s) for time.
                                                                An empty list is the same as allowing all networks.
======================= ============= ========================= =============

`drbd` role
^^^^^^^^^^^^

========================= ============= ===================== =============
     Variable                 value        default             description
========================= ============= ===================== =============
drbd_ctrl1_ip             IP address    `trix_ctrl1_ip`       IP address of the first of controllers in an HA setup.
drbd_ctrl2_ip             IP address    `trix_ctrl2_ip`       IP address of the second of controllers in an HA setup.
drbd_ctrl1_device         Path          /dev/drbd1            The name that will be given to the block device node of the DRBD resource on the first controller in an HA setup.
drbd_ctrl2_device         Path          `drbd_ctrl1_device`   The name that will be given to the block device node of the DRBD resource on the second controller in an HA setup.
drbd_ctrl1_disk           Disk name     `shared_fs_device`    A path to the device that will be used as backend for the DRBD resource on the first controller in an HA setup.
drbd_ctrl2_disk           Disk name     `drbd_ctrl1_disk`     A path to the device that will be used as backend for the DRBD resource on the second controller in an HA setup.
drbd_shared_resource_name String        'trinity_disk'        The name that will be given to the DRBD resource on the controllers in an HA setup.
========================= ============= ===================== =============

.. _tab_envmodules_role:

`environment-modules` role
^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. list-table::
   :header-rows: 1
   :widths: auto
   
   * - Variable
     - Value
     - Default
     - Description

   * - envmodules_version
     - String
     - *current version*
     - The release name of the userspace packages to install.

   * - envmodules_files_path
     - Path
     - `trix_shared`/modules
     - Path where files for all environment modules should be installed in TrinityX cluster.

   * - envmodules_default_list
     - List
     - 
       - gcc
       - gdb
       - hwloc
       - intel-runtime
       - iozone
       - likwid
       - osu-benchmarks
       - python2
       - python3
       *versions omitted*
     - List of modules to install by default.


`firewalld` role
^^^^^^^^^^^^^^^^^

============================ ============= ================ =============
     Variable                    value        default        description
============================ ============= ================ =============
firewalld_public_interfaces  List          ['eth2']         A list of network interfaces that are considered to be public. i.e. used to access networks that are external to the cluster.
firewalld_trusted_interfaces List          ['eth0', 'eth1'] A list of network interfaces that are considered to be trusted. i.e. used to access networks that are interal to the cluster.
firewalld_public_tcp_ports   List          [443]            A list of TCP ports that will be allowd on the public interfaces defined in `firewalld_public_interfaces`
firewalld_public_udp_ports   List          []               A list of UDP ports that will be allowd on the public interfaces defined in `firewalld_public_interfaces`
============================ ============= ================ =============

`luna` role
^^^^^^^^^^^^

=============================== ============= ================================== =============
     Variable                       value        default                          description
=============================== ============= ================================== =============
luna_user_id                    User ID       880                                The user ID of the luna user on the controller(s).
luna_group_id                   Group ID      880                                The group ID of the luna group on the controller(s).

luna                            Dict                                             This the root of the object that describes how the cluster provisioning tool `luna` should be configured.
                                                                                 It is a YAML dictionary. See the following variables for a description of all the attributes it supports.

luna.cluster                    Dict                                             This sub-dictionary of the luna dict defines global luna options.

luna.cluster.frontend_address   IP address    `trix_ctrl_ip`                     The IP address used by nodes during provisioning to query luna for configuration.
luna.cluster.path               Path          `trix_local`/luna                  Path where all of luna's files will be stored on the controller(s).
luna.cluster.named_include_file Path          `trix_local`/etc/named.luna.zones  Path where luna's Bind9 custom configuration will be located on the controller(s).
luna.cluster.named_zone_dir     Path          `trix_local`/var/lib/named         Path on the controller(s) where Bind9 will put DNS resolution files the networks managed by luna.

luna.dhcp                       Dict                                             Sub-dict that defines luna's DHCP configuration used to PXE boot compute nodes.

luna.dhcp.conf_path             Path          `trix_local`/etc/dhcp              Path where generated DHCP configuration will be stored on the controller(s).
luna.dhcp.network               String        `trix_domain`                      Name of network that will be used to provision compute nodes.
luna.dhcp.start_ip              IP address    `trix_cluster_dhcp_start`          The IP address that marks the start of the DHCP IP range used by luna to PXE boot the nodes.
luna.dhcp.end_ip                IP address    `trix_cluster_dhcp_end`            The IP address that marks the end of the DHCP IP range used by luna to PXE boot the nodes.

luna.networks                   List of dict  See following                      A list of dicts describing the networks that will be managed by luna.
                                                                                 The dict that follows (which is also the first item of the luna.networks list) defines the attributes of the provisioning network.

luna.networks.0.name            String        `trix_domain`                      The name that will be used for this network.
luna.networks.0.ip              IP address    `trix_cluster_net`                 Network's address.
luna.networks.0.prefix          Number        `trix_cluster_netprefix`           Network's subnet prefix.
luna.networks.0.ns_ip           IP address    `trix_ctrl_ip`                     IP address of the nameserver on this network. Usually this is the address of the controller(s) on this network.

=============================== ============= ================================== =============

`mariadb` role
^^^^^^^^^^^^^^^

=================== ============= ========================== =============
     Variable           value        default                  description
=================== ============= ========================== =============
mariadb_db_path     Path          `trix_local`/var/lib/mysql Path where MariaDB data folder will be located in a TrinityX cluster.
=================== ============= ========================== =============

`mongodb` role
^^^^^^^^^^^^^^^

=================== ============= ============================ =============
     Variable           value        default                    description
=================== ============= ============================ =============
mongo_db_path       Path          `trix_local`/var/lib/mongodb Path where MongoDB data folder will be located in a TrinityX cluster.
=================== ============= ============================ =============

`nfs` role
^^^^^^^^^^^

=================== ============= ========================== =============
     Variable           value        default                  description
=================== ============= ========================== =============
nfs_rpccount        Number        256                        Number of NFS server processes to be started on the controller(s).
nfs_enable_rdma     boolean       false                      Whether to enable NFS over RDMA by default or not.
                                                             TCP will be used when this option if set to `false`.
nfs_export_shared   boolean       true                       If set to true, `trix_shared` directory will be exported to the compute nodes from the controller(s).
nfs_export_home     boolean       true                       If set to true, `trix_home` directory will be exported to the compute nodes from the controller(s).
nfs_exports_path    Path          `trix_local`/etc/exports.d The path where to store NFS exports configuration on the controller(s).
=================== ============= ========================== =============

`obol` role
^^^^^^^^^^^^

=================== ============= ================================== =============
     Variable           value        default                          description
=================== ============= ================================== =============
obol_conf_path      Path          /etc'                              Path where obol's configuration file will be stored on the controller(s).
users_home_path     Path          `trix_home`                        Default home directory path to use for users created using obol.
ldap_host           FQDN          `trix_ctrl_hostname.trix_domain`   The FQDN of the ldap servers used to store ldap accounts on the cluster.
=================== ============= ================================== =============

`openldap` role
^^^^^^^^^^^^^^^^

============================= ============= =================================== =============
     Variable                     value        default                           description
============================= ============= =================================== =============
openldap_default_user         String        ldap                                OpenLDAP default user name
openldap_default_group        String        ldap                                OpenLDAP default group name

openldap_server_dir_path      Path          `trix_local`/var/lib/ldap           Path where OpenLDAPs databases will be stored on the controller(s).
openldap_server_conf_path     Path          `trix_local`/etc/openldap/slapd.d   Default path for the OpenLDAP configuration on the controller(s).
openldap_server_defaults_file Path          /etc/sysconfig/slapd                Path where to put OpenLDAP's default command line options.

openldap_endpoints            String        'ldaps:/// ldapi:///'                 Space separated list of endpoints that OpenLDAP will accept.

openldap_tls_cacrt            Path          `ssl_ca_cert`                       Path of CA cert used to sign the controller(s) certificate(s).
openldap_tls_crt              Path          `ssl_cert_path`/`ansible_fqdn`.crt  Path of the controller(s) certificate(s).
openldap_tls_key              Path          `ssl_cert_path`/`ansible_fqdn`.key  Path of the controller(s) key(s).

openldap_schemas              List          - cosine                            List of the schemas to be configured in OpenLDAP.
                                            - inetorgperson
                                            - rfc2307bis
                                            - autoinc

============================= ============= =================================== =============

`pacemaker` role
^^^^^^^^^^^^^^^^^

=========================== ============= ========================= =============
     Variable                   value        default                 description
=========================== ============= ========================= =============
pacemaker_properties        Dict          no-quorum-policy: ignore  A list of pacemaker configuration options.
pacemaker_resource_defaults List          - 'migration-threshold=1' A list of pacemaker resource defaults.

fence_ipmilan_host_check    String        'static-list'             This option helps the stonith agent determine which machines are controlled by the fencing device.
fence_ipmilan_method        String        'cycle'                   Method to fence (onoff or cycle)
fence_ipmilan_lanplus       String        'true'                    Use Lanplus if True, don't otherwise.
fence_ipmilan_login         String        'user'                    Username/Login (if required) to control power on IPMI device
fence_ipmilan_passwd        String        'password'                Password (if required) to control power on IPMI device

=========================== ============= ========================= =============

`repos` role
^^^^^^^^^^^^^

=================== ============= ============== =============
     Variable           value        default      description
=================== ============= ============== =============
repos               List                         List of package repositories to install.
repos_port          Number        8080           Default port to listen on when serving the local package repository on the controller(s).
=================== ============= ============== =============

`rsyslog` role
^^^^^^^^^^^^^^^

===================================== ============= ========================================================================= =============
     Variable                             value        default                                                                 description
===================================== ============= ========================================================================= =============
syslog_forwarding_rules               List of dicts                                                                           A list of log forwarding rules to use in rsyslog.d/ configuration files.

syslog_forwarding_rules.0.name        String                                                                                  Forwarding rule's name
syslog_forwarding_rules.0.proto       String                                                                                  Protocol to use for this rule. Can be TCP or UDP.
syslog_forwarding_rules.0.port        Number                                                                                  The port to which rsyslog will send logs that match the rule.
syslog_forwarding_rules.0.host        String                                                                                  The destination host.
syslog_forwarding_rules.0.facility    String                                                                                  Syslog facility name to use for logs sent through this rule.
syslog_forwarding_rules.0.level       String                                                                                  Syslog level to use for logs send through this rule.

syslog_listeners                      List of dicts                                                                           A list of listeners to be configured in rsyslog.

syslog_listeners.0.name               String        default                                                                   Listener's name
syslog_listeners.0.proto              String        tcp                                                                       Listener's protocol. Can be TCP or UDP
syslog_listeners.0.port               Number        514                                                                       Listener's port.

syslog_file_template_rules            List of dicts                                                                           A list of template rules.
                                                                                                                              See http://www.rsyslog.com/doc/master/configuration/templates.html for details.

syslog_file_template_rules.0.name     String        controllers                                                               Template name
syslog_file_template_rules.0.type     String        string                                                                    Template type
syslog_file_template_rules.0.content  String        '/var/log/cluster-messages/%HOSTNAME%.messages'                           Content of the template rule.
syslog_file_template_rules.0.field    String        '$fromhost-ip'                                                            Template's field
syslog_file_template_rules.0.criteria String        startswith                                                                Templates's criteria
syslog_file_template_rules.0.rule     String        '{{ trix_cluster_net.split(".")[:trix_cluster_netprefix//8]|join(".") }}' The matching rule for the template.

===================================== ============= ========================================================================= =============

`slurm` role
^^^^^^^^^^^^^

=================== ============= =========================================== =============
     Variable           value        default                                   description
=================== ============= =========================================== =============
slurm_conf_path     String        `trix_shared`/etc/slurm                     Path where slurm configuration files are stored.
slurm_spool_path    Path          `trix_local`/var/spool/slurm                Path for slurm's working data.
slurm_log_path      Path          /var/log/slurm                              Location where to store slurm logs.

slurm_user_id       Number        891                                         slurm's user ID
slurm_group_id      Number        891                                         slurm's group ID

slurm_ctrl          Hostname      `trix_ctrl_hostname`                        Hostname of the slurm controller
slurm_ctrl_ip       IP address    `trix_ctrl_ip`                              IP address of the slurm controller
slurm_ctrl_list     Hostname list `trix_ctrl1_hostname,trix_ctrl2_hostname`   Comma separated list of the machines that serve as slurm controller.

enable_slurm_pam    Boolean       true                                        Enable or disable slurm's PAM module that denies user access to nodes where they don't have a running job.

slurmdbd_sql_user   String        'slurm_accounting'                          Name to use for slurmdbs's SQL user.
slurmdbd_sql_db     String        'slurm_accounting'                          Name to use for slurmdbd's database.

munge_user_id       Number        892                                         munge's user ID
munge_group_id      Number        892                                         munge's group ID

munge_conf_path     Path          `trix_shared`/etc/munge                     Path where munge's configuration files will be stored.

=================== ============= =========================================== =============

`ssl-cert` role
^^^^^^^^^^^^^^^^

===================== ============= ================================== =============
     Variable             value        default                          description
===================== ============= ================================== =============
ssl_cert_path         Path          `trix_local`/etc/ssl               Location where to store cluster certificates and keys.

ssl_cert_country      String        'NL'                               CA certificate country attribute
ssl_cert_locality     String        'Amsterdam'                        CA certificate locality attribute
ssl_cert_organization String        'ClusterVision B.V.'               CA certificate organization attribute
ssl_cert_state        String        'Noord Holland'                    CA certificate state attribute
ssl_cert_altname      FQDN          `trix_ctrl_hostname.trix_domain`   CA certificate alternative name attribute

ssl_cert_days         Number        3650                               Number of controller's certificate validity days.

ssl_cert_owner        String        'root'                             Default owner of the certificate files
ssl_cert_owner_id     Number        0                                  Default owner's id

ssl_cert_group        String        'ssl'                              Default group owner of the certificate files
ssl_cert_group_id     Number        991                                Default group owner's id

===================== ============= ================================== =============

`sssd` role
^^^^^^^^^^^^

=================== ============= ==================================== =============
     Variable           value        default                            description
=================== ============= ==================================== =============
sss_allowed_groups  List          - admins                             List of user groups that are allowed access on the controller(s).

sss_ldap_hosts      List          - `trix_ctrl_hostname.trix_domain`   List of hostnames that sssd can use for its ldap queries.

sss_filter_enabled  Boolean       false                                Whether to use group based access filters on restrict access to compute nodes or not.

=================== ============= ==================================== =============

`zabbix` role
^^^^^^^^^^^^^^

======================= ============= ============================ =============
     Variable               value        default                    description
======================= ============= ============================ =============
zabbix_script_path      Path          `trix_local`/usr/lib/zabbix/ Location where zabbix can find custom scripts
zabbix_sql_db           String        'zabbix'                     Name of the zabbix database in MariaDB
zabbix_sql_user         String        'zabbix'                     SQL user used by zabbix

zabbix_login            String        'Admin'                      Default name of the zabbix admin user

zabbix_mail_server      Hostname      'localhost'                  Default mail server

======================= ============= ============================ =============

Compute specific variables
~~~~~~~~~~~~~~~~~~~~~~~~~~

Global variables
^^^^^^^^^^^^^^^^^

======================= ============= ================== =============
     Variable               value        default          description
======================= ============= ================== =============
image_name              String        compute            The name of the OS image to create or to which to apply the playbook
image_password          String                           The password to set up for the root user in the image.
                                                         If empty, it will be randomly generated.

======================= ============= ================== =============

`nfs-mounts` role
^^^^^^^^^^^^^^^^^^

==================== ============= ================================= =============
     Variable            value        default                         description
==================== ============= ================================= =============
nfs_mounts           List of dicts see below                         A list of NFS mountpoints and their options

nfs_mounts.0.path    String        '/trinity/shared'                 Path on the compute nodes where the NFS share will be mounted
nfs_mounts.0.remote  Path          controller:/trinity/shared        NFS share to mount
nfs_mounts.0.options String        'defaults,nfsvers=4,ro,retrans=4' Mount point options

==================== ============= ================================= =============


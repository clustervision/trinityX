
TrinityX - OpenStack installation procedure
============================================

This document describes the installation of an OpenStack controller either alongside a standard TrinityX controller or standalone, as well as the creation and configuration of an image for the openstack compute nodes of a TrinityX cluster.

The requirements for the OpenStack controller, as well as for the OpenStack compute nodes, are decribed in the :doc:`requirements`. It is assumed that the guidelines included in this document have been followed, and that the controller machine is ready for the TrinityX configuration.


OpenStack controller installation
---------------------------------

Alongside a TrinityX controller
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The TrinityX configuration script can install and configure all packages required for setting up a working OpenStack controller that includes the following services:

- Identity (keystone)
- Image (glance)
- Compute (nova)
- Network (neutron)
- Volume (cinder)
- Dashboard (horizon)

.. note:: The OpenStack controller is a separate machine that is used solely for this purpose. The OpenStack compute nodes, however, are managed by the previously installed TrinityX controller.


Preconfiguration
````````````````

Before running the TrinityX installer, it is required to do some initial network configuration.
As described in the requirements document the OpenStack controller uses three NICs:

- A first NIC used to route external traffic; it needs to be left unconfigured (except for being up on boot). This one will be managed by OpenStack Neutron
- A second NIC called the management interface. This one is used fo communication between OpenStack services. It needs to have an IP from the provisionning subnet.
- A third NIC used to isolate inter-VM traffic. It belongs to the same network as the compute nodes' second interface.

.. note:: Internet access on the OpenStack controller needs to be through the management NIC or using a fourth one for this special purpose.


.. note:: The OpenStack controller needs to use the TrinityX controller as a DNS resolver.


TrinityX installer
``````````````````

The configuration for a default OpenStack controller installation is described in the file called ``openstack.cfg``, located in the ``configuration`` subdirectory of the TrinityX tree.

This file can be edited to reflect the user's own installation choices. All configuration parameters are included and described. Once the configuration file is ready, the script ``configure.sh`` will apply the configuration to the controller::

    # pwd
    ~/trinityX/configuration
    
    # ./configure.sh openstack.cfg

For further details about the use of the configuration script, including its command line options, please see :doc:`config_tool`.

For further details about the configuration files, please see :doc:`config_cfg_files`.


Standalone mode
~~~~~~~~~~~~~~~

.. note:: The same preconfiguration described above applies to the standalone mode except for the DNS resolver part.



In a standalone mode, the ``openstack.cfg`` configuration file needs to be altered a bit to account for the services that would otherwise be available on the TrinityX controller.

The new default postscripts list should look something like this::

    POSTLIST=( \
            standard-configuration \
            yum-cache \
            hosts \
            local-repos \
            base-packages \
            yum-update \
            additional-repos \
            additional-packages \
            chrony \
            openldap \
            sssd \
            bind \
            mariadb \
            luna \
            postfix \
            rabbitmq \
            keystone \
            glance \
            nova \
            neutron \
            cinder \
            horizon \
            zabbix \
            zabbix-agent \
         )

Once the configuration file is ready, as in the previous mode, the script ``configure.sh`` will apply the configuration to the controller::

    # pwd
    ~/trinityX/configuration
    
    # ./configure.sh openstack.cfg


OpenStack compute node image creation
-------------------------------------

The setup of the image is defined in these two configuration scripts:

- ``images-create-openstack-compute.cfg``, which controls the creation of the directory and the base setup, *including calling the second script*;

- ``images-setup-openstack-compute.cfg``, which controls the installation and setup inside that directory.

.. note:: You do not need to call the second script (``images-setup-openstack-compute.cfg``) by hand. This is done automatically by the creation script, which passes additional parameters to the setup script.


Building the OpenStack compute image should be done on the node where the provisioning tool is installed:

- The OpenStack controller when in standalone mode
- The TrinityX controller otherwise. Care must be taken in this case to append the content of the `trinity.shadow` file from the OpenStack controller to the same file on the TrinityX controller (Otherwise compute nodes will fail to reach the controller since they will be using different passwords).


After updating the configuration of the image creating it is done as simply as when setting up the controller::

    # ./configure.sh images-create-openstack-compute.cfg

.. note:: The location of the new image is displayed as one of the last messages from the creation and setup process.


After the configuration has completed, the node image is ready but not yet integrated into any provisioning system. The steps required for that operation are described in the documentation of the provisioning system installed on your site.


Offline installation
--------------------

To do an offline installation, the same guidlines, as described in :doc:`installation`, apply.


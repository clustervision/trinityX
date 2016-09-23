
Trinity X - OpenStack installation procedure
============================================

This document describes the installation of an OpenStack controller either alongside a standard trinityX controller or standalone, as well as the creation and configuration of an image for the openstack compute nodes of a Trinity X cluster.

The requirements for the OpenStack controller, as well as for the OpenStack compute nodes, are decribed in the `Trinity X pre-installation requirements`_. It is assumed that the guidelines included in this document have been followed, and that the controller machine is ready for the Trinity X configuration.


OpenStack controller installation
---------------------------------

Alongside a trinityX controller
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The Trinity X configuration script can install and configure all packages required for setting up a working OpenStack controller that includes the following services:

- Keystone
- Glance
- Nova
- Neutron
- Cinder
- Horizon

.. note:: The OpenStack controller is a separate machine that is used solely for this purpose. The OpenStack compute nodes, however, are managed by the previously installed trinityX controller.

The configuration for a default OpenStack controller installation is described in the file called ``openstack.cfg``, located in the ``configuration`` subdirectory of the Trinity X tree.

This file can be edited to reflect the user's own installation choices. All configuration parameters are included and described. Once the configuration file is ready, the script ``configure.sh`` will apply the configuration to the controller::

    # pwd
    ~/trinityX/configuration
    
    # ./configure.sh openstack.cfg

For further details about the use of the configuration script, including its command line options, please see `Configuration tool usage`_.

For further details about the configuration files, please see `Configuration files`_.


Standalone mode
~~~~~~~~~~~~~~~

In a standalone mode, the ``openstack.cfg`` configuration file needs to be altered a bit to account for the services that would otherwise be available on the trinityX controller.

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
- The trinityX controller otherwise

After updating the configuration of the image creating it is done as simply as when setting up the controller::

    # ./configure.sh images-create-openstack-compute.cfg

.. note:: The location of the new image is displayed as one of the last messages from the creation and setup process.

After the configuration has completed, the node image is ready but not yet integrated into any provisioning system. The steps required for that operation are described in the documentation of the provisioning system installed on your site.


Offline installation
--------------------

To do an offline installation, the same guidlines, as described in `Trinity X installation procedure`_, apply.



.. Relative file links

.. _Trinity X pre-installation requirements: requirements.rst
.. _Trinity X installation procedure: installation.rst
.. _Configuration tool usage: config_tool.rst
.. _Configuration files: config_cfg_files.rst


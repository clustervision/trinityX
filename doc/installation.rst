
TrinityX installation procedure
================================

This document describes the installation of a TrinityX controller, as well as the creation and configuration of an image for the compute nodes of a TrinityX cluster.

Starting with the 11th release, Ansible is fully integrated into TrinityX. This allows for a lot of flexibility when installing a cluster.

The requirements for all the components of a TriniryX cluster are decribed in the :doc:`requirements`. It is assumed that the guidelines included in this document have been followed, and that the controller machines are ready for the TrinityX configuration.

.. note:: While the procedure to create compute images needs to be run from the cluster controller (the primary controller when in HA mode) the installation procedure of the controllers themselves can be run from any arbitrary machine (including your laptop).

Controller installation
-----------------------

The TrinityX configuration tool will install and configure all packages required for setting up a working TrinityX controller.

The configuration for a default controller installation is described in the file called ``controller.yml``, as well as the files located in the ``group_vars/`` subdirectory of the TrinityX tree, while the list of machines to which the configuration needs to be applied is described in the file called ``hosts``::

    # pwd
    ~/trinityX

    # ls hosts controller.yml group_vars/
    hosts  controller.yml

    group_vars/:
    all


These files can be edited to reflect the user's own installation choices. For a full list of the configuration options that TrinityX supports refer to :doc:`configuration`.

Once the configuration files are ready, the ``controller.yml`` ansible playbook can be run to apply the configuration to the controller(s)::

    # pwd
    ~/trinityX

    # ansible-playbook controller.yml

For further details about the use of ansible, including its command line options, please consult the `official ansible documentation <https://docs.ansible.com/>`_.

For further details about the configuration files, please see :doc:`config_cfg_files`.


Compute node image creation
---------------------------

The creation and configuration of an OS image for the compute nodes uses the same tool and a similar configuration file as for the controller. While the controller configuration applies its setting to the machine on which it runs, the image configuration does so in a directory that will contain the whole image of the compute node.

.. note:: Building a new image isn't required for most system administration tasks. One of the images existing on your system can be cloned and modified. Creating a new image is only useful for an initial installation, or when desiring to start from a clean image. Another scenario is a setup fully controlled by ansible - in this case to create the image it is possible to copy ``compute.yml`` and set up image name accordingly.


Again, the setup of the default image is defined in the playbook ``compute.yml``, which controls the creation of the directory and running the configuration. ``compute.yml`` file includes ``trinity-image.yml`` file as a dependency. Latter is a playbook which is applying standard Trinity configuration.


In the vast majority of cases, changing the configuration of the default image is not required. Creating it is done as simply as when setting up the controller::

    # ansible-playbook compute.yml

.. note:: The location of the new image is displayed as one of the last messages from the creation and setup process.

After the configuration has completed, the node image is ready and integrated into the provisioning system. No further steps are required.

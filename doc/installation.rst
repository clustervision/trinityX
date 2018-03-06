
TrinityX installation procedure
================================

This document describes the installation of a TrinityX controller, as well as the creation and configuration of an image for the compute nodes of a TrinityX cluster.

Starting with the 11th release, Ansible is fully integrated into TrinityX. This allows for a lot of flexibility when installing a cluster.

The requirements for all the components of a TriniryX cluster are described in the :doc:`requirements`. It is assumed that the guidelines included in this document have been followed, and that the controller machines are ready for the TrinityX configuration.

.. note:: While the procedure to create compute images needs to be run from the cluster controller (the primary controller when in HA mode) the installation procedure of the controllers themselves can be run from any arbitrary machine (including your laptop).

Controller installation
-----------------------

The TrinityX configuration tool will install and configure all packages required for setting up a working TrinityX controller.

The configuration for a default controller installation is described in the file called ``controller.yml``, as well as the files located in the ``group_vars/`` subdirectory of the TrinityX tree, while the list of machines to which the configuration needs to be applied is described in the file called ``hosts``::

    # pwd
    ~/trinityX/site/

    # ls hosts controller.yml group_vars/
    hosts  controller.yml

    group_vars/:
    all


These files can be edited to reflect the user's own installation choices. For a full list of the configuration options that TrinityX supports refer to :doc:`configuration`.

Once the configuration files are ready, the ``controller.yml`` ansible playbook can be run to apply the configuration to the controller(s)::

    # pwd
    ~/trinityX/site/

    # ansible-playbook controller.yml

.. note:: By default, high availability is enabled in the installer, so it expects to have access to two machines which will become the controllers. To install a non-HA version you need to update the ``ha`` variable in ``group_vars/all``. For more details on the high availability configuration you can consult :doc:`ha_design`.

If more verbose output is desired during the installation process, you can use `ansible-playbook`'s `-v` option. The verbosity level will increase according to the number of `v`s.
For further details about the use of ansible, including its command line options, please consult the `official ansible documentation <https://docs.ansible.com/>`_.


`controller.yml` playbook
~~~~~~~~~~~~~~~~~~~~~~~~~

When running this playbook for the first time, you will see some initial warning that some luna inventory could no be parsed (luna is the cluster provisioning tool included in TrinityX). What these warnings mean is that `luna` could not not be queried for a list of nodes and osimages which is normal at this point of the installation since luna has not been configured yet::

    [WARNING]:  * Failed to parse /etc/ansible/hosts/luna with script plugin: Inventory script
    (/etc/ansible/hosts/luna) had an execution error: Traceback (most recent call last):   File
    "/etc/ansible/hosts/luna", line 3, in <module>     from luna_ansible.inventory import LunaInventory
    File "/usr/lib/python2.7/site-packages/luna_ansible/inventory.py", line 15, in <module>     raise
    AnsibleError("luna is not installed") ansible.errors.AnsibleError: luna is not installed
    
    [...]


The rest of the output would be a list of all the tasks that ansible is running on controller(s)::

    [...] 

    TASK [trinity/init : Update the trix_ctrl_* variables in case of non-HA setup] **************************
    ok: [controller]
    
    TASK [trinity/init : Toggle selinux state] **************************************************************
     [WARNING]: SELinux state temporarily changed from 'enforcing' to 'permissive'. State change will take
    effect next reboot.
    
    changed: [controller]
    
    [...] 
    
    TASK [trinity/repos : Ensure "/trinity/repos" exists] ***************************************************
    changed: [controller]
    
    [...] 


Then at the end, if everything was successful. You will be able to see a summary of all the actions that ansible has performed including how many changes and how many failures::

    PLAY RECAP **********************************************************************************************
    controller                 : ok=270  changed=197  unreachable=0    failed=0


Do keep in mind that if some of the tasks fails during the installation ansible won't stop until it finishes running all the other tasks. If this happens, then you can use ansible to only re-apply the failing task, the full role containing it or the entire playbook after the cause of the failure has been fixed.


What are the passwords?
~~~~~~~~~~~~~~~~~~~~~~~

By default, the TrinityX installer will generate random passwords for all services that require one. You can find all of the generated passwords on the controller(s) at `/etc/trinity/passwords/` where every password lives in its own file that's named after the service that uses it.


Compute node image creation
---------------------------

The creation and configuration of an OS image for the compute nodes uses the same tool and a similar configuration file as for the controller. While the controller configuration applies its setting to the machine on which it runs, the image configuration does so in a directory that will contain the whole image of the compute node.

.. note:: Building a new image isn't required for most system administration tasks. One of the images existing on your system can be cloned and modified. Creating a new image is only useful for an initial installation, or when desiring to start from a clean one. Another scenario might be a cluster where all configuration (creation, deletion, ...) must be fully controlled by ansible - in this case to create the image it is possible to copy ``compute.yml`` and update ``image_name`` variable to reflect the new image's name.


The setup of the default image is defined in the playbook ``compute.yml``, which controls the creation of a new filesystem directory and applies the image configuration. The ``compute.yml`` file includes the ``trinity-image.yml`` playbook as a dependency. This latter is a playbook that applies a standard Trinity image configuration.


In the vast majority of cases, changing the configuration of the default image is not required. It may be desired, however, to setup a custom root password, in which case the variable ``image_password`` can be set to the desired password.

Creating a new image is as simple as setting up the controller(s)::

    # ansible-playbook compute.yml

.. note:: Any newly created image will reside in the directory defined by the configuration variable ``trix_image`` which points to `/trinity/images/` by default.

After the configuration has completed, the node image is ready and integrated into the provisioning system. No further steps are required.


Updating images and nodes
-------------------------

It is worth pointing out that the ``compute.yml`` or any copy thereof can be applied to both existing images and/or live nodes without issues. All that needs to be done is updating the list of hosts to which it applies.

By default ``compute.yml`` applies to the host `compute.osimages.luna` which means it only applies to the image called `compute`. Therefore, it can either be changed to `osimages.luna`, in which case it will apply to all osimages, or to `new_image.osimages.luna` in which case it will apply to the image called `new_image`. Alternatively, the construct `*.nodes.luna` which refers to the nodes managed by luna can be used. Similarly, it can either be used to refer to all nodes: `nodes.luna`, or to a single node: `node001.nodes.luna`.

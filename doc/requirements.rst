
TrinityX pre-installation requirements
=======================================


Hardware
--------

TrinityX has very few hardware requirements, summarized in the following paragraphs.


Controllers
~~~~~~~~~~~

The machines that will be used as TrinityX controllers are expected to have a minimum of 2 Ethernet NIC:

- one NIC for the public interface, used to connect to the cluster;

- one NIC for the private (internal) interface, used for compute node provisioning and general cluster communications.

.. note:: A third NIC that serves as a dedicated heartbeat link between a pair of HA controllers would provide a redundant communication link which would go a long way in reducing the risk of encountering a split-brain situation. 

.. note:: When installing the controllers in a high availability configuration it is required to have an IPMI interface properly configured on both controllers. This allows for IPMI based fencing functionality to be implemented for safer failovers.

The OpenStack optional module adds another network requirement:

- a third Ethernet NIC used for the traffic between OpenStack VMs.


The controllers must have enough disk space to install the base operating system, as well as all the packages required by TrinityX. For a simple installation this amounts to a few gigabytes only. Other components of Trinity will likely require much more space, namely:

- compute images;

- shared applications;

- user homes.

All of the above are located in specific directories under the root of the TrinityX installation, and can be hosted either on the controller's drives or on remote filesystems. Sufficient storage space must be provided in all cases.


Compute nodes
~~~~~~~~~~~~~

The machines that will be used as compute nodes are expected to have at least 1 Ethernet NIC:

- one NIC for the private (internal) interface, used for provisioning and general cluster communications.


The OpenStack optional module adds another network requirement:

- a second Ethernet NIC used for the traffic between OpenStack VMs.


The compute nodes can be provisioned with or without local storage. When not configured for local storage a ramdisk will be used to store the base image. In that case, make sure to take into account the space of the OS image (which depends on its exact configuration) in your memory calculations.


Software and configuration
--------------------------

Controllers
~~~~~~~~~~~

The TrinityX installer requires the operating system of the controllers to be installed already. As of TrinityX release 11, the supported OS versions are:

- CentOS 7 **Minimal**
- Scientific Linux 7 **Minimal**

It is important to install only the Minimal edition, as some of the packages that are installed with larger editions may conflict with what will be installed for TrinityX. Note that when installing from a non-Minimal edition, it is usually possible to select the Minimal setup at the package selection step.

The network configuration of the controllers must be done before installing TrinityX, and it must be correct. This includes:

- IP addresses and netmasks of all interfaces that will be used by TrinityX;

The timezone must also be set correctly before installation as it will be propagated to all subsequently created node images.

If the user homes or the TrinityX installation directory (part of or whole) are to be set up on remote or distributed volume(s) or filesystem(s), all relevant configuration must be done before installing TrinityX. If necessary, remember to disable the NFS and DRBD roles in the ``controller.yml`` playbook.

Next, the following software packages must also be present on the machine used to install the controllers. This machine is usually the controller in non HA configurations or the first of the two controllers in HA configurations.

- git

- ansible

Also, the following installer dependencies need to be available on that machine:

- OndrejHome.pcs-modules-2 from the ansible galaxy: ``ansible-galaxy install OndrejHome.pcs-modules-2``

- luna-ansible::

    # curl https://updates.clustervision.com/luna/1.2/centos/luna-1.2.repo > /etc/yum.repos.d/luna-1.2.repo
    # yum install luna-ansible

Lastly, since Ansible uses ssh to deploy the configuration, the machine running the installer (whether it be one of the controllers or a third one) should have passwordless access to the controller(s)-to-be. As such, care must be taken to put its key in ``/root/.ssh/authorized_keys`` on the controller(s)-to-be.


Compute nodes
~~~~~~~~~~~~~

The compute nodes must be configured to PXE-boot from the NIC connected to the internal network.



TrinityX pre-installation requirements
=======================================


Hardware
--------

TrinityX has very few hardware requirements, which are summarized in the following paragraphs.


Controllers
~~~~~~~~~~~

The machines that will be used as TrinityX controllers are expected to have a minimum of 2 Ethernet NIC:

- one NIC for the public interface, used to connect to the cluster;

- one NIC for the private (internal) interface, used for compute node provisioning and general cluster communications.


The OpenStack optional module adds another network requirement:

- a third Ethernet NIC used for the traffic between OpenStack VMs.


The controllers must have enough disk space to install the base operating system, as well as all the packages required by the various post scripts. For a simple installation this amounts to a few gigabytes only. Other components of Trinity will likely require much more space:

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


The compute nodes can be provisioned with or without local storage. When not configured for local storage a ramdisk will be used to store the base image. In that case install make sure to take into account the space of the OS image (which depends on the exact configuration of the image) in your memory calculations.



Software and configuration
--------------------------

Controllers
~~~~~~~~~~~

The TrinityX installer requires the operating system of the controllers to be already installed. As of TrinityX v1, the only supported OS version is:

- CentOS 7.2 **Minimal**

It is important to install only the Minimal edition, as some of the packages that are installed with larger editions conflict with what will be installed for TrinityX. Note that when installing from a non-Minimal edition, it is usually possible to select the Minimal setup at the package selection step.

The network configuration of the controllers must be done before installing TrinityX, and it must be correct. This includes:

- IP addresses and netmasks of all interfaces that will be used by TrinityX;

- hostname and domainname (the commands `hostname`, `hostname -s` and `hostname -d` must return the correct values).

The timezone must also be set correctly before installation.

If the user homes or the TrinityX installation directory (part of or whole) are to be set up on remote or distributed volume(s) or filesystem(s), all relevant configuration must be done before installing TrinityX. If necessary, remember to disable the NFS post script.


Compute nodes
~~~~~~~~~~~~~

The compute nodes must be configured to PXE-boot from the NIC connected to the internal network.


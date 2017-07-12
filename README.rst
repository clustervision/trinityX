Overview
========

Welcome to TrinityX!

TrinityX is the new generation of ClusterVision's open-source HPC platform. It is designed from the ground up to provide all services required in a modern HPC system, and to allow full customization of the installation. Also it includes optional modules for specific needs, such as an OpenStack cloud, Docker on the compute nodes and the ability to partition a cluster.

The full documentation is available in the ``doc`` subdirectory.


Quick start
===========

In standard configuration TrinityX provides the following services to the cluster:

* Luna, our default super-efficient node provisioner https://github.com/clustervision/luna
* OpenLDAP
* SLURM
* Zabbix
* NTP
* and more

It will also set up:

* NFS-shared home and application directories
* environment modules
* rsyslog
* and more


Default installation
--------------------

Running TrinityX installer with the default configuration file will:

* in case of a single-controller setup, i.e. non-HA:
  
  - set the controller's name to ``controller``
    
    **Note**: the provisioning interface is expected to be assigned ``10.141.255.254`` *prior* to the installation
    
* in case of a dual-controller setup, i.e. HA: 
  
  - set controllers' names to ``controller1`` and ``controller2``, respectively
  - create a floating IP address ``10.141.255.252`` and associate the hostname ``controller`` with it
    
    **Note**: the provisioning interfaces are expected to be assigned ``10.141.255.254`` and ``10.141.255.253``, respectively, *prior* to the installation
  - create an XFS filesystem on a specified block device, which is assumed to be shared between the controllers, and mount it as /trinity
  
* in both cases:

  - define a provisioning network 10.141.0.0/16 and associate a domain name ``cluster`` with it
  - create shared directories under /trinity
  - generate a random password for each service that requires it

Steps to install TrinityX
~~~~~~~~~~~~~~~~~~~~~~~~~

1. Install CentOS Minimal on your controller(s)

2. Configure network interfaces that will be used in the cluster, e.g public, provisioning and MPI networks

3. Install ``git``::

    # yum install git

4. Clone TrinityX repository into your working directory and go to the configuration directory::

    # git clone http://github.com/clustervision/trinityx
    # cd trinityX/configuration

5. Based on whether you're installing a single-controller or a high-availability (HA) setup, you might want to check one of the configuration files:
       
   * ``controller-nonHA.cfg``
   * ``controller-HA.cfg``

   to see if the default firewall parameters apply to your situation::
   
     FWD_PUBLIC_IF="eth2"
     FWD_TRUSTED_IF="eth0 eth1"

   Moreover, in the case of an HA setup you will most probably need to change the default name of the shared block device set by ``SHARED_FS_DEVICE``.

6. Start TrinityX installation

   **Note**: In the case of HA, complete the installation on the first controller first, then run it on the second one::

     # ./configure.sh <target_configuration_file> |& tee -a install.log
    
   **Note**: If the installer pauses with a prompt for the next action, analyze the error(s) in the output above and try to fix it in another console *without* cancelling the installation.
    
7. Create a default OS image::

    # ./configure.sh images-create-compute.cfg |& tee -a image.log

Now you have your controller(s) installed and the default OS image created!

Customizing your installation
-----------------------------

Now, if you want to tailor TrinityX to your needs, you can modify the configuration file, or better yet, create a custom configuration file that imports all the default configuration and only overrides what's neccessary.

Descriptions to configuration options are given inside ``controller-HA.cfg``. Options that might be changed include:

* controller's hostnames and IP addresses
* shared storage backing device
* DHCP dynamic range
* firewall settings
* passwords

You can also choose which components to exclude from the installation by modifying ``POSTLIST``.

A custom configuration file would look similar to the following::

     # vim my.cfg
     #!/bin/bash
     
     . controller-HA.cfg
   
     # Controller network settings
     CTRL1_HOSTNAME=controller1
     CTRL1_IP=192.168.10.254
     
     CTRL2_HOSTNAME=controller2
     CTRL2_IP=192.168.10.253
     
     CTRL_HOSTNAME=controller
     CTRL_IP=192.168.10.252
     
     DOMAIN=cluster
     
     COROSYNC_CTRL1_IP=192.168.50.254
     COROSYNC_CTRL2_IP=192.168.50.253
     
     # Shared FS options
     SHARED_FS_TYPE=drbd
     SHARED_FS_DEVICE=/dev/rootvg/drbd
     
     #Firewalld
     FWD_PUBLIC_IF="eth0"
     FWD_TRUSTED_IF="eth1 eth2"
   
     # Luna network
     LUNA_NETWORK=192.168.10.0
     LUNA_DHCP_RANGE_START=192.168.10.150
     LUNA_DHCP_RANGE_END=192.168.10.200

Documentation
=============

*Steps how to build TrinityX administration guide and links to other documents will be added later.*

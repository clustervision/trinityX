Overview
========

Welcome to TrinityX!

TrinityX is the new generation of ClusterVision's open-source HPC platform. It is designed from the ground up to provide all services required in a modern HPC system, and to allow full customization of the installation. Also it includes optional modules for specific needs, such as an OpenStack cloud, Docker on the compute nodes and the ability to partition a cluster.

The full documentation is available in the ``doc`` subdirectory. See the instructions how to build it below.


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

* In case of a single-controller setup, i.e. non-HA:
  
  - Set the controller's name to ``controller``
    
    **Note**: The provisioning interface is expected to be assigned ``10.141.255.254`` *prior* to the installation
    
* In case of a dual-controller setup, i.e. HA: 
  
  - Set controllers' names to ``controller1`` and ``controller2``, respectively
  - Create a floating IP address ``10.141.255.252`` and associate the hostname ``controller`` with it
    
    **Note**: The provisioning interfaces are expected to be assigned ``10.141.255.254`` and ``10.141.255.253``, respectively, *prior* to the installation
  - Create an XFS filesystem on a specified block device, which is assumed to be shared between the controllers, and mount it as /trinity
  
* In both cases:

  - Define a provisioning network 10.141.0.0/16 and associate a domain name ``cluster`` with it
  - Create shared directories under /trinity
  - Generate a random password for each service that requires it


Steps to install TrinityX
~~~~~~~~~~~~~~~~~~~~~~~~~

1. Install CentOS Minimal on your controller(s)

2. Configure network interfaces that will be used in the cluster, e.g public, provisioning and MPI networks

3. Install ``git``, ``ansible`` and ``luna-ansible``::

    # yum install git ansible luna-ansible

4. Clone TrinityX repository into your working directory and go to the site directory::

    # git clone http://github.com/clustervision/trinityx
    # cd trinityX/site

5. Based on whether you're installing a single-controller or a high-availability (HA) setup, you might want to update the configuration files:
       
   * ``group_vars/controllers``
   * ``group_vars/all``

   **Note**: In the case of an HA setup you will most probably need to change the default name of the shared block device set by ``shared_fs_device``.

   You might also want to check if the default firewall parameters apply to your situation in the firewalld role in ``site.yml``::
   
      firewalld_public_interfaces:
        - eth2
      firewalld_trusted_interfaces:
        - eth0
        - eth1

6. Install ``OndrejHome.pcs-modules-2`` from the ansible galaxy::

    # ansible-galaxy install OndrejHome.pcs-modules-2

6. Start TrinityX installation::

     # ansible-playbook site.yml |& tee -a install.log
    
   **Note**: If errors are encoutered during the installation process, analyze the error(s) in the output and try to fix it then re-run the installer.
    
7. Create a default OS image::

    # ansible-playbook image.yml |& tee -a image.log

Now you have your controller(s) installed and the default OS image created!


Customizing your installation
-----------------------------

Now, if you want to tailor TrinityX to your needs, you can modify the ansible playbooks and variable files.

Descriptions to configuration options are given inside ``site.yml`` and ``group_vars/*``. Options that might be changed include:

* Controller's hostnames and IP addresses
* Shared storage backing device
* DHCP dynamic range
* Firewall settings

You can also choose which components to exclude from the installation by modifying the ``site.yml`` playbook.


Documentation
=============

  To build the full set of the documentation included with TrinityX:

  1. Install ``git``::

      # yum install git

  2. Clone TrinityX repository into your working directory and go to the directory containing the documentation::

      # git clone http://github.com/clustervision/trinityx
      # cd trinityX/doc

  3. Install ``pip``, e.g. from EPEL repository::

      # yum install python34-pip.noarch

  4. Install ``sphinx`` and ``Rinohtype``::

      # pip3.4 install sphinx Rinohtype

  6. Build the PDF version of the TrinityX guides::

     # sphinx-build -b rinoh . _build/

  If everything goes well, the documentation will be saved as ``_build/TrinityX.pdf``

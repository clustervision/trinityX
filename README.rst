.. image:: img/trinityxbanner_scaled.png

Overview
========

Welcome to TrinityX 15!

TrinityX is the new generation of ClusterVision's open-source HPC, AI and cloud platform. It is designed from the ground up to provide all services required in a modern HPC, AI and cloud system, and to allow full customization of the installation. Also it includes optional modules for specific needs, please check the controller and compute playbooks.



Quick start
===========

In standard configuration TrinityX provides the following services to the cluster:

* Luna, our default super-efficient node provisioner
* OpenLDAP
* SLURM or OpenPBS
* Prometheus and Grafana
* AlertX
* Open OnDemand
* Graphical management applications
* Infrastructure services such as NTP, DNS, DHCP
* and more

It will also set up:

* NFS-shared home and application directories
* OpenHPC applications and libraries
* environment modules
* rsyslog
* High Availability/HA
* and more

.. image:: img/triX_300.png
   :width: 300px
   :height: 300px


Steps to install TrinityX
=========================

1. Install an Enterprise Linux version 8, 9 or 10 (i.e. RHEL, Rocky) on your controller(s). It is recommended to put ``/trinity`` and  ``/trinity/local`` on it's own filesystem. Note the partition configuration must be finalized (i.e. mounted and in fstab) before starting the TrinityX installation.

2. Configure network interfaces that will be used in the cluster, e.g public, provisioning and MPI networks on the controller(s).
   Ansible uses the interface address to determine the course of the playbook.

3. Configure passwordless authentication to the controller itself or/and optionally for in between both controllers in the HA case.

----

A: *GRAPHICAL METHOD*
~~~~~~~~~~~~~~~~~~~~~

4. Download the graphical installer on https://clustervision.com/trinityx/ and let it guide you through the installation.

   Please note: the graphical installer does rely on best-practice defaults and does not configure advanced features like HA.
   For advanced configuration, please follow the manual installation steps.

----

B: **TEXT BASED METHOD**
~~~~~~~~~~~~~~~~~~~~~~~~

4. Clone TrinityX repository into your working directory. Then run ``INSTALL.sh`` to install and be guided through the steps::

       # git clone http://github.com/clustervision/trinityX
       # cd trinityX
       # bash INSTALL.sh

----

C: **MANUAL METHOD**
~~~~~~~~~~~~~~~~~~~~

4. Step by step manual configuration and installation

4.1. Clone TrinityX repository into your working directory. Then run ``prepare.sh`` to install all the prerequisites::

       # git clone http://github.com/clustervision/trinityX
       # cd trinityX
       # bash prepare.sh

4.2. Copy the all file which will contain the controller and cluster configuration. Please view the contents of the file on the directives that may need modification(s)::

       # cd site 
       # cp group_vars/all.yml.example group_vars/all.yml

   * ``group_vars/all.yml``

   You might also want to check if the default firewall parameters in the same file apply to your situation::

      firewalld_public_interfaces: [eth0]
      firewalld_trusted_interfaces: [eth1]
      firewalld_public_tcp_ports: [22, 443]

   In case of a single controller (default), we now assume that the shared IP address is also available on the controller node, this is to ease future expansion.

   If applicable, configure the dns forwarders in trix_dns_forwarders when the defaults, 8.8.8.8 and 8.8.4.4 are unreachable.

4.3. Configure ``hosts`` file to allow ansible to address controllers.

       # cp hosts.example hosts

   Example for non-HA setup::

       [controllers]
       controller ansible_host=10.141.255.254

   Example for HA setup with shared SSH key, a.k.a. passwordless access to the other controller(s)::

       [controllers]
       controller1 ansible_host=10.141.255.254
       controller2 ansible_host=10.141.255.253

   Alternatively for HA setup, the group_vars/all.yml file can be copied to the other controllers and run sequentially.
   In this case, no SSH keys need to be exchanged between the controllers and the ``hosts`` file does not require any change.
   It's important though to have the primary controller finish the controller.yml playbook first before running on the other controllers.

4.4. Start TrinityX installation::

     # ansible-playbook controller.yml

    **Note**: If errors are encoutered during the installation process, analyze the error(s) in the output and try to fix it then re-run the installer.

    **Note**: By default, the installation logs will be available at ``/var/log/trinity.log``

4.5. Create a default RedHat/Rocky OS image::

    # ansible-playbook compute-redhat.yml

4.6. Optionally Create a default Ubuntu OS image::

    # ansible-playbook compute-ubuntu.yml


Now you have your controller(s) installed and the default OS image(s) created!


Customizing your installation
=============================

Now, if you want to tailor TrinityX to your needs, you can modify the ansible playbooks and variable files.

Descriptions to configuration options are given inside ``controller.yml`` and ``group_vars/*``. Options that might be changed include:

* Controller's hostnames and IP addresses
* Shared storage backing device
* DHCP dynamic range
* Firewall settings

You can also choose which components to exclude from the installation by modifying the ``controller.yml`` playbook.

HA or High Availability
=======================

To make HA work properly, services need to understand the HA concept. Many services do, however not all. To still support HA for these services, a shared disk is required, where the active controller has access to this disk and start those services. The disk can be DRBD (default), but also iSCSI, a DAS or NAS, or combinations of. The configuration or combinations of need to provide at least the following volumes:

* {{ trix_ha }}
* {{ trix_home }}
* {{ trix_shared }}
* {{ trix_ohpc }} (if OpenHPC is enabled)
* {{ trix_easybuild }} (if Easybuild is enabled)

LVM and ZFS are supported, where partitions can be made on top of the shared disk. On top of these partitions all regular filesystems, like xfs and ext4 are supported.

Fencing is supported by enforcing stonith. The BMC-s of each controller need to be configured to match the settings for ip address, name and password in the HA section. A mismatch will result in a non proper working HA setup. Alternatively, fencing can be disabled but is not recommended.

OpenHPC Support
===============

The OpenHPC project provides a framework for building, managing and maintain HPC clusters. This project provides packages for most popular scientific and HPC applications. TrinityX can integrate this effort into it's ecosystem. In order to enable this integration set the flag ``enable_openhpc`` in ``group_vars/all`` to ``true`` (default). 

Documentation
=============
A pre-built PDF is provided in the main directory.
Please visit https://docs.clustervision.com for more documentation on the TrinityX project.
An URL with the Luna REST API documentation will follow.

Contributing
============

To contribute to TrinityX:

1. Get familiar with our `code guidelines <Guidelines.rst>`_
2. Clone TrinityX repository
3. Commit your changes in your repository and create a pull request to the ``dev`` branch in ours.

TrinityX Support
================

For further products and professional support, please contact us at sales@clustervision.com


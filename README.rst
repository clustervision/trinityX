.. image:: img/trinityxbanner_scaled.png

Overview
========

Welcome to TrinityX!

TrinityX is the new generation of ClusterVision's open-source HPC, AI and cloud platform. It is designed from the ground up to provide all services required in a modern HPC, AI and cloud system, and to allow full customization of the installation. Also it includes optional modules for specific needs, please check the controller and compute playbooks.



Quick start
===========

In standard configuration TrinityX provides the following services to the cluster:

* Luna, our default super-efficient node provisioner
* OpenLDAP
* SLURM or OpenPBS
* Prometheus and Grafana
* Infrastructure services such as NTP, DNS, DHCP
* and more

It will also set up:

* NFS-shared home and application directories
* OpenHPC applications and libraries
* environment modules
* rsyslog
* High Availability
* and more

.. image:: img/triX_300.png
   :width: 300px
   :height: 300px


Steps to install TrinityX
~~~~~~~~~~~~~~~~~~~~~~~~~

1. Install an Enterprise Linux version 8 or 9 (i.e. RHEL, Rocky) on your controller(s). It is recommended to put ``/trinity`` and  ``/trinity/local`` on it's own filesystem. Note the partition configuration must be finalized (i.e. mounted and in fstab) before starting the TrinityX installation.

2. Configure network interfaces that will be used in the cluster, e.g public, provisioning and MPI networks on the controller(s).
   Ansible uses the interface address to determine the course of the playbook.

3. Configure passwordless authentication to the controller itself or/and for both controllers in the HA case.

4. Clone TrinityX repository into your working directory. Then run ```prepare.sh``` to install all the prerequisites::

       # git clone http://github.com/clustervision/trinityX
       # cd trinityX
       # bash prepare.sh

5. Copy the all file which will contain the controller and cluster configuration. Please view the contents of the file on the directives that may need modification(s)::

       # cd site 
       # cp group_vars/all.yml.example group_vars/all.yml

   * ``group_vars/all.yml``

   You might also want to check if the default firewall parameters in the same file apply to your situation::

      firewalld_public_interfaces: [eth0]
      firewalld_trusted_interfaces: [eth1]
      firewalld_public_tcp_ports: [22, 443]

   In case of a single controller (default), we now assume that the shared IP address is also available on the controller node, this is to ease future expansion.

   If applicable, configure the dns forwarders in trix_dns_forwarders when the defaults, 8.8.8.8 and 8.8.4.4 are unreachable.

6. Configure ``hosts`` file to allow ansible to address controllers.

       # cp hosts.example hosts

   Example for non-HA setup::

       [controllers]
       controller ansible_host=10.141.255.254

   Example for HA setup::

       [controllers]
       controller1 ansible_host=10.141.255.254
       controller2 ansible_host=10.141.255.253


7. Start TrinityX installation::

     # ansible-playbook controller.yml

    **Note**: If errors are encoutered during the installation process, analyze the error(s) in the output and try to fix it then re-run the installer.

    **Note**: By default, the installation logs will be available at ``/var/log/trinity.log``

8. Create a default RedHat/Rocky OS image::

    # ansible-playbook compute-redhat.yml

9. Optionally Create a default Ubuntu OS image::

    # ansible-playbook compute-ubuntu.yml

Now you have your controller(s) installed and the default OS image(s) created!


Customizing your installation
-----------------------------

Now, if you want to tailor TrinityX to your needs, you can modify the ansible playbooks and variable files.

Descriptions to configuration options are given inside ``controller.yml`` and ``group_vars/*``. Options that might be changed include:

* Controller's hostnames and IP addresses
* Shared storage backing device
* DHCP dynamic range
* Firewall settings

You can also choose which components to exclude from the installation by modifying the ``controller.yml`` playbook.

OpenHPC Support
===============

The OpenHPC project provides a framework for building, managing and maintain HPC clusters. This project provides packages for most popular scientific and HPC applications. TrinityX can integrate this effort into it's ecosystem. In order to enable this integration set the flag ``enable_openhpc`` in ``group_vars/all`` to ``true`` (default). 

Documentation
=============
A pre-built PDF is provided in the main directory. A URL with the Luna REST API documentation will follow.


Contributing
============

To contribute to TrinityX:

1. Get familiar with our `code guidelines <Guidelines.rst>`_
2. Clone TrinityX repository
3. Commit your changes in your repository and create a pull request to the ``dev`` branch in ours.

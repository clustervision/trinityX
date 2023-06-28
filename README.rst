NOTE: TrinityX/Luna2 is almost here!! This version is OBSOLETE, don't use.
========

.. image:: img/trinityxbanner_scaled.png

Overview
========

TrinityX/Luna2 is almost here with (a.o many other things) Ubuntu client support, DHPC-less booting and encrypted/secured image distribution (est. 01/09/2023)!! Please use this repo only for testing purposes.

Welcome to TrinityX!

TrinityX is the new generation of ClusterVision's open-source HPC platform. It is designed from the ground up to provide all services required in a modern HPC system, and to allow full customization of the installation. Also it includes optional modules for specific needs, such as an OpenStack cloud and Docker on the compute nodes.

The full documentation is available in the ``doc`` subdirectory. See the instructions how to build it below.


Quick start
===========

In standard configuration TrinityX provides the following services to the cluster:

* Luna, our default super-efficient node provisioner https://github.com/clustervision/luna
* OpenLDAP
* SLURM or OpenPBS
* Telegraf, InfluxDB, Grafana and Sensu Core
* Infrastructure services such as NTP, DNS, DHCP
* and more

It will also set up:

* NFS-shared home and application directories
* OpenHPC applications and libraries
* environment modules
* rsyslog
* and more

.. image:: img/triX_300.png
   :width: 300px
   :height: 300px


Steps to install TrinityX
~~~~~~~~~~~~~~~~~~~~~~~~~

1. Install CentOS Minimal on your controller(s). It is recommended to put ``/trinity`` and  ``/var/lib/influxdb`` on it's own filesystem.

2. Configure network interfaces that will be used in the cluster, e.g public, provisioning and MPI networks on the controller(s).

3. Configure passwordless authentication to the controller itself or/and for both controllers in the HA case.

4. Clone TrinityX repository into your working directory. Then run ```prepare.sh``` to install all the prerequisites::

       # git clone http://github.com/clustervision/trinityX
       # cd trinityX
       # bash prepare.sh

5. Based on whether you're installing a single-controller or a high-availability (HA) setup, the contents may differ. Please view the contents of the file on the directives that may need modification(s)::

       # cd site 
       # cp group_vars/all.yml.example group_vars/all.yml

   * ``group_vars/all.yml``

   You might also want to check if the default firewall parameters in the same file apply to your situation::

      firewalld_public_interfaces: [eth0]
      firewalld_trusted_interfaces: [eth1]
      firewalld_public_tcp_ports: [22, 443]

   **Note**: In the case of an HA setup you will most probably need to change the default name of the shared block device set by ``shared_fs_device``.

   In case of a single server, we now assume that the shared IP address is also available on the controller node, this is to ease future expansion.

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

8. Create a default OS image::

    # ansible-playbook compute.yml

Now you have your controller(s) installed and the default OS image created!


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

A pre-built PDF is provided in the main directory. To build the full set of the documentation included with TrinityX:

1. Install ``git``::

    # yum install git

2. Clone TrinityX repository into your working directory and go to the directory containing the documentation::

    # git clone http://github.com/clustervision/trinityx
    # cd trinityX/doc

3. Install ``pip``, e.g. from EPEL repository::

    # yum install python3-pip.noarch

4. Install ``sphinx`` and ``Rinohtype``::

    # pip3.4 install sphinx Rinohtype

6. Build the PDF version of the TrinityX guides::

   # sphinx-build -b rinoh . _build/

If everything goes well, the documentation will be saved as ``_build/TrinityX.pdf``


Contributing
============

To contribute to TrinityX:

1. Get familiar with our `code guidelines <Guidelines.rst>`_
2. Clone TrinityX repository
3. Commit your changes in your repository and create a pull request to the ``dev`` branch in ours.

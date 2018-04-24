Overview
========

Welcome to TrinityX!

TrinityX is the new generation of ClusterVision's open-source HPC platform. It is designed from the ground up to provide all services required in a modern HPC system, and to allow full customization of the installation. Also it includes optional modules for specific needs, such as an OpenStack cloud and Docker on the compute nodes.

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


Steps to install TrinityX
~~~~~~~~~~~~~~~~~~~~~~~~~

1. Install CentOS Minimal on your controller(s)

2. Configure network interfaces that will be used in the cluster, e.g public, provisioning and MPI networks

3. Configure passwordless authentication to the controller itself or/and for both controllers in the HA case

4. Setup luna repository::

    # curl https://updates.clustervision.com/luna/1.2/centos/luna-1.2.repo > /etc/yum.repos.d/luna-1.2.repo

5. Install ``git``, ``ansible`` and ``luna-ansible``::

    # yum install git ansible luna-ansible

6. Clone TrinityX repository into your working directory and go to the site directory::

    # git clone http://github.com/clustervision/trinityx
    # cd trinityX/site

7. Based on whether you're installing a single-controller or a high-availability (HA) setup, you might want to update the configuration files:

   * ``group_vars/all``

   **Note**: In the case of an HA setup you will most probably need to change the default name of the shared block device set by ``shared_fs_device``.

   You might also want to check if the default firewall parameters apply to your situation in the firewalld role in ``controller.yml``::

      firewalld_public_interfaces:
        - eth2
      firewalld_trusted_interfaces:
        - eth0
        - eth1

8. Install ``OndrejHome.pcs-modules-2`` from the ansible galaxy::

    # ansible-galaxy install OndrejHome.pcs-modules-2

9. Configure ``hosts`` file to allow ansible to address controllers.

   Example for non-HA setup::

       [controllers]
       controller ansible_host=10.141.255.254

   Example for HA setup::

       [controllers]
       controller1 ansible_host=10.141.255.254
       controller2 ansible_host=10.141.255.253

10. Start TrinityX installation::

     # ansible-playbook controller.yml

    **Note**: If errors are encoutered during the installation process, analyze the error(s) in the output and try to fix it then re-run the installer.

    **Note**: By default, the installation logs will be available at ``/var/log/trinity.log``

11. Create a default OS image::

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

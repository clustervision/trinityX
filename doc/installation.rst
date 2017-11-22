
TrinityX installation procedure
================================

This document describes the installation of a TrinityX controller, as well as the creation and configuration of an image for the compute nodes of a TrinityX cluster.

Starting with the 11th release, Ansible is fully integrated into TrinityX. This allows for a lot of flexibility when installing a cluster.
While the procedure to create compute images needs to be run from the cluster controller (the primary controller when in HA mode) the installation procedure of the controllers themselves can be run from any arbitrary machine (including your laptop).

The requirements for this system, as well as for the compute nodes, are decribed in the :doc:`requirements`. It is assumed that the guidelines included in this document have been followed, and that the controller machines are ready for the TrinityX configuration.


Controller installation
-----------------------

The TrinityX configuration tool will install and configure all packages required for setting up a working TrinityX controller.

The configuration for a default controller installation is described in the file called ``site.yml``, as well as the files located in the ``group_vars/`` subdirectory of the TrinityX tree, while the list of machines to which the configuration needs to be applied is described in the file called ``hosts``::

    # pwd
    ~/trinityX
    
    # ls hosts site.yml group_vars/
    hosts  site.yml
    
    group_vars/:
    all  controllers


These files can be edited to reflect the user's own installation choices. All configuration parameters are included and described. Once the configuration file is ready, the ``site.yml`` ansible playbook  will apply the configuration to the controller::

    # pwd
    ~/trinityX
    
    # ls hosts site.yml
    hosts  site.yml
    
    # ansible-playbook -i hosts site.yml

For further details about the use of ansible, including its command line options, please consult the `official ansible documentation <https://docs.ansible.com/>`_.

For further details about the configuration files, please see :doc:`config_cfg_files`.


Compute node image creation
---------------------------

The creation and configuration of an OS image for the compute nodes uses the same tool and a similar configuration file than for the controller. While the controller configuration applies its setting to the machine on which it runs, the image configuration does so in a directory that will contain the whole image of the compute node.

.. note:: Building a new image isn't required for most system administration tasks. One of the images existing on your system can be cloned and modified, then added to the provisioning tool. Creating a new image is only useful for an initial installation, or when desiring to start from a clean image.


Again, the setup of the image is defined in the playbook ``images.yml``, which controls the creation of the directory and running the configuration.


In the vast majority of cases, changing the configuration of the default image is not required. Creating it is done as simply as when setting up the controller::

    # ansible-playbook image.yml

.. note:: The location of the new image is displayed as one of the last messages from the creation and setup process.

After the configuration has completed, the node image is ready and integrated into the provisioning system. No further steps are required.


Offline installation
--------------------

The configuration tool relies on the built-in package management commands of the operating system: ``yum`` and ``rpm`` in the case of CentOS. By default those commands pull the packages that they require from online repositories. For the rare cases where an offline installation is required, the TrinityX configuration tool provides support for using local repositories.

.. note:: When doing an offline installation, you may want to disable all remote repositories. This will save time as ``yum`` won't try to connect to remote repositories. Make sure to read all documentation and READMEs before, and remember that all required packages must be available in one of the local repositories.

Local repositories
~~~~~~~~~~~~~~~~~~

The TrinityX configuration tool copies the whole ``packages`` folder over to the controller, and sets up the repository files to make it available to yum as a source of packages. The matching ``.repo`` files are located in a subfolder of the installer::

    # pwd
    ~/trinityX
    
    # ls -F packages
    local-repo/  pacemaker/  README.rst
    
    # ls -l configuration/controller/local-repos
    total 12
    -rw-r--r-- 1 root root 120 Aug 11 14:47 local-repo.repo

.. note:: The repo file base names must be the same as the folder names.

Each repo file configures the local repository contained in one folder, for example::

    # cat configuration/controller/local-repos/local-repo.repo 
    [local-repo]
    name=TrinityX - local repository
    baseurl=file://TRIX_ROOT/shared/packages/local-repo
    enabled=1
    gpgcheck=0

.. note:: The string ``TRIX_ROOT`` will be replaced at installation time by the installation path of TrinityX. The last part of the ``baseurl`` line (``packages/local-repo``) is the name of the folder in which the local repository resides.

The first option for an offline installation is to make full local mirrors of the repositories required by the installer, in the ``packages`` folder before installation. This has the advantage of making all packages available to a fully disconnected system, at the cost of gigabytes of storage space.

Various methods for creating local mirrors from DVD images or online sources are described in `Creating Local Mirrors for Updates or Installs <https://wiki.centos.org/HowTos/CreateLocalMirror>`_.

The exact list of repositories required for a specific installation depends on the post scripts selected in the configuration file. As of TrinityX release 1, those are:

- base system: CentOS (including updates and extras), EPEL, ELRepo, OpenHPC

- Zabbix post script: Zabbix, Zabbix non-supported

.. note:: The configuration tool requires the group list for the base CentOS repo to be available, see `Group files`_ for details.


Test installation
~~~~~~~~~~~~~~~~~

Instead of making absolutely all packages from all repositories available, the second option for an offline installation is to provide only what is needed.

There are multiple ways of doing so. One of them is to do a test installation in a virtual machine with Internet access first, and copy all the packages from that controller VM to the installation media. Due to the way the configuration script works, this will include all the packages for the controller as well as for the images, if a node image is built.

.. note:: Make sure that the option ``YUM_PERSISTENT_CACHE`` is enabled in the configuration file before installation. This will configure ``yum`` to keep all downloaded files instead of deleting them after installation.


The procedure starts with a full configuration of the controller and the image::

    # ./configure.sh controller.cfg
    
    # ./configure.sh images-create-compute.cfg


Then all rpm files are copied to the installation media that will be used for the offline installation. It is assumed to contain the full TrinityX tree already, and therefore contains the ``packages`` directory. We can make use of the ``local-repo`` subdirectory as it comes with a repo file already::

    # MEDIAPATH=/path/to/your/media
    
    # rsync -raW /var/cache/yum/x86_64 ${MEDIAPATH}/trinityX/packages/local-repo/


And finally, rebuild the repository index::

    # createrepo -v --update --compress-type bz2 \
        -g ${MEDIAPATH}/trinityX/packages/local-repo/x86_64/7/base/gen/comps.xml \
        ${MEDIAPATH}/trinityX/packages/local-repo

.. note:: The command above includes the group file, which is required by the configuration tool. See `Group files`_ for details.


Group files
~~~~~~~~~~~

YUM supports group files, which are a convenient way of installing sets of packages at once. Those group files are provided with the repository metadata if the repos have been created with group definitions, which are XML files.

The TrinityX configuration makes use of groups to install the base OS for node images. When installing from online repos, the necessary group files are available. When installing from local repos, the user must make sure that the group definitions are still available.

As the XML files are hard to edit by hand and may change from subrelease to subrelease, the easiest way to provide a group file in your local repo is to re-use the upstream group file. If you obtained your packages through a `Test installation`_, all packages described in the file may not be available in the local repo. The ones required by the TrinityX configuration tool will be, as they have all been downloaded already.

The name of the group file is usually ``comps.xml``, altough sometimes it can be found under ``groups.xml``. As of TrinityX release 1, only the groups for the base CentOS repository are needed. Adding a group file is done with the ``-g`` flag to ``createrepo``; see `Test installation`_ for an example of usage.

When the local repository was created with the correct group files, the output of this command should be very similar even when all remote repos are disabled::

    # yum groupinfo minimal
    
    Environment Group: Minimal Install
     Environment-Id: minimal
     Description: Basic functionality.
     Mandatory Groups:
        core
     Optional Groups:
       +debugging


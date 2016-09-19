
Trinity X installation procedure
================================

This document describes the installation of a Trinity X controller, as well as the creation and configuration of an image for the compute nodes of a Trinity X cluster.

Both procedures run on the machine that will be used as the controller. The requirements for this system, as well as for the compute nodes, are decribed in the `Trinity X pre-installation requirements`_. It is assumed that the guidelines included in this document have been followed, and that the controller machine is ready for the Trinity X configuration.


Controller installation
-----------------------

The Trinity X configuration script will install and configure all packages required for setting up a working Trinity X controller.

The configuration for a default controller installation is described in the file called ``controller.cfg``, located in the ``configuration`` subdirectory of the Trinity X tree::

    # pwd
    ~/trinityX
    
    # cd configuration
    
    # ls controller.cfg 
    controller.cfg


This file can be edited to reflect the user's own installation choices. All configuration parameters are included and described Once the configuration file is ready, the script ``configure.sh`` will apply the configuration to the controller::

    # pwd
    ~/trinityX/configuration
    
    # ls controller.cfg configure.sh
    configure.sh  controller.cfg
    
    # ./configure.sh controller.cfg

For further details about the use of the configuration script, including its command line options, please see `Trinity X configuration tool`_

For further details about the configuration files, please see `Configuration files`_.


Compute node image creation
---------------------------

The creation and configuration of an OS image for the compute nodes uses the same script and and a similar configuration file than for the controller. While the controller configuration applies its setting to the machine on which it runs, the image configuration does so in a directory that will contain the whole image of the compute node.

.. note:: The location of the new image is displayed as one of the last messages from the creation and setup process.


Again, the setup of the image is defined in configuration scripts. Each image requires two scripts:

- ``images-create-compute.cfg``, which controls the creation of the directory and the base setup, *including calling the second script*;

- ``images-setup-compute.cfg``, which controls the installation and setup inside that directory.

.. note:: You do not need to call the second script (``images-setup-compute.cfg``) by hand. This is done automatically by the creation script, which passes additional parameters to the setup script.


In the vast majority of cases, changing the configuration of the default image is not required. Creating it is done as simply as when setting up the controller::

    # ./configure.sh images-create-compute.cfg

After the configuration has completed, the node image is ready but not yet integrated into any provisioning system. The steps required for that operation are described in the documentation of the provisioning system installed on your site.


Offline installation
--------------------

Local repositories
~~~~~~~~~~~~~~~~~~

Test installation
~~~~~~~~~~~~~~~~~



TrinityX
========

Welcome to TrinityX!

TrinityX is the new generation of ClusterVision's open-source HPC platform. It is designed from the ground up to provide all services required in a modern HPC system, and to allow full customization of the installation. Also it includes optional modules for specific needs, such as an OpenStack cloud, Docker on the compute nodes and the ability to partition a cluster.

The full documentation is available in the ``doc`` subdirectory.


Quick start for the impatients
------------------------------

- Install CentOS Minimal on your controller

- Do the full network configuration as required by your setup

- Run the following commands::

    yum install git
    git clone http://github.com/clustervision/trinityx
    cd trinityX/configuration

- Edit controller.cfg to suit your needs (most defaults are correct, you will need to adjust the network parameters)

- Run::

    ./configure.sh controller.cfg images-create-compute.cfg |& tee -a /var/log/trinity-installer.log


This will set up the controller with the default configuration, then create and set up a compute image.


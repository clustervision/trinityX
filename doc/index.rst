
Trinity X
=========

Introduction
------------

Welcome to the TrinityX documentation!

TrinityX is the new generation of ClusterVision's open-source HPC platform. It is designed from the ground up to provide all services required in a modern HPC system, and to allow full customization of the installation. Also it includes optional modules for specific needs, such as an OpenStack cloud and Docker on the compute nodes.

A standard TrinityX installation includes many software components, such as Slurm, MariaDB, OpenLDAP, or even CentOS, the operating system on which everything runs. All of those pieces of software are documented separately and their documentation can be accessed freely on the internet. In order to avoid duplicating existing documentation, the TrinityX documentation will only include chapters about external software when required, for example to describe a non-standard setup. For everything else, please refer to the original documentation of each piece of software.

Documentation
-------------

.. note::
    Each TrinityX installation is adapted to the specific requirements of the customer, and the list of installed software varies.

The documentation is split into various chapters, each of which dealing with a specific topic. They are grouped into three manuals:

- the :ref:`Installation manual` on how to deploy TrinityX on your system;

- the :ref:`Administration manual` for system administrators managing a production TrinityX system;

- and the :ref:`User manual` for cluster users.

Although each manual is destined to a specific audience, there may be hyperlinks from one manual to another when more advanced reading is suggested.


.. toctree::
   :maxdepth: 1
   :hidden:

   installation_manual.rst


.. toctree::
   :maxdepth: 1
   :hidden:

   administration_manual.rst
  
  
.. toctree::
   :maxdepth: 1
   :hidden:
  
   user_manual.rst
  
Docker documentation
~~~~~~~~~~~~~~~~~~~~

If the configuration with Docker is used, the following guide provides information on running jobs.
  
.. toctree::
   :maxdepth: 1
     
   running_docker_jobs.rst
  

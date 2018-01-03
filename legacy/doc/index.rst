
Trinity X documentation
=======================

Introduction
------------

Welcome to the TrinityX documentation!

TrinityX is the new generation of ClusterVision's open-source HPC platform. It is designed from the ground up to provide all services required in a modern HPC system, and to allow full customization of the installation. Also it includes optional modules for specific needs, such as an OpenStack cloud, Docker on the compute nodes and the ability to partition a cluster.

A standard TrinityX installation includes many additional pieces of software, such as Slurm, MariaDB, OpenLDAP, or even CentOS, the operating system on which everything runs. All of those projects are documented separately, and the relevant documentation either has been provided to you after installation, or is available freely on the internet. In order to avoid duplicating existing documentation, the TrinityX documentation will only include chapters about external software when required, for example to describe a non-standard setup. For everything else, please refer to the original documentation of each piece of software.

.. note::
    Each TrinityX installation is adapted to the specific requirements of the customer, and the list of installed software varies.


The documentation is split into various chapters, each of which dealing with a specific topic. They are grouped into three manuals:

- the `Engineering documentation`_ for engineers deploying TrinityX systems and developers writing post scripts;

- the `Administator's manual`_ for system administrators managing a production TrinityX system;

- and the `User's manual`_ for cluster users.

Although each manual is destined to a specific audience, there may be hyperlinks from one manual to another when more advanced reading is suggested.



Engineering documentation
-------------------------

Installation
~~~~~~~~~~~~

.. toctree::
   :maxdepth: 1
   
   requirements.rst
   ps_controller_storage.rst
   ha_design.rst
   installation.rst
   installation_openstack.rst


Configuration tool
~~~~~~~~~~~~~~~~~~

- General use

.. toctree::
   :maxdepth: 1
   
   config_tool.rst
   config_cfg_files.rst

- Development

.. toctree::
   :maxdepth: 1
   
   config_post_scripts.rst
   config_env_vars.rst
   config_common_funcs.rst


Administator's manual
---------------------

.. note::
    Some parts of the `Engineering documentation`_ may be useful to system administrators, especially :doc:`config_tool` and :doc:`config_cfg_files`.


.. toctree::
   :maxdepth: 1

   user_management.rst

Hints and tips
~~~~~~~~~~~~~~

.. toctree::
   :maxdepth: 1
   
   hintsntips_trix.rst
   hintsntips_luna.rst


User's manual
-------------

Docker documentation
~~~~~~~~~~~~~~~~~~~~

.. toctree::
   :maxdepth: 1
   
   running_docker_jobs.rst


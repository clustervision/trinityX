
Post script environment variables
=================================

When a configuration post script contains a shell script part, this script runs in an environment that includes many additional environment variables. Some of them are only really useful for the configuration tool itself, while others are set for use by the script.


The variables fall into two categories:

- the `Variables from the configuration tool`_, which are set by the tool;

- and the `Variables from files`_, which are set when sourcing various files.


All of those variables have a local scope: they are defined or loaded in a fresh subshell for each script, and that environment is destroyed when the script exits. Although there are certainly multiple tricks to create variables that escape that destruction, the configuration tool defines files, functions and conventions to manage the persistent storage of system-wide configuration options. See `Variables from files`_ for more details.



Variables from the configuration tool
-------------------------------------

The configuration tool defines only a few dynamic variables:

- ``POST_TOPDIR``
    
    The top directory of the TrinityX installation scripts.
    
    The TOPDIR is used to access data that is not part of the configurationt tool's tree, or is too big to be stored there. For example, the repositories managed by the ``local-repos`` post script, which are optional and created outside of the configurationt tool itself, reside in ``${POST_TOPDIR}/packages``. The configuration tool itself lives in a subdirectory of the ``POST_TOPDIR``: ``${POST_TOPDIR}/configuration``.


- ``POST_CONFDIR``

    The directory containing the configuration file being processed. This is only really useful when sourcing another config file -- see :doc:`config_cfg_files` for more details.


- ``POST_CONFIG``
    
    The full path of the configuration file being processed.
    
    Before the configuration tool sourced that file automatically, the scripts that needed configuration variables had to source it themselves. This variable is now deprecated, and is maintained for compatibility only.


- ``POST_FILEDIR``
    
    The full path of the script's private directory, if it exists.
    
    Post scripts can contain a private subdirectory in which they can store the files that they require (configuration files, subscripts, etc). That directory is optional, and the variable is defined only if an actual directory exists in the filesystem.
    
    The name of the directory itself is inferred from the name of the post script, see :doc:`config_post_scripts` for the naming rules.

- ``POST_CHROOT``

    The path of the chroot directory used for this configuration file. If not running in a chroot (i.e. for a standard configuration on a controller), this variable will not exist.



Variables from files
--------------------

The main sources of variables available to the scripts are the following files. Those files are all sourced in the shell environment before the script is executed, so no additional sourcing is required.


Current configuration file
~~~~~~~~~~~~~~~~~~~~~~~~~~

The current configuration file is always loaded into the environment. Any configuration option defined in it is available as an environment variable.

The exact contents of this file depend on the configuration created for installation. See the documentation for each post script and the contents of ``controller.cfg`` and other configuration files for more details.


/etc/trinity.sh
~~~~~~~~~~~~~~~

``/etc/trinity.sh`` contains system-wide variables about the state of the system, as configured and installed. ``/etc/trinity.sh`` is in fact a symlink to the actual file, as its location is subject to change depending on the system configuration. In all cases that symlink exists in ``/etc``, pointing to the correct file for that system.

This file does not exist before the installation of Trinity. It is created by the post script called ``standard-configuration``, which is one of the very first ones to run.

The standard variables defined at the creation of the file are:


==================  ==========================================================
``TRIX_VERSION``    The version number of Trinity at installation time

``TRIX_ROOT``       The root path of the Trinity installation

``TRIX_HOME``       The location of the user home directories

``TRIX_IMAGES``     The location of the node images

``TRIX_SHARED``     The shared folder exported to the nodes

``TRIX_APPS``       The root folder for additional applications

``TRIX_SHFILE``     The actual path of the ``trinity.sh`` file

``TRIX_SHADOW``     The path of the `Shadow file`_

==================  ==========================================================


By convention, all values stored in the file start with the string ``TRIX_``. This is done in order to avoid namespace issue between those system-wide values, and anything coming from a configuration file.

In a completely standard installation, the initial state would look like this::

    # TrinityX environment file
    # Please do not modify!
    
    TRIX_VERSION="10"
    
    TRIX_ROOT="/trinity"
    TRIX_HOME="/trinity/home"
    TRIX_IMAGES="/trinity/images"
    TRIX_SHARED="/trinity/shared"
    TRIX_APPS="/trinity/shared/applications"
    
    TRIX_SHFILE="/trinity/shared/trinity.sh"
    TRIX_SHADOW="/trinity/trinity.shadow"
    
    if [[ "$BASH_SOURCE" == "$0" ]] ; then
        echo "$TRIX_VERSION"
    fi


Post scripts can add variables to that file, with a few rules:

- those variables must either represent the state of a given subsystem, or information that other post scripts will need;

- they must in no case serve a private communication mechanism between different post scripts (redesign your scripts if you find yourself in that situation);

- for sanity reasons the functions provided must be used (i.e. no direct access to the file -- see `Setting persistent variables`_ for details).


Shadow file
~~~~~~~~~~~

The shadow file is the file containing the passwords for various subsystems of Trinity: LDAP admin, databases, web UIs, etc.

When a service requires a password, the post script can either use one provided by the user (configuration option, private password file, etc), or use the ``get_password`` function to generate a random one. As the installation files might be on removable media and not available after the initial configuration, in all cases we need to store the password somewhere. That is the role of the shadow file.

This file does not exist before the installation of Trinity. Its contents are entirely configuration-dependant.



Setting persistent variables
----------------------------

Adding a variable or changing the state of a variable, both in ``trinity.sh`` and in the shadow file, is done through shell functions preloaded in the environment. Those are:

- ``store_variable``, to record or update a variable;

- ``get_password``, to get a new random password;

- ``store_password``, to store a password in the shadow file.


Always use those functions to manipulate the state of the variables in those files.

See :doc:`config_common_funcs` for the full syntaxes and descriptions.


Visibility of new variables
~~~~~~~~~~~~~~~~~~~~~~~~~~~

As all of those files a sourced each time a script is ran, all changes to either ``trinity.sh`` or the shadow file will be automatically visible by all subsequent post scripts.


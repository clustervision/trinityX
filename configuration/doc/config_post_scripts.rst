
.. vim: tw=0


Configuration post scripts
==========================

The Trinity X configuration tool revolves around the concept of post-installation scripts, or *post scripts*. After the installation of the base OS, the configuration tool will install packages and run an arbitrary list of those post scripts to implement the Trinity X configuration. Those scripts deal typically with one piece of software only or the configuration of one specific area of the system. Most of them are optional, allowing for a high level of control over the final state of the system. 


Configuration files
-------------------

At the highest level, a Trinity X installation is defined in one (or more) configuration file(s). Those are valid shell files, that are sourced by the configuration tool to obtain the list of post scripts to run, as well as the configuration options for those post scripts. By tradition those files have the ``.cfg`` extension, but there is no hard rule over their naming.

The contents of the configuration file are loaded into the shell environment prior to the execution of the scripts (see `Components of a post script`_ for more details). That way, configuration options can be set for each post script in the configuration file, and they will be available as environment variables.


At the absolute minimum, two variables must be set in any configuration file:

- ``POSTDIR``:
    The base directory for the post scripts. If it's not an absolute path, then it will be treated as relative to the directory in which the configuration file resides. It can be set to ``"."`` for the exceptional case when the post scripts are in the same directory as the configuration file.

- ``POSTLIST``:
    The list of post scripts to run. They will be processed in the order in which they are listed in the configuration file. Note that this is a Bash array, and therefore the syntax is: ``POSTLIST=( ps1 ps2 ...)``. The name of each post script must obey some rules, see `Components of a post script`_ for more details.


After processing each post script, the configuration tool checks the return code of the shell script. If it is not ``0`` (the standard UNIX return value for success), the default behaviour will be to display an error message and pause the processing of the post scripts. This can be changed through the use of command line parameters when calling the configuration tool; see the tool's documentation for more information.

For more details about return codes, see `Environment variables and return codes <file://config_env_vars.rst>`_.


Components of a post script
---------------------------

A post script is made up of multiple distinct files and a directory, each with a different role. All of them are optional, so that any post script can provide only what is necessary for its purpose.

Those files must share their basename (i.e. the filename without any extension), and that basename is the name of the post script as a whole. Even if the post script is only made of one shell script, called ``myscript.sh`` for example, for the purpose of the configuration tool the name of the post script is ``myscript``, not ``myscript.sh``.

In the order in which they are processed by the configuration tool, the files are:

- a list of yum package groups to install, with the extension ``.grplist``;

- a list of packages to install, with the extension ``.pkglist``;

- a valid Bash script with the extension ``.sh``;

- a directory that contains additional files that may be required by your script, without any extension.

The groups are installed first, then the packages, then the script is executed. The directory itself is not touched by the configuration script. Its path is exported to the script via a shell enviromnent variable (``POST_FILEDIR``) so that the script can manage an additional set of private files that reside in that directory. Note that if the directory doesn't exist, then the environment variable will be unset.

As all of those files are optional, no error message will be displayed if any of them doesn't exist. If none exists, then it will be treated as if the shell script exited with an error code.



Rules for post script creation
------------------------------

- Do not install packages directly from the shell script. Instead, create a matching ``.grplist`` or ``.pkglist`` for those.

- Do not store big binary files in the post script directory, or anywhere really. Git doesn't like that. If it's an RPM then ship in in the local repo. If it's a shared application, put it with other apps.

- If you really have to chose between mutually exclusive sets of packages (for example Nagios + Ganglia vs. Zabbix), create multiple post scripts that can be toggled on and off. Especially for different versions of a given package, or support for different CentOS releases,write separate post scripts.

- Feel free to append information to ``/etc/trinity.sh``, as long as it's only environment variables and it's pertinent. This file is sourced automatically and its contents made available to all post scripts. See `Environment variables and return codes <file://config_env_vars.rst>`_ and `Common functions <file://config_common_funcs.rst>`_ for more details and the correct way to do so.

- Try to make your scripts as `idempotent <https://en.wikipedia.org/wiki/Idempotence>`_ as possible, that is; being able to run multiple times without changing the results beyond those of the first run. Some functions are provided to help with that goal, those are described in `Common functions <file://config_common_funcs.rst>`_.

- At the very least, make sure that the shell script doesn't do any damage when the state of the system at the beginning of execution is not what expected. In other words, don't make too many assumptions and do a few checks at the beginning. The sane default behaviour when a configuration already exists is to wipe it and start clean (big red reset button), in the future a flag may be provided to change that default.


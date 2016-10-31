
Configuration files
===================

At the highest level, a TrinityX installation is defined in one (or more) configuration file(s). Those are valid shell files, that are sourced by the configuration tool to obtain the list of post scripts to run, as well as the configuration options for those post scripts. By tradition those files have the ``.cfg`` extension, but there is no hard rule over their naming.



Configuration file contents
---------------------------

The contents of the configuration file are loaded into the shell environment prior to the execution of the scripts. That way, configuration options can be set for each post script in the configuration file, and they will be available as environment variables.


At the absolute minimum, the configuration tool needs the following two variables:

- ``POSTDIR``:
    The base directory for the post scripts. If it's not an absolute path, then it will be treated as relative to the directory in which the configuration file resides. It can be set to ``"."`` when the post scripts are in the same directory as the configuration file. If not set, the default behaviour is to assume that the directory has the same name as the configuration file's basename (for example: ``controller.cfg`` -> by default ``POSTDIR=controller``).

- ``POSTLIST``:
    The list of post scripts to run. They will be processed in the order in which they are listed in the configuration file. Note that this is a Bash array, and therefore the syntax is: ``POSTLIST=( ps1 ps2 ...)``. The name of each post script must obey some rules, see :doc:`config_post_scripts` for more details.


After processing each post script, the configuration tool checks the return code of the shell script. If it is not ``0`` (the standard UNIX return value for success), the default behaviour will be to display an error message and pause the processing of the post scripts. This can be changed through the use of command line parameters when calling the configuration tool; see the :doc:`config_tool` chapter for more information.



List of configuration options
-----------------------------

As each post script can define its own configuration options and may not be well documented, obtaining an authoritative list of all possible configuration options is not obvious.

The current consensus is that the file ``controller.cfg`` contains the complete list of all options, with as much documentation as possible. Each post script writer is responsible for adding its options and corresponding descriptions to the file. Until a new system is figured out, this is as good as it gets.



Creating new configuration files
--------------------------------

Creating a configuration file for a new project is quite straightforward. The simplest way is to copy ``controller.cfg`` and to edit it to match the required configuration. The final configuration file is self-contained, but any update to ``controller.cfg`` has to be carried over by hand.

As the configuration files are valid Bash scripts too, it is also possible to source ``controller.cfg`` at the very top of the new configuration file, and then only set the variables that differ from the default values.

Assuming that the new configuration file resides in the same directory as ``controller.cfg``, this will work::

   source "${POST_CONFDIR}/controller.cfg"


The list of post scripts can be either redefined (``POSTLIST=( ... )``), or appended to (``POSTLIST+=( ... )``), depending on whether the new config file defines a full installation or an additional layer only.


Order of post scripts
~~~~~~~~~~~~~~~~~~~~~

The order of post scripts in the configuration file is important as some post scripts depend on the successful processing of others before running. Currently the configuration tool doesn't provide any way to express any form of requirement between post scripts. The basic list contained in ``controller.cfg`` works in that order, but may not if changed.

Until a better solution is implemented, exert caution when changing the order of post scripts.


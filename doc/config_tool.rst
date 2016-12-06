
TrinityX configuration tool
============================

The TrinityX configuration tool is used for the basic configuration of the controllers, as well as the creation and configuration of the node images.

The core idea behind that tool is to have a modular post-installation configuration system, so that various packages and configuration steps are optional and can be turned on and off depending on the required configuration. To that effect, the configuration tool runs a set of post-installation scripts and installs the packages required by those scripts. And that's about it.

It is *not* a full-blown configuration manager. Amongst other things, as of the time of writing it can't undo a configuration. That limitation means that it is only suited to an initial configuration, and not to updating configurations later.

This document will present the high-level use of the tool. For more details, including how to write new post scripts, please see the other chapters of the :doc:`index`.



Overview
--------

There are two main concepts known to the tool: configuration files, and post scripts.


Configuration files
~~~~~~~~~~~~~~~~~~~

Configuration files are standard shell scripts that are sourced by the tool to know what it has to do. Amongst other things, they contain the list of post scripts that will be processed by the configuration tool.


Post scripts
~~~~~~~~~~~~
  
Post scripts are the individual tasks that make up the configuration of the system. Any given post script may request the installation of packages, may run a shell script to do some configuration, and may come with additional files in a
private subdirectory.



Usage
-----

Running the configuration tool is very simple::

    ./configure.sh [options] <config_file> [<config_file> ...]

It will load each configuration file named in the parameters in order, and run all scripts in each of those files.

The tool is not immensely smart. It will stop on errors and ask for the user to press Enter to continue, so as to give the possibility to do some manual fixing before continuing. But it doesn't do any conditional execution based on return codes, and therefore it will run all scripts, all the time.

As it asks for user input when things go wrong, its output cannot be entirely redirected to a file. The easiest way to keep a log of the installation is::

    ./configure.sh file.cfg |& tee -a your_log_file

``tee`` will keep the output on the terminal and write a copy to the log file.

The color output is automatically disabled if the script detects that its output is not an interactive TTY.


Alternate syntax
~~~~~~~~~~~~~~~~

In normal use the list of post scripts to execute is a configuration option, specified in the config file. Changing the scripts requires editing the file. There are cases when this is cumbersome (testing, re-running a failed script), so the configuration tools supports an alternate syntax::

    ./configure.sh [options] --config <config_file> [<post script> ...]

This alternate syntax is used to run a specific set of post scripts, within the configuration environment provided by the config file. When the ``--config`` option is encountered in the argument list, the following happens:

- the next argument is the configuration file;

- all the remaining arguments are the names of the scripts to run.

The names of the scripts obey the same rules as within the configuration file: they are base names (no extensions and no directories), and must reside within the ``POSTDIR`` specified in the configuration file.

Any list of post scripts specified inside the configuration file (variable ``POSTLIST``) is ignored, and only the chosen scripts are run.

It is possible to mix regular configuration files with chosen scripts, as long as the chosen scripts are last and the sequence is respected. For example, this is perfectly valid::

    ./configure.sh 1.cfg -d --config 2.cfg script1 script2

The scripts specified in the ``POSTLIST`` of ``1.cfg`` will run first, in standard mode. Then the two additional ones will run in debug mode, in the configuration environment of ``2.cfg``.


Parameters
~~~~~~~~~~

The complete list of command line parameters is:

- ``-v``
    Gives a more verbose output than normal.

- ``-q``
    Gives a quieter output than normal.

- ``-d``
    Runs all post scripts in full debug mode (``bash -x``)


The following options are mainly useful for automated testing:

- ``--nocolor``
    Display all output messages without any color.
    Note that this only applies to the messages coming from the configuration tool itself; other commands called by post scripts may still use colors. Also, redirecting the tool's output (to a pipe or file) disables the colors automatically.

- ``--step``
    Pause after each post script, and wait for user input before continuing.

- ``--continue``
    Do not stop for user input when an error occurs.

- ``--stop``
    Soft stop: exit the configuration tool when any post script returns an error code. This is not default as not all post scripts have correct error code management.

- ``--hardstop``
    Hard stop: exit both the current post script and the configuration tool when any error of any form happens in the shell script. This may be overkill in a lot of cases as there are legitimate situations where a post script may not care about the return code of any command within, including an error, yet will be terminated. (Think of ``grep`` returning a non-zero code when the string doesn't match anything, for example.)

- ``--chroot <dir>``
    Apply the configuration(s) inside a chroot to ``<dir>``. This is the way through which node images are configured. Note that it is also possible to define a ``CHROOT`` variable in a configuration file, for the same purpose. If both are used, the command line flag will have precedence over the configuration file option.


A few additional rules:

- ``-v`` and ``-q`` are mutually exclusive;

- ``--continue`` is mutually exclusive with ``--stop`` / ``--hardstop`` and ``--step``;

- ``--hardstop`` selects ``--stop`` too.


In the main syntax form, all options are positional: they apply only to the configuration files after them on the command line. In the alternate syntax form, all options must be specified *before* ``--config``.



Example
-------

A very simple example of a post script is provided in the same directory as the configuration tool. It displays the various environment variables that are made available to the Bash scripts.

Running it is, again, very easy::

    ./configure.sh example.cfg

This will give you an idea of what to expect from the running of the configuration tool.



Trinity X configuration tool
============================

This folder contains the configuration tool used for the basic installation of
Trinity X controllers.

The core idea behind that tool is to have a modular post-installation
configuration system, so that various packages and configuration steps are
optional and can be turned on and off depending on the required configuration.
To that effect, the configuration tool runs a set of post-installation scripts
and installs the packages required by those scripts. And that's about it.

It is *not* a full-blown configuration manager. Amongst other things, as of the
time of writing it can't undo a configuration, nor does it support conditional
execution of scripts. Those limitations mean that it is only suited to an
initial configuration, and not to updating configurations later.

This document will present the high-level use of the tool. For more technical
details, including how to write new post scripts, please see the contents of
the **doc** directory.



Overview
--------

There are two main concepts known to the tool.


Configuration files
~~~~~~~~~~~~~~~~~~~

Configuration files are standard shell scripts that are sourced by the tool (as
well as various post scripts) to know what it has to do.

At the very least they must contain those two environment variables:

- ``POSTDIR``
    The base directory in which the post scripts are located.
    If it is a relative path, then it is relative to the directory where the
    configuration file is located.

- ``POSTLIST``
    An array containing the names of the post scripts that have to be run
    for that specific configuration, in the order in which they will run. Note
    that there are rules to the name of the post script, see `Post scripts`_ for
    more details.

Usually the configuration file will also contain variables used by the post
scripts in the list.


Post scripts
~~~~~~~~~~~~
  
Post scripts are the individual tasks that make up the configuration of the
system. They are themselves made up of 3 different files. The name of those
files is based on the name of the postscript, i.e. they must match the entry in
the ``POSTLIST`` of the configuration file.

Assuming that the post script is called ``myscript``, those files would be:

- ``myscript.pkglist``
    A list of RPM packages to install first.

- ``myscript.sh``
    A Bash script to execute after the installation of the packages.

- ``myscript``
    A directory containing files required by the shell script, for example
    configuration templates for the specific software that was just installed.

All of those elements are optional. A post script may install packages, may
run a Bash script and may include a private directory. Technically it's possible
to have an entry in the ``POSTLIST`` that has none of there, in which case
nothing would be done.

For more information about writing postscripts, see the **doc** directory.



Usage
-----

Running the configuration tool is very simple::

    ./configure.sh file.cfg [file2.cfg ...]

It will load each configuration file named in the parameters in order, and run
all scripts in each of those files.

The tool is not immensely smart. It will stop on errors and ask for the user to
press Enter to continue, so as to give the possibility to do some manual fixing
before continuing. But it doesn't do any conditional execution, and therefore
will run all scripts, all the time.

As it asks for user input when things go wrong, its output cannot be entirely
redirected to a file. The easiest way to keep a log of the installation is::

    ./configure.sh file.cfg 2>&1 | tee -a your_log_file

``tee`` will keep the output on the terminal and write a copy to the log file.

If you are offended by color codes in your log files, use the ``--nocolor``
option.


Example
~~~~~~~

A very simple example of a post script is provided in the same directory as the
configuration tool. It displays the various environment variables that are made
available to the Bash scripts.

Running it is, again, very easy::

    ./configure.sh example.cfg

This will give you an idea of what to expect from the running of the tool.


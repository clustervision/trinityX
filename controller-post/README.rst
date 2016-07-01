
.. vim: si:et:ts=4:sw=4:tw=80


trinityX controller post-installation scripts
=============================================

This directory contains the various post-install scripts that are ran after
the OS installation on the controller, to bring it to the standard configuration
state of a trinityX system.



Base configuration
------------------

The following script does the very basic (and mandatory) configuration for all
trinityX systems::

    standard-post.sh

It takes no parameter, and must be ran first. All additional mandatory
configuration goes into this script.

.. note:: This should be kept as small as possible. Even for a piece of software
   that will be installed on most systems, having a separate file to manage it
   is often simpler. So think twice before adding anything in there, and if not
   sure it goes into a separate post script.



Optional scripts
----------------

trinityX contains a very lightweight tool to run an arbitrary number of post
installation scripts. It includes scripts for the most common tasks, and others
can be added easily (see `Adding an optional script`_ for more details).

The command to run the default list of post scripts is::

    optional-posts.sh

It contains a standard list of scripts that are likely to be needed on most
systems, but are kept separate for ease of maintenance or were made optional for
the odd site that doesn't need them.

.. note:: The term *script* is used in a very loose way here. It can be a shell
   script or a list of packages to install, or both, and it can have a
   dedicated directory for additional files. See `Adding an optional script`_
   for more details.

Tuning the list of post scripts can be done in two ways:


1. editing ``optional-posts.sh`` to comment out the scripts that are not needed;

2. calling ``optional-posts.sh`` by hand with the list of scripts in the order
   in which they must run.


The second case is very convenient for testing, and for special post scripts
that may require non-scripted configuration before running.

.. note:: The script name can be the actual name of a script, with a ``.sh``
   extension, or just the base name without extension. Internally the tool uses
   the base name and expands all path names from it.

.. note:: Why would one run ``optional-posts.sh myscript`` when (s)he could run
   ``./myscript.sh``? Well, the framework does a little bit more for you than
   just running one or more scripts. See `Adding an optional script`_ for more
   details.



Inter-script dependencies
-------------------------

All scripts that have dependencies on other scripts (that is, they must run
*after* a certain list of scripts), must be listed here.

=============== =========================== ===============================
Script name     Depends on                  Conflicts with
--------------- --------------------------- -------------------------------
sssd            openldap
=============== =========================== ===============================



trinityX environment variables
------------------------------

The basic configuration creates a script in the installation folder (usually
``/trinity``, with a symlink in ``/etc``::

    /trinity/trinity.sh
    /etc/trinity.sh -> /trinity/trinity.sh

It is designed to be sourced in trinityX scripts to obtain information about the
current installation::

    source /etc/trinity.sh

By default it defines two variables:

- ``TRIX_VERSION``
    The version of the current trinityX installation

- ``TRIX_ROOT``
    The root path of the current trinityX installation

Post scripts can append to this file to share further information about any
item of configuration that would be required by other scripts.

The environment script is also a valid shell script, and when executed (as
opposed to sourced) it will return the version number. For example::

    [root@controller ~]# bash /etc/trinity.sh 
    10



Adding an optional script
-------------------------

Adding a new script to the list is actually fairly easy. There are few strict
rules, and as it will run after complete installation (and not in a limited
Kickstart environment) you have access to all the normal Linux facilities.

A post script is composed of 3 parts, all optional. Assuming that you want to
call your post script ``newscript``, those are:


- a list of packages to install, with the extension ``.pkglist``:
  ``newscript.pkglist``;

- a valid Bash script with the ``.sh`` extension: ``newscript.sh``;

- a directory that contains additional files that may be required by your
  script: ``newscript`` (without any extension).


The packages named in the list, if it exists, are installed first with ``yum``.
Empty lines and lines starting with ``#`` are ignored.

Then the shell script, if it exists, is ran.

In both cases, if the command returns a non-zero code the configuration tool
will stop and wait for user input before continuing.

The directory is never accessed directly by the configuration tool. Anything in
there is stricty for the matching script.

.. warning:: In case of a typo in the name of the post script, neither the
   package list nor the shell script will be found. The configuration tool will
   not complain about this and continue running further post scripts.

Writing post scripts in another language is possible. In that case, the Bash
script (as it must be Bash) can be a wrapper which calls the actual
configuration script in its matching directory.



Post script environment variables
---------------------------------

The configuration tool exports multiple variables before calling the Bash
script. Those are:

- ``POST_TOPDIR``
  the very top level of the trinityX installation tree

- ``POST_PKGLIST``
  the package list name

- ``POST_SCRIPT``
  the Bash script name (so when reading it from within the script, this the
  same as ``$0``)

- ``POST_FILEDIR``
  the directory of that post script


Additional environment variables are available from the trinityX environment
file, see `trinityX environment variables`_ for details.

.. note:: There is no check done for the actual existence of those files and
   directory. Those are just the names as they are expected to be, made
   available to the script for ease of use.


Example of a test post script and its execution::

    [root@domina controller-post]# ls test*
    test.sh
    
    
    [root@domina controller-post]# cat test.sh 
    
    echo "POST_TOPDIR:  "$POST_TOPDIR
    echo "POST_PKGLIST: "$POST_PKGLIST
    echo "POST_SCRIPT:  "$POST_SCRIPT
    echo "POST_FILEDIR: "$POST_FILEDIR
    
    source /etc/trinity.sh
    
    echo "TRIX_VERSION: "$TRIX_VERSION
    echo "TRIX_ROOT:    "$TRIX_ROOT
    
    
    [root@domina controller-post]# ./optional-posts.sh test.sh 
    
    ################################################################################
    ####  List of post scripts to run:
    
    test.sh
    
    ####  Running post script: test
    No package file found: /root/trinityX/controller-post/test.pkglist
    
    POST_TOPDIR:  /root/trinityX
    POST_PKGLIST: /root/trinityX/controller-post/test.pkglist
    POST_SCRIPT:  /root/trinityX/controller-post/test.sh
    POST_FILEDIR: /root/trinityX/controller-post/test
    TRIX_VERSION: 10
    TRIX_ROOT:    /trinity



Rules for optional scripts
--------------------------

- Do not install packages directly from the script. Create a matching
  ``.pkglist`` for those.

- Do not store big binary files in the post script directory, or anywhere
  really. Git doesn't like that. If it's an RPM then it should be in the local
  repo. If it's a shared application it should be with other apps.

- If you really have to chose between different sets of packages, create
  multiple post scripts that can be toggled on and off. Especially for
  different versions of a given package, or support for different CentOS
  releases, make separate post scripts and make it obvious that they are
  mutually exclusive.

- Feel free to append information to ``/etc/trinity.sh``, as long as it's only
  environment variables and it's pertinent. This file may (will?) be sourced by
  other scripts to get installation information, so keep it short and to the
  point.

- Check your requirements carefully, especially on other post scripts, and
  document them in `Inter-script dependencies`_.

- Try to make your scripts as `idempotent
  <https://en.wikipedia.org/wiki/Idempotence>`_ as possible, that is being able
  to run multiple times without changing the results beyond those of the first
  run. It's really hard to achieve, for example when appending to configuration
  files, yet try to do it as much as possible.

- At the very least make sure that it doesn't do any damage if the initial
  configuration before the script runs, is not what is expected.


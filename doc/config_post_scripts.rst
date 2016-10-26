
Post scripts
============


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

In the group and package files, all non-empty lines and lines not starting with a ``#`` are assumed to contain only names of either groups or packages. In particular, comments on the same line as group / package names are not supported.

As all of those files are optional, no error message will be displayed if any of them doesn't exist. If none exists, then it will be treated as if the shell script exited with an error code, which will display an error message by default.



Rules for post script creation
------------------------------


Typical structure of the Bash script
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The Bash script for most post scripts should follow a standard structure::

    # Start with displaying the variables that you will need
    # No passwords there!
    
    display_var MYPS_VAR1 MYPS_VAR2
    
    
    # If using a password, get a random one if the environment variable was not set
    
    mypass="$(get_password "$MYPS_PWD")"
    
    
    # Now do something useful
    # Use the echo_* functions to indicate progress:
    
    echo_info "This is what I am doing first"
    
    # ...
    
    echo_info "Now I'm doing this"
    
    # ...
    
    
    # At the very end, store the password if and only if everything went right
    
    echo_info "Saving password to the shadow file"
    store_password "MYPS_PWD" "$mypass"
    
    
    # If using a common return code (sum of all return codes), remember to return it
    
    exit $ret



General rules
~~~~~~~~~~~~~

- Separate your code and data. In other words, as much as possible don't define whole configuration files as strings in the shell script. Some of it is unavoidable (changing an option value, appending a line, etc -- use the provided functions for that!), but if you're copying whole files, then use the post script's private directory and copy them from there. See ``POST_FILEDIR`` in :doc:`config_env_vars`.

- If you really have to chose between mutually exclusive sets of packages (for example Nagios + Ganglia vs. Zabbix), create multiple post scripts that can be toggled on and off by commenting them out in the configuration file. Especially for different versions of a given package, or support for different CentOS releases, write separate post scripts.

- Never download anything inside the shell script. No RPM, no repo file, nothing. Assume that the installation is done on a site without connectivity, and make everything available locally. Remember that you can have a private directory for your own files.

- Never, ever, **under any circumstance**, install any package yourself inside the shell script. Let the configuration tool install packages for you, see `Package management`_ for details. If you need to install a repo RPM (or a repo file, or a repo GPG key), check the ``additional-repos`` post script.


Default behaviour
~~~~~~~~~~~~~~~~~

- Try to make your scripts as `idempotent <https://en.wikipedia.org/wiki/Idempotence>`_ as possible, that is; being able to run multiple times without changing the results beyond those of the first run. Some functions are provided to help with that goal, those are described in :doc:`config_common_funcs`.

- At the very least, make sure that the shell script doesn't do any damage when the state of the system at the beginning of execution is not what expected. In other words, don't make too many assumptions and do a few checks at the beginning. The sane default behaviour when a configuration already exists is to wipe it and start clean (a.k.a. the big red reset button), so that re-running a post script that failed restarts it from the beginning.


Package management
~~~~~~~~~~~~~~~~~~

- Do not install packages directly from the shell script. Instead, create a matching ``.grplist`` or ``.pkglist`` for those.

- Do not store big binary files in the post script directory, or anywhere really. Git doesn't like that. If it's an RPM then ship in in the local repo. If it's a shared application, put it with the other applications.

- The only exceptions to the above rule are the small RPMs used for additional repositories only. Copy them to the private directory of the ``additional-repos`` post script, and they will be installed and ready before processing your own post script.

- When no RPM is available in external repos and it's necessary to provide one with Trinity, then use the local repository, which exists for that purpose. When installing a group of packages for a specific post script, then create your own local repository: create a subdirectory in the ``packages`` and copy your files there; it will be automatically picked up by the ``local-repos`` post script, copied and installed on the controllers. In both cases, remember to create or update the repository metadata after copying your files! See the documentation in the ``packages`` directory for more details.


Variable and configuration management
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Feel free to append information to ``/etc/trinity.sh``, as long as it's only environment variables and it's pertinent. This file is sourced automatically and its contents made available to all post scripts. See :doc:`config_env_vars` and :doc:`config_common_funcs` for more details and the correct way to do so.

- Print out the variables that you will need at the beginning of your script. That way, the output messages will contain the exact state of the post script's input. Use the function ``display_var`` for that, see :doc:`config_common_funcs`.

- Be careful in the choice of your variables in the configuration file. If possible, try to have a sane default value if no config option is set (i.e., empty configuration). For example, if ``something`` is required in 99% if cases but you want to give the option to disable it, make it ``DISABLE_SOMETHING`` and not ``ENABLE_SOMETHING``. With an empty config file, ``ENABLE_SOMETHING`` would not be set and that would break the 99% of cases. When a configuration option must have a value (for example a path to a file), make sure that you have a fallback value if the option is not set, and document it very well next to the option in ``controller.cfg`` and your shell script.

- Regarding the naming of configuration variables: for each option specific to a post script, pick a prefix that matches or refers to that script. For example, all options for the ``chrony`` post script start with ``CHRONY_``. That makes things much cleaner and clearer. General options (such as IP addresses, for example) can have non-prefixed names, but then it's up to you to make sure that there is no name collision and that the option name makes sense.

- The prefix ``TRIX_`` is reserved for the values contained in ``/etc/trinity.sh``. Never use it as a configuration option prefix.

- All configuration variables must be added to the file ``controller.cfg``, which serves as the reference. The variables for a given post script must be listed under a header containing the name of the post script; see the file for examples. They must be set to a sane value or commented out.

- All the configuration variables added to ``controller.cfg`` must be documented: what their role is, what range of values do they accept, what their default option is if not set.

- When appending a line to a file, use the function called ``append_line``. It avoids duplication, which causes problems in many configuration files.

- In many cases, instead of using ``sed`` to modify a configuration file it's better to use sed to comment out existing options, then use ``append_line`` to add new ones at the end. In many cases it will also provide free quasi-idempotence: the previous line added will be commented out in the configuration (and therefore will have no effect), and only the new lines will be taken into account.


Shell script error management
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- The shell script component of all post scripts must manage its errors correctly. Amongst other things, this means that: it must check the return codes of the various functions, display helpful error messages, and clean up behind itself.

- Using ``set -e`` in the script is **not** correct error management. Amongst other things, it prevents the script from displaying an error message when the error occurs, thus preventing the user from knowing what went wrong without debugging the script.

- Other tricks that trigger an early and/or silent exit from the script must not be used. All tests for errors must be clearly visible and obvious, and the same goes for the command to exit the script. Exit must not be a side effect. For example, the parameter expansion ``${PARAMETER:?MESSAGE}`` displays the message if the parameter is null or unset *if the shell is interactive, but exits the shell if it's not interactive*. It is a perfect example of what should be avoided: the test leading to the exit is invisible, the exit itself is invisible and is a side effect, and the whole behaviour depends on the state of the environment.

- When detecting an error, if the script is not idempotent then it must try to undo as much as possible. In other words: in no case should it leave a half-configuration behind, if that configuration cannot be overwritten by a subsequent eexecution of the script. This is especially important for scripts that use passwords: the password may not be identical in the next run (if it was generated randomly), and therefore it may not be possible to undo the previous configuration during the subsequent execution.


Password management
~~~~~~~~~~~~~~~~~~~

- Passwords are stored read-only in the shadow file, and the TrinityX functions will not overwrite them. For that reason, as well as basic logic, the passwords should only be stored at the very end of the post scripts, once everything else has been completed successfully.

- When setting up software with password, it is critical to respect the `Shell script error management`_ rules and undo all configuration in case of an error. Passwords make reconfiguration pretty much impossible, so clean up behind yourselves.

- The password variables should never be displayed during configuration. On customer systems the output will end up in an installation log, and there should not be any password in that log.


Documentation
~~~~~~~~~~~~~

- The post scripts should include reasonable documentation in the source code. It may seem obvious at the time you're writing it, but months or years later, what was that weird triple-rule sed for?

- All configuration variables in the config files **must** be documented: role, range of values and default value must be documented.

- If the post script is particularly complex and / or deserves more explanation than what can be included in source code comments, then a Markdown or ReST file should be provided with it and included in the configuration tool documentation.



Common functions
================

The TrinityX configuration tool provides numerous functions to make writing post scripts easier. Those are pre-loaded in the shell environment of the Bash scripts, and are available for all to use.

Some of those functions were created to add or modify information contained in configuration files. When applicable, those functions should always be used instead of direct modifications, as they do various checks to avoid duplicate entries and incorrect outputs.

When the return codes are not specified, it is safe to assume that they respect the UNIX standard: 0 for success, non-zero for error.



Message display functions
-------------------------

Display functions are wrappers to output messages with a special meaning in a consistent way from script to script. By default they are in color, except when redirected or when ``--nocolor`` is used. See the :doc:`config_tool` for more details.


Syntax::

    echo_info message
    echo_warn message
    echo_error message

``message`` is a standard string. Note that escaped characters (``\n`` and such) will *not* be interpreted.


- ``echo_info``
    For info messages that stand out a bit more than just an ``echo``. Typically used to mark the different sections of a script.

- ``echo_warn``
    For warning messages.

- ``echo_error``
    For error messages.
    
    Note that this function does not do anything outside of displaying the message. Calling ``echo_error`` will not break out of the current function or script, nor will it return an error code. Those tasks are the responsibility of the calling script.


Examples::

    # echo_info A progress message
    
    [ info ]   A progress message
    
    # echo_warn We\'ve had an issue
    
    [ warn ]   We've had an issue
    
    # echo_error That did NOT go well.
    
    [ ERROR ]  That did NOT go well.



Variable functions
------------------

``display_var``
~~~~~~~~~~~~~~~

Display the contents of one or more environment variables


Syntax::

    display_var var1 [var2 ...]

``varX`` are variable names, and not their contents. Those variables may or may not exist, and may or may not be set.

It will display ``(empty)`` or ``(unset)`` for any variable that is either empty or unset.


Example::

    # display_var POST_{TOPDIR,CONFDIR,CONFIG,FILEDIR}
    
    POST_TOPDIR   =  /root/trinityX
    POST_CONFDIR  =  /root/trinityX/configuration
    POST_CONFIG   =  /root/trinityX/configuration/example.sh
    POST_FILEDIR  =  (unset)



``flag_is_set`` and ``flag_is_unset``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Test if a variable used as a flag is set or unset.

A flag is unset if the variable doesn't exist, or is set to 0, "n" or "no" (in capital or small letters). In all other cases, including when the variable exists but isn't set to anything or when it's set to an empty string, the flag is set.


Syntax::

    flag_is_set var
    flag_is_unset var

``var`` is a variable name, and not its content. That variable may or may not exist, and may or may not be set.


Return values:

- 0 if the flag is set, resp. unset;

- 1 is the flag is unset; resp. set;

- another non-zero error code if the syntax is incorrect.

Due to the third error code, it's always better to use each of them directly and not inverted::

    if flag_is_unset SOME_FLAG ; then ...
    
    # is much better than:
    
    if ! flag_is_set SOME_FLAG ; then ...

Typically those functions will be used to determine whether or not to run the block of code. Having an error code returned in case of wrong syntax is a useful sanity check in some situations.


Example::

    # TEST_FLAG=
    # if flag_is_set TEST_FLAG ; then echo The flag is set. ; fi
    
    The flag is set.




Data management functions
-------------------------

``append_line``
~~~~~~~~~~~~~~~

Append a line to a file. If the exact same line exists in the file already, don't do anything. The file will be created if it doesn't exist.


Syntax::

    append_line filename string

The string is a Bash string (between double quotes), not a list of parameters: ``"The complete string"``, not ``The complete string``.


Example::

    # append_line /tmp/test line1
    line1
    
    # append_line /tmp/test line2
    line2
    
    # append_line /tmp/test line1
    Line already present in destination file: line1
    
    # cat /tmp/test 
    line1
    line2



``store_variable`` and ``store_system_variable``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Store a variable in a file. If the variable exists in the file already, the original entry is deleted and the new value is appended at the end of the file (in effect, updating it). The file will be created if it doesn't exist.


Syntax::

    store_variable filename variable value
    store_system_variable filename variable value

- ``store_variable``
    Stores the value surrounded by quotes: ``variable="value"``.
    
    The variable name is sanitized: non-alphanumeric characters are replaced by an underscore (``_``). This is in accordance with IEEE standard 1003.1-2001 for the naming of shell variables.

- ``store_system_variable``
    For non-shell configuration files, stores the value without quotes: ``variable=value``
    
    The variable name is sanitized: characters that are neither alphanumeric, nor "." or "-" are replaced by an underscore (``_``).


Example::

    # store_variable /tmp/test VAR1,incorrect test
    VAR1_incorrect="test"
    
    # store_variable /tmp/test "VAR2 still not good" test
    VAR2_still_not_good="test"
    
    # store_system_variable /tmp/test VAR3-correct.maybe test
    VAR3-correct.maybe=test
    
    # store_variable /tmp/test VAR1_incorrect "not a test"
    VAR1_incorrect="not a test"
    
    # cat /tmp/test 
    VAR2_still_not_good="test"
    VAR3-correct.maybe=test
    VAR1_incorrect="not a test"




Password management functions
-----------------------------

``get_password``
~~~~~~~~~~~~~~~~

Generate a random password if the parameter is empty. The password is 8 character long, and generated with OpenSSL.


Syntax::

    get_password string

``string`` is typically the contents of a variable that is supposed to contain a password. If it's empty or non-existent, a new password is printed on stdout.


Example::

    # get_password 
    3ghc5ww3
    
    # get_password 
    BMOEM9IB
    
    # get_password mypass
    mypass



``store_password``
~~~~~~~~~~~~~~~~~~

Save a password to the shadow file of a TrinityX installation. The path of the shadow file is stored in the ``TRIX_SHADOW`` variable. See :doc:`config_env_vars` for more information about the shadow file.

The shadow file is designed to be sourced by post scripts, to obtain the required passwords for their tasks. To avoid issues, all passwords are defined as read-only variables in the file. They cannot be changed by subsequent calls to the function.


Syntax::

    store_password variable password

The sanitization rules for the variable name are the same as with ``store_variable``.


Example::

    # PASSWD_SOMETHING="$(get_password)"
    
    # store_password PASSWD_SOMETHING "$PASSWD_SOMETHING"
    declare -r PASSWD_SOMETHING="ouQf9kI4"
    
    # realpw="$(get_password)"
    
    # store_password PASSWD_SOMETHING "$realpw"
    
    [ warn ]   store_variable_backend: will not overwrite a read-only variable: PASSWD_SOMETHING
    
    # cat $TRIX_SHADOW
    declare -r PASSWD_SOMETHING="ouQf9kI4"


As shown in the example above, ``store_password`` will be used usually after a call to ``get_password``. The typical workflow will look like this::

    # MYSCRIPT_PW is a configuration option to let the user set the password
    # if no password is provided, obtain a random one
    mypass="$(get_password "$MYSCRIPT_PW")"
    
    # do something useful
    
    if [[ test if everything went right ]] ; then
        store_password MYSCRIPT_PW "$mypass"
    fi

For more information about password management, see :doc:`config_post_scripts`.


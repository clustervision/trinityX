
User management in a TrinityX cluster
=====================================

User management in TrinityX is handled by a utility called *obol*. Obol is a simple wrapper around LDAP commands to update the local LDAP directory installed by default. It supports both user and group management almost the same way those would be handled by the default Linux utilities.



Obol
----

Obol can manage users and groups on the local LDAP directory and it supports the following attributes for users:
    
============= =============
 Attribute     Description
============= =============
``password``  User's password
``cn``        User's name (common name)
``sn``        User's surname
``givenName`` User's given name
``group``     The primary group the user belongs to
``uid``       The user's ID
``gid``       The primary group's ID
``mail``      Email address of the user
``phone``     Phone number
``shell``     Default shell
``groups``    A comma separated list of additional group names to add the user to.
``expire``    Number of days after which the account expires. If set to -1, the account will never expire

============= =============

To create or modify a user, run::
    # obol user add|modify ...

.. note:: Please note that running obol commands requires root privileges.

Managing groups is similarly achieved using::
    # obol group [command] ....
Where [command] can either be ``add``, ``show``, ``delete``, ``list``, ``addusers``, or ``delusers``

For the full list of the commands supported by Obol, run::

    obol user -h
    obol user [command] -h

    obol group -h
    obol group [command] -h



Cluster access
--------------

TrinityX supports both a group-based access control system and a SLURM PAM-based one where only users with running jobs can access the resources allocated to them.

When group-based access control (GBAC) is used, TrinityX will allow or deny access to the compute nodes based on the groups to which a user belongs. By default, TrinityX only allows access to users that belong to the group ``admins``.

Choosing between the two described access modes is allowed by the ``enable_slurm_pam`` variable in trinityX/site/group_vars/all. If set to `true`, SLURM PAM will be used, otherwise, group-based filtering will be used.

.. note:: If for some reason there is a need to update the list of groups that have access to the nodes or disable this control altogether, ``sssd.conf`` should be updated on each node. Change ``ldap_access_filter`` or ``ldap_access_order`` from ``filter,expire`` to ``expire``.



Authentication backends
-----------------------

TrinityX installations come with an openldap directory by default. This directory is used for authentication across the cluster. In some cases, we might want to use a different directory entirely or another remote directory in combination with the local one.


Using a remote directory
~~~~~~~~~~~~~~~~~~~~~~~~

In order to mask the local openldap directory and only use a remote one, an administrator needs to update sssd's configuration file across the cluster (i.e. on the controllers as well as on compute images).

What they will need to update is the two options `ldap_uri` and `ldap_search_base`:

- `ldap_uri` will need to point to the remote directory (e.g. ldaps://ldap.university.edu/)
- `ldap_search_base` will need to refer to the distinguished name of the directory (e.g. dc=university,dc=edu)

For the changes to take effect, sssd.service will need to be restarted on all the affected nodes (and compute nodes reprovisioned).


Using the local and a remote directory at the same time
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

In cases where an administrator prefers to use the local directory in combination with a remote one then one will need to update both sssd's and openldap's configurations.

The local openldap installation has a special proxy database `dn: dc=cluster` that can serve as an aggregator for multiple ldap directories. 
The local one, `dn: dc=local`, is already accounted for in the proxy with a `dn: dc=local,dc=cluster`. So the administrator only needs to add a reference to the remote directory::

    ldapmodify -Y EXTERNAL -H ldapi:///

    dn: olcMetaSub={0}uri,olcDatabase={2}meta,cn=config
    changetype: add
    objectClass: olcMetaTargetConfig
    olcMetaSub: {0}uri
    olcDbURI: "ldapi:///dc=remote,dc=cluster" ldap://ldap.university.edu
    olcDbRewrite: {0}suffixmassage "dc=remote,dc=cluster" "dc=university,dc=edu"

Then, the sssd configuration must be updated to point to the proxy database:

- `ldap_search_base` has to refer to `dc=cluster`

For changes to take effect, sssd.service must be restarted on all affected nodes (and compute nodes reprovisioned).


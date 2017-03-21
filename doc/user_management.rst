
User management in a TrinityX cluster
=====================================

User management in TrinityX is handled by a utility called obol. obol is a simple wrapper around LDAP commands to update the local LDAP directory that is installed by default. It supports both user and group management almost the same way those would be handled by the default linux utilities.



obol
----

For the full list of the operations supported by obol, you can run::

    obol user -h
    obol user [op] -h

    obol group -h
    obol group [op] -h



Cluster access
--------------

When configured, TrinityX can setup a group based access control system (GBAC) so as to allow or deny access based on the groups a user belongs to.

By default TrinityX only allows access to the cluster nodes for users that belong to either of ther groups: ``admins`` or ``users``.

This is managed by the configuration option ``CTRL_ALLOWED_GROUPS="admins users"`` in the controller-HA.cfg file.

If for some reason we need to update the list of groups that have access or disable this control all together, we can do so by updating sssd.conf on each of the nodes. We need to change ``ldap_access_order`` from ``filter,expire`` to ``expire``



Authentication backends
-----------------------

TrinityX installations come with an openldap directory by default. This directory is used for authentication across the cluster. In some cases however we might want to use a different directory entirely; or use another remote directory in combination with the local one.


Using a remote directory
~~~~~~~~~~~~~~~~~~~~~~~~

In order to mask the local openldap directory and only use a remote one, an administrator needs to update sssd's configuration file across the cluster (i.e. on the controllers as well as on compute images).

What they will need to update is the two options `ldap_uri` and `ldap_search_base`:

- `ldap_uri` will need to point to the remote directory (e.g. ldaps://ldap.university.edu/)
- `ldap_search_base` will need to refer to the distinguished name of the directory (e.g. dc=university,dc=edu)

For the changes to take effect, sssd.service will need to be restarted on all the affected nodes (and compute nodes reprovisioned).


Using the local and a remote directory at the same time
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

In cases where an administrator prefers to use the local directory in combination with a remote one then (s)he will need to update both sssd's and openldap's configurations.

The local openldap installation has a special proxy database `dn: dc=cluster` than can serve as an aggregator for multiple ldap directories. 
The local one `dn: dc=local` is already accounted for in the proxy with a `dn: dc=local,dc=cluster`. So the administrator only needs to add a reference to the remote directory::

    ldapmodify -Y EXTERNAL -H ldapi:///

    dn: olcMetaSub={0}uri,olcDatabase={2}meta,cn=config
    changetype: add
    objectClass: olcMetaTargetConfig
    olcMetaSub: {0}uri
    olcDbURI: "ldapi:///dc=remote,dc=cluster" ldap://ldap.university.edu
    olcDbRewrite: {0}suffixmassage "dc=remote,dc=cluster" "dc=university,dc=edu"

Then sssd configuration must updated to point to the proxy database:

- `ldap_search_base` has to refer to `dc=cluster`

For the changes to take effect, sssd.service will need to be restarted on all the affected nodes (and compute nodes reprovisioned).


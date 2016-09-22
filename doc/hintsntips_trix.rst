
Hints and tips for an Trinity X installation
============================================

Authenticating users against a remote ldap directory
----------------------------------------------------

TrinityX installations come with an openldap directory by default. This directory is used for authentication across the cluster. In some cases however we might want to use a different directory entirely; or use another remote directory in combination with the local one.

Using the remote directory only
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

In order to mask the local openldap directory and only use a remote one, an administrator needs to update sssd's configuration file across the cluster (i.e. on the controllers as well as on compute images).

What they will need to update is the two options `ldap_uri` and `ldap_search_base`:

- `ldap_uri` will need to point to the remote directory (e.g. ldaps://ldap.university.edu/)
- `ldap_search_base` will need to refer to the distinguished name of the directory (e.g. dc=university,dc=edu)

For the changes to take effect, sssd.service will need to be restarted on all the affected nodes (and compute nodes reprovisioned).


Using both the local and remote directories
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

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


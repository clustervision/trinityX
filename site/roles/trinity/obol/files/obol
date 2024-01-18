#!/usr/bin/python3

######################################################################
# Obol user management tool
#
# Original work from Hans Then, forked from
# https://github.com/hansthen/obol/, version 1.2
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License (included with the sources) for more
# details.
######################################################################

__author__ = "Diego Sonaglia"
__copyright__ = ""
__license__ = "GPL"
__version__ = "1.7"
__maintainer__ = "Diego Sonaglia"
__email__ = "diego.sonaglia@clustervision.com"
__status__ = "Development"


import os
import sys
import time
import json
import hashlib
import base64
import argparse
import configparser
import secrets
import logging
from getpass import getpass
from typing import List, Dict, Union

import ldap


def print_warning(msg, name="Warning"):
    """Print a warning message to stderr"""
    print(f"[{name}] {msg}", file=sys.stderr)


def print_error(msg, name="Error"):
    """Print an error message to stderr"""
    print(f"[{name}] {msg}", file=sys.stderr)


def print_table(item: Union[List, Dict]):
    """Print a list of dicts as a table, dict as a transposed table"""
    if isinstance(item, list):
        if len(item) == 0:
            print("No results")
            return
        keys = item[0].keys()
        widths = [len(key) for key in keys]

        for row in item:
            for i, key in enumerate(keys):
                widths[i] = max(widths[i], len(str(row[key])))

        print(" | ".join([key.ljust(widths[i]) for i, key in enumerate(keys)]))
        print("-+-".join(["-" * widths[i] for i, key in enumerate(keys)]))

        for row in item:
            print(
                " | ".join(
                    [str(row[key]).ljust(widths[i]) for i, key in enumerate(keys)]
                )
            )

    elif isinstance(item, dict):
        keys = item.keys()
        widths = [len(key) for key in keys]

        max_width = max(widths)
        for key in keys:
            print(key.ljust(max_width), "|", item[key])


def show_output(func):
    """Function decorator to print the output of a function"""

    def inner(obol, *args, **kwargs):
        output = func(obol, *args, **kwargs)

        output_type = kwargs.pop("output_type", None)

        if output_type == "json":
            print(json.dumps(output, indent=2))
        elif output_type == "table":
            print_table(output)
        return output

    return inner


class Obol:
    """Obol class"""

    user_fields = [
        "cn",
        "uid",
        "uidNumber",
        "gidNumber",
        "homeDirectory",
        "loginShell",
        "shadowExpire",
        "shadowLastChange",
        "shadowMax",
        "shadowMin",
        "shadowWarning",
        "sn",
        "userPassword",
        "givenName",
        "mail",
        "telephoneNumber",
    ]
    group_fields = ["cn", "gid", "gidNumber", "member"]

    def __init__(self, config_path, overrides=None):
        self.config = configparser.ConfigParser()

        # try to open and read configuration from config_path
        with open(config_path, "r", encoding="utf-8") as config_file:
            self.config.read_file(config_file)

        # override LDAP params from cli
        for key, value in (overrides or {}).items():
            if value and (key in self.config["ldap"]):
                self.config.set("ldap", key, value)

        # try binding to LDAP
        try:
            ldap_host = self.config.get("ldap", "host")
            ldap_bind_dn = self.config.get("ldap", "bind_dn")
            ldap_bind_pass = self.config.get("ldap", "bind_pass")

            self.conn = ldap.initialize(ldap_host)
            self.conn.simple_bind_s(ldap_bind_dn, ldap_bind_pass)
        except Exception as exc:
            raise ConnectionError("Failed binding to ldap") from exc

    @property
    def base_dn(self):
        """Returns the base DN"""
        return self.config.get("ldap", "base_dn")

    @property
    def users_dn(self):
        """Returns the users DN"""
        return f"ou=People,{self.base_dn}"

    @property
    def groups_dn(self):
        """Returns the groups DN"""
        return f"ou=Group,{self.base_dn}"

    @classmethod
    def _make_secret(cls, password):
        """Encodes the given password as a base64 SSHA hash+salt buffer"""
        if password.startswith("{SSHA}"):
            return password

        salt = os.urandom(4)
        # Hash the password and append the salt
        sha = hashlib.sha1(password.encode("utf-8"))
        sha.update(salt)
        # Create a base64 encoded string of the concatenated digest + salt
        digest_b64 = base64.b64encode(sha.digest() + salt).decode("utf-8")

        # Tag the digest above with the {SSHA} tag
        tagged_digest = f"{{SSHA}}{digest_b64}"

        return tagged_digest

    def _next_id(self, idlist, id_min=1050, id_max=10000):
        idlist = [int(i) for i in idlist]
        existing_ids = [i for i in range(id_min, id_max) if i not in idlist]
        next_id = str(min(existing_ids))
        return next_id

    def _next_uid(self, _users):
        idlist = [u["uidNumber"] for u in _users or []]
        return self._next_id(idlist, 1050, 10000)

    def _next_gid(self, _groups):
        idlist = [g["gidNumber"] for g in _groups or []]
        return self._next_id(idlist, 150, 10000)

    def _user_show_by_uid(self, uid, _users=None):
        """Show system user details"""
        users = _users or self.user_list()
        for user in users:
            if user["uidNumber"] == uid:
                return user
        return None

    def _group_show_by_gid(self, gid, _groups=None):
        """Show system group details"""
        groups = _groups or self.group_list()
        for group in groups:
            if group["gidNumber"] == gid:
                return group
        return None

    def _username_exists(self, username, _users=None):
        """Check if a username exists"""
        users = _users or self.user_list()
        for user in users:
            if user["uid"] == username:
                return True
        return False

    def _groupname_exists(self, groupname, _groups=None):
        """Check if a groupname exists"""
        groups = _groups or self.group_list()
        for group in groups:
            if group["cn"] == groupname:
                return True
        return False

    def _usernames_exists(self, usernames, _users=None):
        """Check if a ll the usernames exists"""
        users = _users or self.user_list()
        for username in usernames:
            if not self._username_exists(username, _users=users):
                return False
        return True

    def _groupnames_exists(self, groupnames, _groups=None):
        """Check if a ll the groupnames exists"""
        groups = _groups or self.group_list()
        for groupname in groupnames:
            if not self._groupname_exists(groupname, _groups=groups):
                return False
        return True

    def _uid_exists(self, uid, _users=None):
        """Check if a uid exists"""
        users = _users or self.user_list()
        for user in users:
            if user["uidNumber"] == uid:
                return True
        return False

    def _gid_exists(self, gid, _groups=None):
        """Check if a gid exists"""
        groups = _groups or self.group_list()
        for group in groups:
            if group["gidNumber"] == gid:
                return True
        return False

    ###### List
    @show_output
    def user_list(self, **kwargs):
        """List users defined in the system"""

        # Retrieve users from LDAP
        users = []
        fields = ["uid", "uidNumber", "gidNumber"]
        filter_dn = "(objectclass=posixAccount)"
        for _, attrs in self.conn.search_s(
            self.users_dn, ldap.SCOPE_SUBTREE, filter_dn, fields
        ):
            # Decode bytes to utf8 and parse data
            user = {
                k: [vi.decode("utf8") for vi in v][0]
                for k, v in attrs.items()
                if k in fields
            }
            users.append(user)

        return users

    @show_output
    def group_list(self, **kwargs):
        """List groups defined in the system"""

        # Retrieve groups from LDAP
        groups = []
        fields = [
            "cn",
            "gidNumber",
        ]
        filter_dn = "(objectclass=posixGroup)"
        for _, attrs in self.conn.search_s(
            self.groups_dn, ldap.SCOPE_SUBTREE, filter_dn, fields
        ):
            # Decode bytes to utf8 and parse data
            group = {
                k: [vi.decode("utf8") for vi in v][0]
                for k, v in attrs.items()
                if k in fields
            }
            groups.append(group)

        return groups

    ###### Show
    @show_output
    def user_show(self, username, **kwargs):
        """Show system user details"""

        # Retrieve first user from LDAP query, raise error if not found
        filter_dn = f"(uid={username})"
        for _, attrs in self.conn.search_s(
            self.users_dn, ldap.SCOPE_SUBTREE, filter_dn, self.user_fields
        ):
            # Decode bytes to utf8 and parse data
            user = {
                k: [vi.decode("utf8") for vi in v][0]
                for k, v in attrs.items()
                if k in self.user_fields
            }
            break
        else:
            # Raise error if no user found
            raise LookupError(f"User '{username}' does not exist")

        # Retrieve user's groups from LDAP
        user["groups"] = []
        filter_dn = "(objectclass=groupOfMembers)"
        for _, attrs in self.conn.search_s(
            self.groups_dn, ldap.SCOPE_SUBTREE, filter_dn
        ):
            # Decode bytes to utf8 and parse data
            for member in attrs.get("member", []):
                if member.decode("utf8").startswith(f"uid={username},"):
                    user["groups"].append(attrs["cn"][0].decode("utf8"))

        return user

    @show_output
    def group_show(self, groupname, **kwargs):
        """
        Show system group details
        """

        # Retrieve first group from LDAP query, raise error if not found
        filter_dn = f"(cn={groupname})"
        for _, attrs in self.conn.search_s(
            self.groups_dn, ldap.SCOPE_SUBTREE, filter_dn, self.group_fields
        ):
            # Decode bytes to utf8 and parse data
            group = {
                k: [vi.decode("utf8") for vi in v]
                for k, v in attrs.items()
                if k in self.group_fields
            }
            group = {k: v[0] if not (k == "member") else v for k, v in group.items()}
            members = group.pop("member") if "member" in group else []
            group["users"] = [m.split(",")[0].split("=")[1] for m in members]
            break
        else:
            # Raise error if no group found
            raise LookupError(f"Group {groupname} does not exist")

        return group

    ###### Add
    def user_add(
        self,
        username,
        cn=None,
        sn=None,
        given_name=None,
        password=None,
        autogen_password=False,
        prompt_password=False,
        uid=None,
        gid=None,
        mail=None,
        phone=None,
        shell=None,
        groupname=None,
        groups=None,
        home=None,
        expire=None,
        **kwargs,
    ):
        """Add a user to the LDAP directory"""
        # Ensure username's uniqueness
        existing_users = self.user_list()
        if self._username_exists(username, _users=existing_users):
            raise ValueError(f"Username {username} already exists")

        # Ensure uid's correctness or generate one
        if uid:
            if self._uid_exists(uid, _users=existing_users):
                raise ValueError(f"UID {uid} already exists")
        else:
            uid = self._next_uid(existing_users)

        # Ensure groups correctness
        create_group = False
        existing_groups = self.group_list()
        if groupname or gid:
            if groupname:
                # if only groupname is specified: groupname should exist
                if not self._groupname_exists(groupname, _groups=existing_groups):
                    raise ValueError(f"Group {groupname} does not exist")
                gid = [g["gidNumber"] for g in existing_groups if g["cn"] == groupname][
                    0
                ]
            if gid:
                # if only gid is specified: gid should exist
                if not self._gid_exists(gid, _groups=existing_groups):
                    raise ValueError(f"GID {gid} does not exist")
                groupname = [g["cn"] for g in existing_groups if g["gidNumber"] == gid][
                    0
                ]
            if groupname and gid:
                # if both groupname and gid are specified: should refer to same group
                if (
                    groupname
                    != [g["cn"] for g in existing_groups if g["gidNumber"] == gid][0]
                ):
                    raise ValueError(f"Group {groupname} does not have gid {gid}")

        else:
            # neither groupname or gid is specified: groupname <- username
            groupname = username
            if self._groupname_exists(groupname, _groups=existing_groups):
                gid = [g["gidNumber"] for g in existing_groups if g["cn"] == groupname][
                    0
                ]
            else:
                gid = self._next_gid(existing_groups)
                create_group = True

        # Add the user
        dn = f"uid={username},ou=People,{self.base_dn}"
        cn = cn or username
        sn = sn or username
        home = home or f"{self.config.get('users', 'home')}/{username}"
        shell = shell or self.config.get("users", "shell")

        if (expire is not None) and (expire != "-1"):
            expire = str(int(expire) + int(time.time() / 86400))
        else:
            expire = "-1"
        user_record = [
            (
                "objectclass",
                [
                    b"top",
                    b"person",
                    b"organizationalPerson",
                    b"inetOrgPerson",
                    b"posixAccount",
                    b"shadowAccount",
                ],
            ),
            ("uid", [username.encode("utf-8")]),
            ("cn", [cn.encode("utf-8")]),
            ("sn", [sn.encode("utf-8")]),
            ("loginShell", [shell.encode("utf-8")]),
            ("uidNumber", [uid.encode("utf-8")]),
            ("gidNumber", [gid.encode("utf-8")]),
            ("homeDirectory", [home.encode("utf-8")]),
            ("shadowMin", [b"0"]),
            ("shadowMax", [b"99999"]),
            ("shadowWarning", [b"7"]),
            ("shadowExpire", [str(expire).encode("utf-8")]),
            ("shadowLastChange", [str(int(time.time() / 86400)).encode("utf-8")]),
        ]

        if given_name:
            user_record.append(("givenName", [given_name.encode("utf-8")]))

        if mail:
            user_record.append(("mail", [mail.encode("utf-8")]))

        if phone:
            user_record.append(("telephoneNumber", [phone.encode("utf-8")]))

        if autogen_password:
            password = secrets.token_urlsafe(16)
            print(f"Generated password for user {username}: {password}")

        if prompt_password:
            password = getpass(f"Enter password for user {username}: ")

        if password:
            hashed_password = self._make_secret(password).encode("utf-8")
            user_record.append(("userPassword", [hashed_password]))

        # Add the user
        self.conn.add_s(dn, user_record)

        # Add the default group if it does not exist
        if create_group:
            self.group_add(groupname, gid, [username])

        # Add the user to the specified groups
        for group in (groups or []) + [groupname]:
            self.group_addusers(group, [username])

        # Create the user's home directory
        if not os.path.exists(home):
            os.mkdir(home)
            os.chown(home, int(uid), int(gid))
        else:
            home_folder_uid = int(os.stat(home).st_uid)
            if home_folder_uid != int(uid):
                print_warning(
                    f"Home directory {home} already exists and has wrong owner uid {home_folder_uid}, should be {uid}"
                )

    def group_add(self, groupname=None, gid=None, users=None, **kwargs):
        """Add a group to the LDAP"""

        # Ensure groupname's uniqueness
        existing_groups = self.group_list()

        if self._groupname_exists(groupname, _groups=existing_groups):
            raise ValueError(f"Groupname {groupname} already exists")

        # Ensure gid's uniqueness
        if gid:
            if self._gid_exists(gid, _groups=existing_groups):
                raise ValueError(f"GID {gid} already exists")
        else:
            gid = self._next_gid(existing_groups)

        if users:
            # Ensure users exist
            existing_usernames = [u["uid"] for u in self.user_list()]
            incorrect_usernames = [u for u in users if u not in existing_usernames]
            if len(incorrect_usernames) > 0:
                raise ValueError(
                    f"Users '{', '.join(incorrect_usernames)}' do not exist"
                )

        # Add group
        group_dn = f"cn={groupname},ou=Group,{self.base_dn}"
        group_record = [
            ("objectclass", [b"top", b"groupOfMembers", b"posixGroup"]),
            ("cn", [groupname.encode("utf-8")]),
            ("gidNumber", [gid.encode("utf-8")]),
        ]
        self.conn.add_s(group_dn, group_record)

        # Add users to group
        if users:
            self.group_addusers(groupname, users)

    ###### Delete
    def user_delete(self, username, **kwargs):
        """Delete a user from the system"""

        # Ensure user exists
        usernames = [u["uid"] for u in self.user_list()]
        if username not in usernames:
            raise LookupError(f"User '{username}' does not exist")

        # Delete the user
        user_dn = f"uid={username},ou=People,{self.base_dn}"
        self.conn.delete_s(user_dn)

        # Delete the default group if it exists and has no other members
        try:
            group = self.group_show(username)
            if len(group["users"]) == 0:
                group_dn = f"cn={group['cn']},ou=Group,{self.base_dn}"
                self.conn.delete_s(group_dn)
        except LookupError:
            pass

    def group_delete(self, groupname, **kwargs):
        """Delete a user from the system"""

        # Ensure group exists
        groupnames = [g["cn"] for g in self.group_list()]
        if groupname not in groupnames:
            raise LookupError(f"Group '{groupname}' does not exist")

        # Ensure group has no members
        group = self.group_show(groupname)
        if len(group["users"]) > 0:
            raise ValueError(f"Group '{groupname}' has members")
        # Delete the group
        group_dn = f"cn={groupname},ou=Group,{self.base_dn}"
        self.conn.delete_s(group_dn)

    ###### Modify
    def user_modify(
        self,
        username,
        cn=None,
        sn=None,
        given_name=None,
        password=None,
        autogen_password=False,
        prompt_password=False,
        uid=None,
        gid=None,
        mail=None,
        phone=None,
        shell=None,
        groupname=None,
        groups=None,
        home=None,
        expire=None,
        **kwargs,
    ):
        """Modify a user"""

        # Ensure user exists
        existing_user = self.user_show(
            username,
        )
        existing_groups = self.group_list()

        primary_group_changed = False
        mod_attrs = []

        groups_to_add = []
        groups_to_del = []

        if cn:
            mod_attrs.append((ldap.MOD_REPLACE, "cn", f"{cn}".encode("utf-8")))
        if sn:
            mod_attrs.append((ldap.MOD_REPLACE, "sn", f"{sn}".encode("utf-8")))
        if given_name:
            mod_attrs.append(
                (ldap.MOD_REPLACE, "givenName", f"{given_name}".encode("utf-8"))
            )
        if uid:
            raise NotImplementedError("changing UID of existing user is not supported")

        if groupname:
            # if groupname is specified: groupname should exist
            if not self._groupname_exists(groupname, _groups=existing_groups):
                raise ValueError(f"Group '{groupname}' does not exist")

            _gid = [g["gidNumber"] for g in existing_groups if g["cn"] == groupname][0]
            # if also gid is specified: should refer to same group
            if gid and (gid != _gid):
                raise ValueError(f"Group '{groupname}' does not have gid {gid}")
            gid = _gid

        elif gid:
            # if only gid is specified: gid should exist
            if not self._gid_exists(gid, _groups=existing_groups):
                raise ValueError(f"GID {gid} does not exist")

        if gid:
            groupname = [g["cn"] for g in existing_groups if g["gidNumber"] == gid][0]

        if gid or groupname:
            old_groupname = [
                g["cn"]
                for g in existing_groups
                if g["gidNumber"] == existing_user["gidNumber"]
            ][0]
            mod_attrs.append((ldap.MOD_REPLACE, "gidNumber", f"{gid}".encode("utf-8")))
            primary_group_changed = True

        if mail:
            mod_attrs.append((ldap.MOD_REPLACE, "mail", f"{mail}".encode("utf-8")))
        if phone:
            mod_attrs.append(
                (ldap.MOD_REPLACE, "telephoneNumber", f"{phone}".encode("utf-8"))
            )
        if shell:
            mod_attrs.append(
                (ldap.MOD_REPLACE, "loginShell", f"{shell}".encode("utf-8"))
            )
        if home:
            mod_attrs.append(
                (ldap.MOD_REPLACE, "homeDirectory", f"{home}".encode("utf-8"))
            )
        if expire:
            if expire != "-1":
                expire = str(int(expire) + int(time.time() / 86400))
            mod_attrs.append(
                (ldap.MOD_REPLACE, "shadowExpire", f"{expire}".encode("utf-8"))
            )
        if autogen_password:
            password = secrets.token_urlsafe(16)
            print(f"Generated password for user {username}: {password}")
        if prompt_password:
            password = getpass(f"Enter password for user {username}: ")
        if password:
            hashed_password = self._make_secret(password).encode("utf-8")
            mod_attrs.append((ldap.MOD_REPLACE, "userPassword", hashed_password))
        if groups:
            # Ensure groups exist
            existing_groupnames = [g["cn"] for g in self.group_list()]
            incorrect_groupnames = [g for g in groups if g not in existing_groupnames]
            if len(incorrect_groupnames) > 0:
                incorrect_groupnames_str = ", ".join(incorrect_groupnames)
                raise ValueError(f"Groups '{incorrect_groupnames_str}' do not exist")

            primary_group = [
                g["cn"]
                for g in existing_groups
                if g["gidNumber"] == existing_user["gidNumber"]
            ][0]

            groups_to_add = [g for g in groups if g not in existing_user["groups"]]
            groups_to_del = [
                g
                for g in existing_user["groups"]
                if (g not in groups) and (g != primary_group)
            ]

        # Modify the user in LDAP
        dn = f"uid={username},ou=People,{self.base_dn}"
        self.conn.modify_s(dn, mod_attrs)

        if primary_group_changed:
            # Modify the user's primary group
            self.group_delusers(old_groupname, [username])
            self.group_addusers(groupname, [username])

        for group in groups_to_add:
            self.group_addusers(group, [username])
        for group in groups_to_del:
            self.group_delusers(group, [username])

    def group_modify(self, groupname, gid=None, users=None, **kwargs):
        """Modify a group"""

        # Ensure group exists
        existing_group = self.group_show(groupname)

        group_mod_attrs = []
        users_mod_attrs = {}
        users_to_add = []
        users_to_del = []

        if gid:
            # Not implemented yet
            raise NotImplementedError("changing GID of existing group is not supported")

        if users:
            # Ensure users exist
            existing_users = self.user_list()
            existing_usernames = [u["uid"] for u in existing_users]
            incorrect_usernames = [u for u in users if u not in existing_usernames]
            if len(incorrect_usernames) > 0:
                raise ValueError(
                    f"Users '{', '.join(incorrect_usernames)}' do not exist"
                )

            existing_group_usernames = existing_group["users"]
            existing_primary_group_usernames = [
                u["uid"]
                for u in existing_users
                if u["gidNumber"] == existing_group["gidNumber"]
            ]
            users_to_add = [u for u in users if u not in existing_group_usernames]
            users_to_del = [
                u
                for u in existing_group["users"]
                if (u not in existing_group_usernames)
                and (u not in existing_primary_group_usernames)
            ]

        # Modify the group
        group_dn = f"cn={groupname},ou=Group,{self.base_dn}"
        self.conn.modify_s(group_dn, group_mod_attrs)
        self.group_addusers(groupname, users_to_add)
        self.group_delusers(groupname, users_to_del)
        # Modify the users that use this group as primaryGroup
        for user_dn, user_mod_attrs in users_mod_attrs.items():
            self.conn.modify_s(user_dn, user_mod_attrs)

    ###### Other
    def group_rename(self, groupname, new_groupname, **kwargs):
        """Rename a group"""

        existing_groups = self.group_list()
        # Ensure group exists
        if not self._groupname_exists(groupname, _groups=existing_groups):
            raise LookupError(f"Group '{groupname}' does not exist")

        # Ensure new groupname does not exist
        if self._groupname_exists(new_groupname, _groups=existing_groups):
            raise ValueError(f"Group '{new_groupname}' already exists")

        # Rename the group
        group_dn = f"cn={groupname},{self.groups_dn}"
        new_group_rdn = f"cn={new_groupname}"

        self.conn.rename_s(group_dn, new_group_rdn, self.groups_dn)

    def group_addusers(self, groupname, usernames, **kwargs):
        """Add users to a group"""

        # Ensure group exists
        existing_group = self.group_show(groupname)
        if all(u in existing_group["users"] for u in usernames):
            return

        # Ensure users exist
        existing_usernames = [u["uid"] for u in self.user_list()]
        incorrect_usernames = [u for u in usernames if u not in existing_usernames]
        if len(incorrect_usernames) > 0:
            raise ValueError(f"Users '{', '.join(incorrect_usernames)}' do not exist")

        mod_attrs = []
        for name in usernames:
            mod_attrs.append(
                (
                    ldap.MOD_ADD,
                    "member",
                    f"uid={name},ou=People,{self.base_dn}".encode("utf-8"),
                )
            )

        group_dn = f"cn={groupname},ou=Group,{self.base_dn}"
        self.conn.modify_s(group_dn, mod_attrs)

    def group_delusers(self, groupname, usernames, warn=False, **kwargs):
        """Remove users from a group"""

        # Ensure group exists
        existing_group = self.group_show(groupname)

        # Ensure users exist
        existing_users = self.user_list()
        existing_usernames = [u["uid"] for u in existing_users]
        incorrect_usernames = [u for u in usernames if u not in existing_usernames]
        if len(incorrect_usernames) > 0:
            raise LookupError(f"Users '{', '.join(incorrect_usernames)}' do not exist")

        mod_attrs = []
        for user in existing_users:
            if user["uid"] in usernames:
                if user["gidNumber"] == existing_group["gidNumber"]:
                    if warn:
                        print_warning(
                            f"You removed user {user['uid']} from its primary group"
                        )
                mod_attrs.append(
                    (
                        ldap.MOD_DELETE,
                        "member",
                        f"uid={user['uid']},ou=People,{self.base_dn}".encode("utf-8"),
                    )
                )

        group_dn = f"cn={groupname},ou=Group,{self.base_dn}"
        self.conn.modify_s(group_dn, mod_attrs)


def run():
    """
    Runs the CLI
    """
    # Parser
    parser = argparse.ArgumentParser(prog="obol", description="Manage Cluster Users.")

    # LDAP bind parameters override
    parser.add_argument("--bind-dn", "-D", metavar="BIND_DN", help="LDAP bind DN")
    parser.add_argument(
        "--bind-pass", "-w", metavar="BIND_PASSWORD", help="LDAP bind password"
    )
    parser.add_argument("--host", "-H", metavar="HOST", help="LDAP host")
    parser.add_argument("--base-dn", "-b", metavar="BASE_DN", help="LDAP base DN")
    # Output format
    parser.add_argument(
        "--json",
        "-J",
        action="store_const",
        const="json",
        dest="output_type",
        default="table",
        help="Output in JSON format",
    )

    # Subparsers and commands
    subparsers = parser.add_subparsers(help="commands", dest="target")
    user_parser = subparsers.add_parser(
        "user",
        help="User commands",
    )
    group_parser = subparsers.add_parser("group", help="Group commands")
    user_commands = user_parser.add_subparsers(dest="command")
    group_commands = group_parser.add_subparsers(dest="command")

    # User add command
    user_add_command = user_commands.add_parser("add", help="Add a user")
    user_add_command.add_argument("username")
    user_add_command_password_group = user_add_command.add_mutually_exclusive_group()
    user_add_command_password_group.add_argument("--password", "-p")
    user_add_command_password_group.add_argument(
        "--prompt-password", "-P", action="store_true"
    )
    user_add_command_password_group.add_argument(
        "--autogen-password", "--autogen", action="store_true"
    )
    user_add_command.add_argument("--cn", metavar="COMMON NAME")
    user_add_command.add_argument("--sn", metavar="SURNAME")
    user_add_command.add_argument("--givenName", dest="given_name")
    user_add_command.add_argument(
        "--group", "-g", metavar="PRIMARY GROUP", dest="groupname"
    )
    user_add_command.add_argument("--uid", metavar="USER ID")
    user_add_command.add_argument("--gid", metavar="GROUP ID")
    user_add_command.add_argument("--mail", metavar="EMAIL ADDRESS")
    user_add_command.add_argument("--phone", metavar="PHONE NUMBER")
    user_add_command.add_argument("--shell")
    user_add_command.add_argument(
        "--groups",
        type=lambda s: s.split(","),
        help="A comma separated list of group names",
    )
    user_add_command.add_argument(
        "--expire",
        metavar="DAYS",
        help=(
            "Number of days after which the account expires. " "Set to -1 to disable"
        ),
    )
    user_add_command.add_argument("--home", metavar="HOME")

    # User modify command
    user_modify_command = user_commands.add_parser(
        "modify", help="Modify a user attribute"
    )
    user_modify_command.add_argument("username")
    user_modify_command_password_group = (
        user_modify_command.add_mutually_exclusive_group()
    )
    user_modify_command_password_group.add_argument("--password", "-p")
    user_modify_command_password_group.add_argument(
        "--prompt-password", "-P", action="store_true"
    )
    user_modify_command_password_group.add_argument(
        "--autogen-password", "--autogen", action="store_true"
    )
    user_modify_command.add_argument("--cn", metavar="COMMON NAME")
    user_modify_command.add_argument("--sn", metavar="SURNAME")
    user_modify_command.add_argument("--givenName", dest="given_name")
    user_modify_command.add_argument(
        "--group", "-g", metavar="PRIMARY GROUP", dest="groupname"
    )
    user_modify_command.add_argument("--uid", metavar="USER ID")
    user_modify_command.add_argument("--gid", metavar="GROUP ID")
    user_modify_command.add_argument("--shell")
    user_modify_command.add_argument("--mail", metavar="EMAIL ADDRESS")
    user_modify_command.add_argument("--phone", metavar="PHONE NUMBER")
    user_modify_command.add_argument(
        "--groups",
        type=lambda s: s.split(","),
        help="A comma separated list of group names",
    )
    user_modify_command.add_argument(
        "--expire",
        metavar="DAYS",
        help=(
            "Number of days after which the account expires. " "Set to -1 to disable"
        ),
    )
    user_modify_command.add_argument("--home", metavar="HOME")

    # User show command
    user_show_command = user_commands.add_parser("show", help="Show user details")
    user_show_command.add_argument("username")

    # User delete command
    user_delete_command = user_commands.add_parser("delete", help="Delete a user")
    user_delete_command.add_argument("username")

    # User list command
    _ = user_commands.add_parser("list", help="List users")

    # Group add command
    group_add_command = group_commands.add_parser("add", help="Add a group")
    group_add_command.add_argument("groupname")
    group_add_command.add_argument("--gid", metavar="GROUP ID")
    group_add_command.add_argument(
        "--users",
        type=lambda s: s.split(","),
        help="A comma separated list of usernames",
    )

    # Group modify command
    group_modify_command = group_commands.add_parser("modify", help="Modify a group")
    group_modify_command.add_argument("groupname")
    group_modify_command.add_argument("--gid", metavar="GROUP ID")
    group_modify_command.add_argument(
        "--users",
        type=lambda s: s.split(","),
        help="A comma separated list of usernames",
    )

    # Group rename command
    group_addusers_command = group_commands.add_parser(
        "rename", help="Rename group but keep its GID and users"
    )
    group_addusers_command.add_argument("groupname")
    group_addusers_command.add_argument("new_groupname")

    # Group addusers command
    group_addusers_command = group_commands.add_parser(
        "addusers", help="Add users to a group"
    )
    group_addusers_command.add_argument("groupname")
    group_addusers_command.add_argument("usernames", nargs="+")

    # Group delusers command
    group_delusers_command = group_commands.add_parser(
        "delusers", help="Delete users from a group"
    )
    group_delusers_command.add_argument("groupname")
    group_delusers_command.add_argument("usernames", nargs="+")

    # Group show command
    group_show_command = group_commands.add_parser("show", help="Show group details")
    group_show_command.add_argument("groupname")

    # Group delete command
    group_delete_commands = group_commands.add_parser("delete", help="Delete a group")
    group_delete_commands.add_argument("groupname")

    # Group list command
    _ = group_commands.add_parser("list", help="List groups")

    # Run command
    try:
        # log executed command but redact password
        logged_cmd = ""
        password_argument = False

        for arg in sys.argv:
            if password_argument:
                logged_cmd += "<REDACTED> "
            else:
                logged_cmd += f"{arg} "
            password_arguments = ["--password", "-p", "--bind-pass", "-w"]
            password_argument = arg in password_arguments
        # setup logger
        logging.basicConfig(
            filename="/var/log/obol.log",
            format="[%(asctime)s][%(levelname)s][%(name)s] %(message)s",
            level=logging.INFO,
        )
        logging.info(f"Executing command '{logged_cmd}'")

        args = vars(parser.parse_args())
        obol = Obol("/etc/obol.conf", overrides=args)
        if args["target"] is None or args["command"] is None:
            if args["target"] == "user":
                user_parser.print_help()
            elif args["target"] == "group":
                group_parser.print_help()
            else:
                parser.print_help()
            sys.exit(1)
        method_name = f"{args['target']}_{ args['command']}"
        function = getattr(obol, method_name, None)
        function(**args, warn=True)
        logging.info(f"Command '{logged_cmd}' succeeded")
    except Exception as exc:
        logging.error(f"Command '{logged_cmd}' failed: {exc}")
        print_error(
            exc,
            name=type(exc).__name__,
        )
        sys.exit(1)


if __name__ == "__main__":
    run()

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

__author__      = 'Diego Sonaglia'
__copyright__   = ''
__license__     = 'GPL'
__version__     = '1.5'
__maintainer__  = 'Diego Sonaglia'
__email__       = 'diego.sonaglia@clustervision.com'
__status__      = 'Development'


import os
import sys
import grp
import pwd
import ldap
import time
import json
import hashlib
import argparse
import configparser
import base64

from typing import List, Dict, Union
from pprint import pprint


def print_warning(msg, name="Warning"):
    """Print a warning message to stderr"""
    print("[%s] %s" % (name, msg), file=sys.stderr)


def print_error(msg, name="Error"):
    """Print an error message to stderr"""
    print("[%s] %s" % (name, msg), file=sys.stderr)


def print_table(item: Union[List, Dict]):
    """Print a list of dicts as a table, dict as a transposed table"""
    if isinstance(item, list):
        if len(item) == 0: 
            print('No results')
            return 
        keys = item[0].keys()
        widths = [len(key) for key in keys]

        for row in item:
            for i, key in enumerate(keys):
                widths[i] = max(widths[i], len(str(row[key])))

        print(' | '.join([key.ljust(widths[i]) for i, key in enumerate(keys)]))
        print('-+-'.join(['-' * widths[i] for i, key in enumerate(keys)]))

        for row in item:
            print(' | '.join([str(row[key]).ljust(widths[i]) for i, key in enumerate(keys)]))

    elif isinstance(item, dict):
        keys = item.keys()
        widths = [len(key) for key in keys]

        max_width = max(widths)
        for key in keys:
            print(key.ljust(max_width), '|', item[key])

def show_output(func):
    '''Function decorator to print the output of a function '''
    def inner(obol, *args, **kwargs):
        output = func(obol, *args, **kwargs)

        output_type = kwargs.get('output_type')

        if output_type == 'json' :
            print(json.dumps(output, indent=2))
        elif output_type == 'table':
            print_table(output)
        return output
    return inner


class Obol:
    user_fields = [
        'cn',
        'uid',
        'uidNumber',
        'gidNumber',
        'homeDirectory',
        'loginShell',
        'shadowExpire',
        'shadowLastChange',
        'shadowMax',
        'shadowMin',
        'shadowWarning',
        'sn',
        'userPassword',
        'givenName',
        'mail',
        'telephoneNumber',
    ]
    group_fields = [
        'cn',
        'gid',
        'gidNumber',
        'member'
    ]

    def __init__(self, config_path, overrides={}):
        self.config = configparser.ConfigParser()
        self.config.read(config_path)
        # override from cli

        for key, value in overrides.items():
            if value and (key in self.config['ldap']):
                self.config.set('ldap', key, value)
        # bind to LDAP
        self.conn = ldap.initialize(self.config.get("ldap", "host"))
        self.conn.simple_bind_s(self.config.get("ldap", "bind_dn"),
                                self.config.get("ldap", "bind_pass"))

    @property
    def base_dn(self):
        return self.config.get("ldap", "base_dn")

    @property 
    def users_dn(self):
        return 'ou=People,%s' % self.base_dn

    @property
    def groups_dn(self):
        return 'ou=Group,%s' % self.base_dn

    @classmethod
    def _make_secret(cls, password):
        """Encodes the given password as a base64 SSHA hash+salt buffer"""
        if password.startswith('{SSHA}'):
            return password

        salt = os.urandom(4)
        # Hash the password and append the salt
        sha = hashlib.sha1(password.encode('utf-8'))
        sha.update(salt)
        # Create a base64 encoded string of the concatenated digest + salt
        digest_b64 = base64.b64encode(sha.digest() + salt).decode('utf-8')

        # Tag the digest above with the {SSHA} tag
        tagged_digest = f'{{SSHA}}{digest_b64}'

        return tagged_digest

    def _next_id(self, idlist, id_min=1050, id_max=10000):
        idlist = [int(i) for i in idlist]
        existing_ids = [i for i in range(id_min, id_max) if i not in idlist]
        next_id = str(min(existing_ids))
        return next_id

    def _next_uid(self, _users):
        idlist = [u['uidNumber'] for u in _users or []]
        return self._next_id(idlist, 1050, 10000)

    def _next_gid(self, _groups):
        idlist = [g['gidNumber'] for g in _groups or []]
        return self._next_id(idlist, 150, 10000)

    def _user_show_by_uid(self, uid, _users=None):
        """Show system user details"""
        users = _users or self.user_list()
        for user in users:
            if user['uidNumber'] == uid:
                return user

    def _group_show_by_gid(self, gid, _groups=None):
        """Show system group details"""
        groups = _groups or self.group_list()
        for group in groups:
            if group['gidNumber'] == gid:
                return group

    def _username_exists(self, username, _users=None):
        """Check if a username exists"""
        users = _users or self.user_list()
        for user in users:
            if user['uid'] == username:
                return True
        return False

    def _groupname_exists(self, groupname, _groups=None):
        """Check if a groupname exists"""
        groups = _groups or self.group_list()
        for group in groups:
            if group['cn'] == groupname:
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
            if user['uidNumber'] == uid:
                return True
        return False

    def _gid_exists(self, gid, _groups=None):
        """Check if a gid exists"""
        groups = _groups or self.group_list()
        for group in groups:
            if group['gidNumber'] == gid:
                return True
        return False

    ###### List
    @show_output
    def user_list(self, **kwargs):
        """List users defined in the system"""

        base_dn = self.users_dn
        filter = '(objectclass=posixAccount)'

        users = []
        for _, attrs in self.conn.search_s(base_dn, ldap.SCOPE_SUBTREE, filter):
            fields = ['uid', 'uidNumber', 'gidNumber']
            user = { k:[vi.decode('utf8') for vi in v][0] for k,v in attrs.items() if k in fields }
            users.append(user)

        return users


    @show_output
    def group_list(self, **kwargs):
        """List groups defined in the system"""

        base_dn = self.groups_dn
        filter = '(objectclass=posixGroup)'

        groups = []
        for _, attrs in self.conn.search_s(base_dn, ldap.SCOPE_SUBTREE, filter):
            fields = ['cn', 'gidNumber', ]
            group = { k:[vi.decode('utf8') for vi in v][0] for k,v in attrs.items() if k in fields }
            groups.append(group)

        return groups


    ###### Show
    @show_output
    def user_show(self, username, **kwargs):
        """Show system user details"""

        users_dn = self.users_dn
        filter = '(uid=%s)' % username

        for _, attrs in self.conn.search_s(users_dn, ldap.SCOPE_SUBTREE, filter, self.user_fields):
            user = { k:[vi.decode('utf8') for vi in v][0] for k,v in attrs.items() if k in self.user_fields }
            break
        else:
            raise LookupError("User '%s' does not exist" % username)

        groups_dn = self.groups_dn

        user['groups'] = []
        for _, attrs in self.conn.search_s(groups_dn, ldap.SCOPE_SUBTREE, '(objectclass=groupOfMembers)'):
            for member in attrs.get('member', []):
                if member.decode('utf8').startswith('uid=%s,' % username):
                    user['groups'].append( attrs['cn'][0].decode('utf8'))

        return user

    @show_output
    def group_show(self, groupname, **kwargs):
        base_dn = self.groups_dn
        filter = '(cn=%s)' % groupname

        for _, attrs in self.conn.search_s(base_dn, ldap.SCOPE_SUBTREE, filter, self.group_fields):
            group = { k:[vi.decode('utf8') for vi in v] for k,v in attrs.items() if k in self.group_fields }
            group = { k:v[0] if not (k=='member') else v for k,v in group.items() }

            members = group.pop('member') if 'member' in group else []

            group['users'] = [ m.split(',')[0].split('=')[1] for m in members]
            return group

        raise LookupError("Group %s does not exist" % groupname)

    ###### Add
    def user_add(self,
                username,
                cn=None,
                sn=None,
                givenName=None,
                password=None,
                uid=None,
                gid=None,
                mail=None,
                phone=None,
                shell=None,
                groupname=None,
                groups=None,
                home=None,
                expire=None,
                **kwargs):
        """Add a user to the LDAP directory"""
        # Ensure username's uniqueness
        existing_users = self.user_list()
        if self._username_exists(username, _users=existing_users):
            raise ValueError('Username %s already exists' % username)

        # Ensure uid's correctness or generate one
        if uid:
            if self._uid_exists(uid, _users=existing_users):
                raise ValueError('UID %s already exists' % uid)
        else:
            uid = self._next_uid(existing_users)

        # Ensure groups correctness
        create_group = False
        existing_groups = self.group_list()
        if groupname or gid:
            if groupname:
                # if only groupname is specified: groupname should exist
                if not self._groupname_exists(groupname, _groups=existing_groups):
                    raise ValueError('Group %s does not exist' % groupname)
                gid = [ g['gidNumber'] for g in existing_groups if g['cn'] == groupname ][0]
            if gid:
                # if only gid is specified: gid should exist
                if not self._gid_exists(gid, _groups=existing_groups):
                    raise ValueError('GID %s does not exist' % gid)
                groupname = [ g['cn'] for g in existing_groups if g['gidNumber'] == gid ][0]
            if groupname and gid:
                # if both groupname and gid are specified: should refer to same group
                if groupname != [ g['cn'] for g in existing_groups if g['gidNumber'] == gid ][0]:
                    raise ValueError('Group %s does not have gid %s' % (groupname, gid))


        else:
            # neither groupname or gid is specified: groupname <- username
            groupname = username
            if self._groupname_exists(groupname, _groups=existing_groups):
                gid = [ g['gidNumber'] for g in existing_groups if g['cn'] == groupname ][0]
            else:
                gid = self._next_gid(existing_groups)
                create_group = True


        # Add the user
        dn = 'uid=%s,ou=People,%s' % (username, self.base_dn)
        cn = cn or username
        sn = sn or username
        home = home or self.config.get("users", "home") + '/' + username
        shell = shell or self.config.get("users", "shell")

        if (expire is not None) and (expire != '-1'):
            expire = str(int(expire) + int(time.time() / 86400))
        else:
            expire = '-1'
        user_record = [
        ('objectclass', [b'top', b'person', b'organizationalPerson',
                        b'inetOrgPerson', b'posixAccount', b'shadowAccount']),
        ('uid', [username.encode('utf-8')]),
        ('cn', [cn.encode('utf-8')]),
        ('sn', [sn.encode('utf-8')]),
        ('loginShell', [shell.encode('utf-8')]),
        ('uidNumber', [uid.encode('utf-8')]),
        ('gidNumber', [gid.encode('utf-8')]),
        ('homeDirectory', [home.encode('utf-8')]),
        ('shadowMin', [b'0']),
        ('shadowMax', [b'99999']),
        ('shadowWarning', [b'7']),
        ('shadowExpire', [str(expire).encode('utf-8')]),
        ('shadowLastChange', [str(int(time.time() / 86400)).encode('utf-8')])
        ]

        if givenName:
            user_record.append(('givenName', [givenName.encode('utf-8')]))

        if mail:
            user_record.append(('mail', [mail.encode('utf-8')]))

        if phone:
            user_record.append(('telephoneNumber', [phone.encode('utf-8')]))

        if password:
            hashed_password = self._make_secret(password).encode('utf-8')
            user_record.append(('userPassword', [hashed_password]))

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

    def group_add(self,
                groupname=None,
                gid=None,
                users=None,
                **kwargs):
        """Add a group to the LDAP"""

        # Ensure groupname's uniqueness
        existing_groups = self.group_list()

        if self._groupname_exists(groupname, _groups=existing_groups):
            raise ValueError('Groupname %s already exists' % groupname)

        # Ensure gid's uniqueness
        if gid:
            if self._gid_exists(gid, _groups=existing_groups):
                raise ValueError('GID %s already exists' % gid)
        else:
            gid = self._next_gid(existing_groups)

        if users:
            # Ensure users exist
            existing_usernames = [u['uid'] for u in self.user_list()]
            incorrect_usernames = [u for u in users if u not in existing_usernames]
            if len(incorrect_usernames) > 0:
                raise ValueError("Users '%s' do not exist" % ', '.join(incorrect_usernames))

        # Add group
        dn = 'cn=%s,ou=Group,%s' % (groupname, self.base_dn)
        group_record = [
            ('objectclass', [b'top', b'groupOfMembers', b'posixGroup']),
            ('cn', [groupname.encode('utf-8')]),
            ('gidNumber', [gid.encode('utf-8')])
        ]
        self.conn.add_s(dn, group_record)

        # Add users to group 
        if users:
            self.group_addusers(groupname, users)

    ###### Delete
    def user_delete(self, username, **kwargs):
        """Delete a user from the system"""

        # Ensure user exists
        usernames = [u['uid'] for u in self.user_list()]
        if username not in usernames:
            raise LookupError("User '%s' does not exist" % username)

        # Delete the user
        dn = 'uid=%s,ou=People,%s' % (username, self.base_dn)
        self.conn.delete_s(dn)

        # Delete the default group if it exists and has no other members
        try:
            group = self.group_show(username,)
            if len(group['users']) == 0:
                dn = 'cn=%s,ou=Group,%s' % (group['cn'], self.base_dn)
                self.conn.delete_s(dn)
        except LookupError:
            pass

    def group_delete(self, groupname, **kwargs):
        """Delete a user from the system"""

        # Ensure group exists
        gropunames = [g['cn'] for g in self.group_list()]
        if groupname not in gropunames:
            raise LookupError("Group '%s' does not exist" % groupname)

        # Ensure group has no members
        group = self.group_show(groupname,)
        if len(group['users']) > 0:
            raise ValueError("Group '%s' has members" % groupname)
        # Delete the group
        dn = 'cn=%s,ou=Group,%s' % (groupname, self.base_dn)
        self.conn.delete_s(dn)


    ###### Modify
    def user_modify(self,
            username,
            cn=None,
            sn=None,
            givenName=None,
            password=None,
            uid=None,
            gid=None,
            mail=None,
            phone=None,
            shell=None,
            groupname=None,
            groups=None,
            home=None,
            expire=None,
            **kwargs):
        """Modify a user"""

        # Ensure user exists
        existing_user = self.user_show(username,)
        existing_groups = self.group_list()

        primary_group_changed = False
        mod_attrs = []
        groups_to_add = []
        groups_to_del = []

        if cn:
            mod_attrs.append((ldap.MOD_REPLACE, 'cn', cn.encode('utf-8')))
        if sn:
            mod_attrs.append((ldap.MOD_REPLACE, 'sn', sn.encode('utf-8')))
        if givenName:
            mod_attrs.append((ldap.MOD_REPLACE, 'givenName', givenName.encode('utf-8')))
        if uid:
            # Ensure uid's uniqueness
            uids = [u['uidNumber'] for u in self.user_list()]
            if uid in uids:
                raise ValueError('UID %s already exists' % uid)
            mod_attrs.append((ldap.MOD_REPLACE, 'uidNumber', uid.encode('utf-8')))

        if groupname:
            # if groupname is specified: groupname should exist
            if not self._groupname_exists(groupname, _groups=existing_groups):
                raise ValueError('Group %s does not exist' % groupname)

            _gid = [g['gidNumber'] for g in existing_groups if g['cn'] == groupname][0]
            # if also gid is specified: should refer to same group
            if gid and (gid != _gid):
                raise ValueError('Group %s does not have gid %s' % (groupname, gid))
            gid = _gid

        elif gid:
            # if only gid is specified: gid should exist
            if not self._gid_exists(gid, _groups=existing_groups):
                raise ValueError('GID %s does not exist' % gid)

            groupname = [g['cn'] for g in existing_groups if g['gidNumber'] == gid][0]

        if gid or groupname:
            old_groupname =  [g['cn'] for g in existing_groups if g['gidNumber'] == existing_user['gidNumber']][0]
            mod_attrs.append((ldap.MOD_REPLACE, 'gidNumber', gid.encode('utf-8')))
            primary_group_changed = True

        if mail:
            mod_attrs.append((ldap.MOD_REPLACE, 'mail', mail.encode('utf-8')))
        if phone:
            mod_attrs.append((ldap.MOD_REPLACE, 'telephoneNumber', phone.encode('utf-8')))
        if shell:
            mod_attrs.append((ldap.MOD_REPLACE, 'loginShell', shell.encode('utf-8')))
        if home:
            mod_attrs.append((ldap.MOD_REPLACE, 'homeDirectory', home.encode('utf-8')))
        if expire:
            if expire != '-1':
                expire = str(int(expire) + int(time.time() / 86400))
            mod_attrs.append((ldap.MOD_REPLACE, 'shadowExpire', expire.encode('utf-8')))
        if password:
            hashed_password = self._make_secret(password).encode('utf-8')
            mod_attrs.append((ldap.MOD_REPLACE, 'userPassword', hashed_password))
        if groups:
            # Ensure groups exist
            existing_groupnames = [g['cn'] for g in self.group_list()]
            incorrect_groupnames = [g for g in groups if g not in existing_groupnames]
            if len(incorrect_groupnames) > 0:
                raise ValueError("Groups '%s' do not exist" % ', '.join(incorrect_groupnames))

            primary_group = [g['cn'] for g in existing_groups if g['gidNumber'] == existing_user['gidNumber']][0]

            groups_to_add = [g for g in groups if g not in existing_user['groups']]
            groups_to_del = [g for g in existing_user['groups'] if (g not in groups) and (g != primary_group)]


        # Modify the user in LDAP
        dn = 'uid=%s,ou=People,%s' % (username, self.base_dn)
        self.conn.modify_s(dn, mod_attrs)

        if primary_group_changed:
            # Modify the user's primary group
            self.group_delusers(old_groupname, [username])
            self.group_addusers(groupname, [username])

        for group in groups_to_add:
            self.group_addusers(group, [username])
        for group in groups_to_del:
            self.group_delusers(group, [username])

    def group_modify(self,
            groupname,
            gid=None,
            users=None,
            **kwargs):
        """Modify a group"""

        # Ensure group exists
        existing_group = self.group_show(groupname,)

        group_mod_attrs = []
        users_mod_attrs = {}
        users_to_add = []
        users_to_del = []

        if gid:
            # Not implemented yet
            raise NotImplementedError("changing GID of existing group is not supported yet")

        if users:
            # Ensure users exist
            existing_users = self.user_list()
            existing_usernames = [u['uid'] for u in existing_users]
            incorrect_usernames = [u for u in users if u not in existing_usernames]
            if len(incorrect_usernames) > 0:
                raise ValueError("Users '%s' do not exist" % ', '.join(incorrect_usernames))

            existing_group_usernames = existing_group['users']
            existing_primary_group_usernames = [u['uid'] for u in existing_users if u['gidNumber'] == existing_group['gidNumber'] ]
            users_to_add = [u for u in users if u not in existing_group_usernames]
            users_to_del = [u for u in existing_group['users'] if (u not in existing_group_usernames) and (u not in existing_primary_group_usernames )]            

        # Modify the group
        group_dn = 'cn=%s,ou=Group,%s' % (groupname, self.base_dn)
        self.conn.modify_s(group_dn, group_mod_attrs)
        self.group_addusers(groupname, users_to_add)
        self.group_delusers(groupname, users_to_del)
        # Modify the users that use this group as primaryGroup
        for user_dn, user_mod_attrs in users_mod_attrs.items():
            self.conn.modify_s(user_dn, user_mod_attrs)


    def group_addusers(self, groupname, usernames, **kwargs):
        """Add users to a group"""

        # Ensure group exists
        existing_group = self.group_show(groupname,)
        if all([u in existing_group['users'] for u in usernames]):
            return

        # Ensure users exist
        existing_usernames = [u['uid'] for u in self.user_list()]
        incorrect_usernames = [u for u in usernames if u not in existing_usernames]
        if len(incorrect_usernames) > 0:
            raise ValueError("Users '%s' do not exist" % ', '.join(incorrect_usernames))

        mod_attrs = []
        for name in usernames:
            mod_attrs.append((ldap.MOD_ADD, 'member',
                            str('uid=%s,ou=People,%s' % (name, self.base_dn)).encode('utf-8')))

        group_dn = 'cn=%s,ou=Group,%s' % (groupname, self.base_dn)

        self.conn.modify_s(group_dn, mod_attrs)


    def group_delusers(self, groupname, usernames, warn=False, **kwargs):
        """Remove users from a group"""

        # Ensure group exists
        existing_group = self.group_show(groupname,)

        # Ensure users exist
        existing_users = self.user_list()
        existing_usernames = [u['uid'] for u in existing_users]
        incorrect_usernames = [u for u in usernames if u not in existing_usernames]
        if len(incorrect_usernames) > 0:
            raise LookupError("Users '%s' do not exist" % ', '.join(incorrect_usernames))

        mod_attrs = []
        for user in existing_users:
            if user['uid'] in usernames:
                if user['gidNumber'] == existing_group['gidNumber']:
                    if warn:
                        print_warning(f"You removed user {user['uid']} from its primary group")
                mod_attrs.append((ldap.MOD_DELETE, 'member',
                                str('uid=%s,ou=People,%s' % (user['uid'], self.base_dn)).encode('utf-8')))

        group_dn = 'cn=%s,ou=Group,%s' % (groupname, self.base_dn)
        self.conn.modify_s(group_dn, mod_attrs)


def run():
    # Parser
    parser = argparse.ArgumentParser(prog='obol',
                                    description='Manage Cluster Users.')

    # LDAP bind parameters override
    parser.add_argument('--bind-dn', '-D', metavar="BIND_DN", help='LDAP bind DN')
    parser.add_argument('--bind-pass', '-w', metavar="BIND_PASSWORD", help='LDAP bind password')
    parser.add_argument('--host', '-H', metavar="HOST", help='LDAP host')
    parser.add_argument('--base-dn', '-b', metavar="BASE_DN", help='LDAP base DN')
    # Output format
    parser.add_argument('--json', '-J', action='store_const', const='json', dest='output_type', default='table', help='Output in JSON format')

    # Subparsers and commands
    subparsers = parser.add_subparsers(help='commands', dest='target')
    user_parser = subparsers.add_parser('user', help='User commands', )
    group_parser = subparsers.add_parser('group', help='Group commands')
    user_commands = user_parser.add_subparsers(dest='command')
    group_commands = group_parser.add_subparsers(dest='command')

    # User add command
    user_add_command = user_commands.add_parser('add', help='Add a user')
    user_add_command.add_argument('username')
    user_add_command.add_argument('--password', '-p')
    user_add_command.add_argument('--cn', metavar="COMMON NAME")
    user_add_command.add_argument('--sn', metavar="SURNAME")
    user_add_command.add_argument('--givenName')
    user_add_command.add_argument('--group', '-g', metavar='PRIMARY GROUP', dest='groupname')
    user_add_command.add_argument('--uid', metavar='USER ID')
    user_add_command.add_argument('--gid', metavar='GROUP ID')
    user_add_command.add_argument('--mail', metavar="EMAIL ADDRESS")
    user_add_command.add_argument('--phone', metavar="PHONE NUMBER")
    user_add_command.add_argument('--shell')
    user_add_command.add_argument('--groups', type=lambda s: s.split(','),
                        help='A comma separated list of group names')
    user_add_command.add_argument('--expire', metavar="DAYS",
                        help=('Number of days after which the account expires. '
                            'Set to -1 to disable'))
    user_add_command.add_argument('--home', metavar="HOME")

    # User modify command
    user_modify_command = user_commands.add_parser('modify', help='Modify a user attribute')
    user_modify_command.add_argument('username')
    user_modify_command.add_argument('--password', '-p')
    user_modify_command.add_argument('--cn', metavar="COMMON NAME")
    user_modify_command.add_argument('--sn', metavar="SURNAME")
    user_modify_command.add_argument('--givenName')
    user_modify_command.add_argument('--group', '-g', metavar='PRIMARY GROUP', dest='groupname')
    user_modify_command.add_argument('--uid', metavar='USER ID')
    user_modify_command.add_argument('--gid', metavar='GROUP ID')
    user_modify_command.add_argument('--shell')
    user_modify_command.add_argument('--mail', metavar="EMAIL ADDRESS")
    user_modify_command.add_argument('--phone', metavar="PHONE NUMBER")
    user_modify_command.add_argument('--groups', type=lambda s: s.split(','),
                        help='A comma separated list of group names')
    user_modify_command.add_argument('--expire', metavar="DAYS",
                        help=('Number of days after which the account expires. '
                            'Set to -1 to disable'))
    user_modify_command.add_argument('--home', metavar="HOME")

    # User show command
    user_show_command = user_commands.add_parser('show', help='Show user details')
    user_show_command.add_argument('username')

    # User delete command
    user_delete_command = user_commands.add_parser('delete', help='Delete a user')
    user_delete_command.add_argument('username')

    # User list command
    user_list_command = user_commands.add_parser('list', help='List users')

    # Group add command
    group_add_command = group_commands.add_parser('add', help='Add a group')
    group_add_command.add_argument('groupname')
    group_add_command.add_argument('--gid', metavar='GROUP ID')
    group_add_command.add_argument('--users', type=lambda s: s.split(','),
                        help='A comma separated list of usernames')

    # Group modify command
    group_modify_command = group_commands.add_parser('modify', help='Modify a group')
    group_modify_command.add_argument('groupname')
    group_modify_command.add_argument('--gid', metavar='GROUP ID')
    group_modify_command.add_argument('--users', type=lambda s: s.split(','),
                        help='A comma separated list of usernames')

    # Group addusers command
    group_addusers_command = group_commands.add_parser('addusers', help='Add users to a group')
    group_addusers_command.add_argument('groupname')
    group_addusers_command.add_argument('usernames', nargs='+')

    # Group delusers command
    group_delusers_command = group_commands.add_parser('delusers',
                                        help='Delete users from a group')
    group_delusers_command.add_argument('groupname')
    group_delusers_command.add_argument('usernames', nargs='+')

    # Group show command
    group_show_command = group_commands.add_parser('show', help='Show group details')
    group_show_command.add_argument('groupname')

    # Group delete command
    group_delete_commands = group_commands.add_parser('delete', help='Delete a group')
    group_delete_commands.add_argument('groupname')

    # Group list command
    group_list_command = group_commands.add_parser('list', help='List groups')

    # Run command
    args = vars(parser.parse_args())
    obol = Obol('/etc/obol.conf', overrides=args)
    try:
        if args['target'] is None or args['command'] is None:
            if args['target'] == 'user':
                user_parser.print_help()
            elif args['target'] == 'group':
                group_parser.print_help()
            else:
                parser.print_help()
            exit(1)
        method_name = '%s_%s' % (args['target'], args['command'])
        function = getattr(obol, method_name, None)
        function(**args, warn=True)
    except (ValueError, LookupError) as e:
        print_error(e, type(e).__name__)
        exit(1)
    except Exception as e:
        print_error(e, (f"OtherError: {type(e).__name__}"))
        exit(1)


if __name__ == '__main__':
    run()

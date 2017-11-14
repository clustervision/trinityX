#!/usr/bin/python

from ansible.module_utils.basic import AnsibleModule
import os
import subprocess
import pymongo
import json
import re


def run_cmd(cmd, stdin):
    p = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stdin=subprocess.PIPE,
        shell=True
    )

    output = p.communicate(
        stdin
    )[0]
    output = output.strip()
    err = ''
    if p.stderr is not None:
        err = p.stderr.read()
    return p.returncode, output, err


def t_mongo_user_present(data):

    # check if we able to connect as admin

    mongo_cmd = 'mongo --quiet'

    if data['login_password'] is not None:

        mongo_cmd += ' --norc '

        if data['login_host']:
            mongo_cmd += ' --host ' + data['login_host']

        if data['login_port']:
            mongo_cmd += ' --port ' + str(data['login_port'])

        if data['login_database']:
            mongo_cmd += ' --authenticationDatabase ' + data['login_database']

        mongo_cmd += ' --password ' + data['login_password']

    retcode, output, _ = run_cmd(
        mongo_cmd,
        "printjson(db.serverStatus().ok)"
    )

    if output != '1':
        return True, False, 'Unable to authenticate in MongoDB'

    # check if user exist
    retcode, output, _ = run_cmd(
        mongo_cmd,
        "db = db.getSiblingDB('{}'); db.getUser('{}').user"
        .format(data['database'], data['name'])
    )

    if retcode == 0 and output == data['name']:
        user_exists = True
    else:
        user_exists = False

    # now check user passwd,
    mongo_cmd_user = 'mongo --quiet --norc'
    mongo_cmd_user += ' --host ' + data['login_host']
    mongo_cmd_user += ' --port ' + str(data['login_port'])
    mongo_cmd_user += ' --authenticationDatabase ' + data['database']
    mongo_cmd_user += ' --username ' +  data['name']
    mongo_cmd_user += ' --password ' +  data['password']

    retcode, output, _ = run_cmd(
        mongo_cmd_user,
        "version()"
    )

    if retcode == 0:
        user_can_login = True
    else:
        user_can_login = False

    # now check roles for user:
    retcode, output, _ = run_cmd(
        mongo_cmd,
        "db = db.getSiblingDB('{}'); printjson(db.getUser('{}').roles)"
        .format(data['database'], data['name'])
    )

    roles_are_valid = False

    # FIXME here will be and issue if multiple roles needs to be assigned
    try:
        roles = json.loads(output)
        for elem in roles:
            if elem['db'] != data['database']:
                continue
            if elem['role'] == data['role']:
                roles_are_valid = True
    except:
        roles_are_valid = False

    if user_can_login and roles_are_valid:
        return False, False, ""

    # need to create user:
    if not user_exists:
        retcode, output, err = run_cmd(
            mongo_cmd,
            """
            db = db.getSiblingDB('{}');
            db.createUser({{
                user: '{}', pwd: '{}',
                roles: [ {{ role: '{}', db: '{}' }} ]}})
            """
            .format(
                data['database'],
                data['name'],
                data['password'],
                data['role'],
                data['database'],
            )
        )
        return (bool(retcode), True,
                "STDOUT: {}; STDERR: {}".format(output, err))

    # need to fix password
    changed = False
    if not user_can_login:

        retcode, output, err = run_cmd(
            mongo_cmd,
            """
            db = db.getSiblingDB('{}');
            db.changeUserPassword('{}', '{}')
            """
            .format(
                data['database'],
                data['name'],
                data['password'],
            )
        )
        changed = True
        if bool(retcode):
            return (bool(retcode), changed,
                    "STDOUT: {}; STDERR: {}".format(output, err))

    if not roles_are_valid:
        retcode, output, err = run_cmd(
            mongo_cmd,
            """
            db = db.getSiblingDB('{}');
            db.grantRolesToUser('{}', [{ role: '{}', db: '{}' }])
            """
            .format(
                data['database'],
                data['name'],
                data['role'],
                data['database'],
            )
        )
        changed = True
        if bool(retcode):
            return (bool(retcode), changed,
                    "STDOUT: {}; STDERR: {}".format(output, err))

    return (bool(retcode), changed,
            "STDOUT: {}; STDERR: {}".format(output, err))

def t_mongo_user_absent(data):
    # check if we able to connect as admin

    mongo_cmd = 'mongo --quiet'

    if data['login_password'] is not None:

        mongo_cmd += ' --norc '

        if data['login_host']:
            mongo_cmd += ' --host ' + data['login_host']

        if data['login_port']:
            mongo_cmd += ' --port ' + str(data['login_port'])

        if data['login_database']:
            mongo_cmd += ' --authenticationDatabase ' + data['login_database']

        mongo_cmd += ' --password ' + data['login_password']

    retcode, output, _ = run_cmd(
        mongo_cmd,
        "printjson(db.serverStatus().ok)"
    )

    if output != '1':
        return True, False, 'Unable to authenticate in MongoDB'

    # check if user exist
    retcode, output, _ = run_cmd(
        mongo_cmd,
        "db = db.getSiblingDB('{}'); db.getUser('{}').user"
        .format(data['database'], data['name'])
    )

    if retcode == 0 and output == data['name']:
        user_exists = True
    else:
        user_exists = False

    if not user_exists:
        return False, False, ''

    #  delete user
    retcode, output, err = run_cmd(
        mongo_cmd,
        """
        db = db.getSiblingDB('{}');
        db.dropUser('{}')
        """
        .format(
            data['database'],
            data['name'],
        )
    )

    return (bool(retcode), True,
            "STDOUT: {}; STDERR: {}".format(output, err))


def main():
    module = AnsibleModule(
        argument_spec={
            'name': {
                'type': 'str', 'required': True},
            'password': {
                'type': 'str', 'required': True, 'no_log': True},
            'database': {
                'type': 'str', 'required': False, 'default': 'admin'},
            'role': {
                'type': 'str', 'required': False, 'default': 'readWrite',
                'choices': [
                     'read', 'readWrite', 'dbAdmin', 'userAdmin',
                     'clusterAdmin', 'readAnyDatabase',
                     'readWriteAnyDatabase', 'userAdminAnyDatabase',
                     'dbAdminAnyDatabase',
                     'root', 'dbOwner'
                ]
            },
            'login_host': {
                'type': 'str', 'required': False, 'default': 'localhost'},
            'login_port': {
                'type': 'int', 'required': False, 'default': 27017},
            'login_database': {
                'type': 'str', 'required': False, 'default': "admin"},
            'login_password': {
                'type': 'str', 'required': False, 'no_log': True},
            'state': {
                'type': 'str', 'default': 'present',
                'choices': ['present', 'absent']}
        }
    )

    choice_map = {
        "present": t_mongo_user_present,
        "absent": t_mongo_user_absent,
    }

    is_error, has_changed, result = choice_map.get(
        module.params['state'])(module.params)

    if not is_error:
        module.exit_json(changed=has_changed, meta=result)
    else:
        module.fail_json(msg='Error cluster changing', meta=result)


if __name__ == '__main__':
    main()

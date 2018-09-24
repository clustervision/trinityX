#!/usr/bin/python

from __future__ import absolute_import, division, print_function

from ansible.module_utils.basic import AnsibleModule
from ansible.module_utils.urls import fetch_url
from ansible.module_utils._text import to_native

from inspect import cleandoc
import tempfile
import os
import shutil

BUFSIZE = 65536


class BuildRepo(object):

    def __init__(self, module):
        self.module = module
        params = module.params
        self.gpg = self.module.get_bin_path('gpg')
        self.rpm = self.module.get_bin_path('rpm', True)
        self.yum = self.module.get_bin_path('yum', True)
        if params['use_local']:
            self.repo = params['local_repo']
            self.gpgkey = params['local_key']
            # remote_repo: epel-release
            # local_repo:  http://some-local-server/path
            # will be converted to local-repo: epel-release
            if ('/' not in params['remote_repo']
                    and '/' in params['local_repo']):
                self.repo = params['remote_repo']
            # we can use something like
            # remote_repo: http://some.server/full/path/file.repo
            # local_repo:  http://other.server/another/path/
            elif params['local_repo'].endswith('/'):
                file_name = params['remote_repo'].split('/')[-1]
                self.repo += file_name

            if params['remote_key'] and params['remote_key'].endswith('/'):
                file_name = params['remote_key'].split('/')[-1]
                self.gpgkey += file_name
        else:
            self.repo = params['remote_repo']
            self.gpgkey = params['remote_key']

    def run(self):
        if self.repo.endswith('.repo'):
            self.put_repofile()
            return
        if self.repo.endswith('.rpm') or not '/' in self.repo:
            self.install_rpm()
            return
        self.create_repo_from_url()
        return

    def get_file(self, url):

        if '://' not in url:
            # deal with local file
            return url

        # we have remote file
        suffix = url.split('/')[-1]

        with tempfile.NamedTemporaryFile(
                suffix=suffix, delete=False) as tmp_file:
            self.module.add_cleanup_file(tmp_file.name)
            try:
                rsp, info = fetch_url(self.module, url)
                if not rsp:
                    msg = "Failure downloading {}, {}".format(url, info['msg'])
                    self.module.fail_json(msg=msg)
                data = rsp.read(BUFSIZE)
                while data:
                    tmp_file.write(data)
                    data = rsp.read(BUFSIZE)
            except Exception as e:
                msg = "Failure downloading {}, {}".format(url, to_native(e))
                self.module.fail_json(msg=msg)
        return tmp_file.name

    def put_repofile(self):
        repofile_name = self.repo.split('/')[-1]

        tmp_repofile = self.get_file(self.repo)

        changed_key = self.put_gpgkey()

        yum_repos_d_repofile = '/etc/yum.repos.d/' + repofile_name

        if not os.path.exists(yum_repos_d_repofile):
            shutil.copy(tmp_repofile, yum_repos_d_repofile)
            self.module.exit_json(changed=True, meta=self.repo)

        tmp_md5 = self.module.md5(tmp_repofile)
        local_file_md5 = self.module.md5(yum_repos_d_repofile)

        if tmp_md5 != local_file_md5:
            shutil.copyfile(tmp_repofile, yum_repos_d_repofile)
            self.module.exit_json(changed=True, meta=self.repo)

        self.module.exit_json(changed=False | changed_key, meta=self.repo)

    def put_gpgkey(self):
        if not self.gpgkey:
            return False
        tmp_key_file = self.get_file(self.gpgkey)
        keyid = self.normalize_keyid(self.getkeyid(tmp_key_file))
        if self.is_key_imported(keyid):
            return False
        self.import_key(tmp_key_file)
        return True

    def get_pkg_name(self, url):
        pkg_file = None
        if '/' in self.repo or self.repo.endswith('.rpm'):
            pkg_file = self.get_file(self.repo)
        pkg_name = self.repo
        if pkg_file is None:
            return pkg_name, pkg_file
        cmd = self.rpm + " --qf '%{name}' -qp " + pkg_file
        stdout, _ = self.execute_command(cmd)
        lines = stdout.splitlines()
        if len(lines) == 0:
            msg = "Unable to find package name for {}; {}; {}".format(
                url, cmd, lines)
            self.module.fail_json(msg=msg)
        if len(lines) > 1:
            msg = "Several package names returned for {}".format(url)
            self.module.fail_json(msg=msg)
        return lines[0], pkg_file

    def is_rpm_installed(self, pkg_name):
        cmd = self.rpm + ' -q ' + pkg_name
        rc, _, _ = self.module.run_command(cmd)
        return not rc

    def install_rpm(self):
        pkg_name, pkg_path = self.get_pkg_name(self.repo)

        changed_key = self.put_gpgkey()

        if self.is_rpm_installed(pkg_name):
            self.module.exit_json(changed=False | changed_key, meta=self.repo)

        cmd = self.yum + ' --setopt=*.skip_if_unavailable=1 -y install '
        if pkg_path is None:
            cmd += pkg_name
        else:
            cmd += pkg_path
        _, _ = self.execute_command(cmd)
        self.module.exit_json(changed=True, meta=self.repo)

    def create_repo_from_url(self):
        if not self.module.params['name']:
            msg = "No name specified for the repo"
            self.module.fail_json(msg=msg)
        repo_name = self.module.params['name']
        fmt = {
            'name': repo_name,
            'repo': self.repo,
            'gpgcheck': 1 if self.gpgkey else 0
        }
        repo_file_name = repo_name + '.repo'
        repo_data = (
            """
            [{name}]
            name={name}
            baseurl={repo}
            enabled=1
            gpgcheck={gpgcheck}
            """
        )

        repo_data = cleandoc(repo_data.format(**fmt))

        tmp_dir = tempfile.gettempdir()
        tmp_file_name = tmp_dir + '/' + repo_file_name
        with open(tmp_file_name, 'w') as tmp_file:
            self.module.add_cleanup_file(tmp_file_name)
            try:
                tmp_file.write(repo_data)
            except Exception as e:
                msg = "Unable to write data to {}: {}".format(
                    tmp_file_name, to_native(e))
                self.module.fail_json(msg=msg)

        self.repo = tmp_file_name
        self.put_repofile()

    def normalize_keyid(self, keyid):
        """Ensure a keyid doesn't have a leading 0x,
        has leading or trailing whitespace, and make sure is uppercase"""
        ret = keyid.strip().upper()
        if ret.startswith('0x'):
            return ret[2:]
        elif ret.startswith('0X'):
            return ret[2:]
        else:
            return ret

    def execute_command(self, cmd):
        rc, stdout, stderr = self.module.run_command(
            cmd, use_unsafe_shell=True)
        if rc != 0:
            self.module.fail_json(msg=stderr)
        return stdout, stderr

    def is_key_imported(self, keyid):
        cmd = self.rpm + ' -q  gpg-pubkey'
        rc, stdout, stderr = self.module.run_command(cmd)
        if rc != 0:  # No key is installed on system
            return False
        cmd += ' --qf "%{description}" | '
        cmd += self.gpg
        cmd += ' --no-tty --batch --with-colons --fixed-list-mode -'
        stdout, stderr = self.execute_command(cmd)
        for line in stdout.splitlines():
            if keyid in line.split(':')[4]:
                return True
        return False

    def import_key(self, keyfile):
        if not self.module.check_mode:
            self.execute_command([self.rpm, '--import', keyfile])


def main():
    module = AnsibleModule(
        argument_spec={
            'remote_repo': {'type': 'str', 'required': True},
            'remote_key': {'type': 'str'},
            'local_repo': {'type': 'str'},
            'local_key': {'type': 'str'},
            'name': {'type': 'str'},
            'use_local': {'type': 'bool', 'default': False},

        }
    )
    BuildRepo(module).run()


if __name__ == '__main__':
    main()

#!/usr/bin/python2

import sys
import traceback
from ansible.playbook import Playbook
from ansible.vars.manager import VariableManager
from ansible.inventory.manager import InventoryManager
from ansible.inventory.host import Host
from ansible.parsing.dataloader import DataLoader
from ansible.template import Templar
from ansible.playbook.block import Block
from collections import Iterable
from ansible.errors import AnsibleUndefinedVariable
from ansible.utils.display import Display
import argparse

#self._inventory = data.get('inventory', None)
#all_group = self._inventory.groups.get('all')


class Unwrap(object):
    def __init__(self):
        self.tasks = set()

    def unwrap_blocks(self, blocks):
        """
        Recursuvely unpacks Ansible iterables to ansible.playbook.task.Task
        """
        if isinstance(blocks, list):
            for elem in blocks:
                self.unwrap_blocks(elem)
            return

        if isinstance(blocks, Block):
            self.unwrap_blocks(blocks.block)
            return
        self.tasks.add(blocks)


def flatten(x):
    if isinstance(x, (unicode, bytes, str)) or not isinstance(x, Iterable):
        return [x]
    ret = []
    for elem in x:
        ret.extend(flatten(elem))
    return ret


def parse_arguments():
    parser = argparse.ArgumentParser(
        description="""
        Parses Ansible playbook and puts packages requested to install
        """
    )
    parser.add_argument(
        '--playbook', '-p', type=str, required=True,
        help="Playbook"
    )
    parser.add_argument(
        '--host', '-H', type=str, required=True,
        help="Hostname (one of the controller)"
    )

    return parser.parse_args()


class Parser(object):

    def __init__(self, args):
        self.args = args
        self.templar, self.tasks = self.get_ansible_tasks()

    def get_ansible_tasks(self):
        # Load playbooks
        loader = DataLoader()
        inventory = InventoryManager(loader=loader, sources=[self.args.host])
        variable_manager = VariableManager(loader=loader, inventory=inventory)

        pb = Playbook.load(
            self.args.playbook,
            variable_manager=variable_manager,
            loader=loader
        )

        plays = pb.get_plays()

        all_vars = {}
        all_vars.update(variable_manager.get_vars(host=Host(self.args.host)))
        # enumarate all available plays
        tasks = set()
        for play in plays:
            all_vars.update(variable_manager.get_vars(play=play))

        templar = Templar(loader=loader, variables=all_vars)
        for play in plays:
            new_play = play.copy()
            new_play.post_validate(templar)
            for role in new_play.get_roles():
                u = Unwrap()
                block_container = role.compile(new_play)
                u.unwrap_blocks(block_container)
                tasks.update(u.tasks)

        return templar, tasks

    def get_yum_packages(self, task):
        packages = set()

        # pkg_name could be 'package' '{{ item }}' or '{{ item.key }}'
        # ansible 2.4
        if 'loop_args' in task and task['loop_args'] is not None:
            # handle '{{ item }}' or '{{ item.key }}'
            packages.update(
                flatten(self.templar.template(task['loop_args']))
            )
        # ansible 2.5
        if 'loop' in task and task['loop'] is not None:
            # handle '{{ item }}' or '{{ item.key }}'
            packages.update(
                flatten(self.templar.template(task['loop']))
            )
        else:
            # handle 'package' case
            var = task['args']['name']
            try:
                pkg_name = flatten(self.templar.template(var))
                packages.update(pkg_name)
            except AnsibleUndefinedVariable:
                Display().warning("Unable to resolve variable: '{}'".format(var))


        filtered_list = []
        # remove packages started with '/'
        for e in packages:
            if e.startswith('/'):
                continue
            filtered_list.append(e)

        return set(filtered_list)

    def get_trix_repos_packages(self, task):
        repo_set = set()
        try:
            role_params = self.templar.template(task['role']['_role_params'])
            repos = [e['repo'] for e in role_params['repos']]
        except Exception:
            return repo_set

        # filter invalid repos
        for r in repos:
            if r.endswith('.repo') or r.endswith('.rpm') or '://' not in r:
                repo_set.add(r)
        return repo_set

    def get_packages(self):
        packages = set()

        for task in self.tasks:
            ser = task.serialize()

            if ser['action'] == 'yum':
                packages.update(self.get_yum_packages(ser))

            if ser['action'] == 'trix_repos':
                packages.update(self.get_trix_repos_packages(ser))

        packages = list(packages)
        packages.sort()
        return packages


def main():
    args = parse_arguments()
    parser = Parser(args)
    packages = parser.get_packages()
    for p in packages:
        print p

if __name__ == '__main__':
    try:
        main()
    except:
        sys.stderr.write(traceback.format_exc(limit=10))
        sys.exit(1)

#!/usr/bin/python2

import sys
import traceback
from ansible.playbook import Playbook
from ansible.vars.manager import VariableManager
from ansible.parsing.dataloader import DataLoader
from ansible.template import Templar
from ansible.playbook.block import Block
from ansible.parsing.yaml.objects import AnsibleSequence
import argparse


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


def get_package_names(ser):
    """
    Given Ansible-like YAML task for yum with iterator, like

    - name: "Install packages"
      yum:
        name: '{{ item }}'
        state: present
      with_items: '{{ packages }}'

    return list of the packackes
    """
    packages = set()
    parm_search = {}
    parm_search.update(ser['role']['_default_vars'])
    parm_search.update(ser['role']['_role_params'])
    if 'loop_args' in ser:
        loop_args = ser['loop_args']
    else:
        loop_args = ser['loop']
    if not isinstance(loop_args, AnsibleSequence):
        loop_args = [loop_args]
    for arg in loop_args:
        # more likely some local packages
        if arg.startswith("/"):
            continue
        a = arg[2:-2].strip()
        if ser['action'] == 'trix_repos':
            pkgs = [e['repo'] for e in parm_search[a]]
            for p in pkgs:
                if p.endswith('.repo') or p.endswith('.rpm') or '://' not in p:
                    packages.add(p)
            continue
        sep = ser['args']['name'].find('.')
        # handle '{{ item }}' case
        if sep == -1:
            pkg_names = [e for e in parm_search[a]]
            packages.update(pkg_names)
            continue
        # handle '{{ item.key }}' case
        key = ser['args']['name'][(sep + 1):-2].strip()
        pkg_names = [e[key] for e in parm_search[a]]
        packages.update(pkg_names)
    return packages


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

    return parser.parse_args()


def get_ansible_tasks(args):
    # Load playbooks
    loader = DataLoader()
    variable_manager = VariableManager(loader=loader, inventory=None)
    pb = Playbook.load(
        args.playbook, variable_manager=variable_manager, loader=loader)
    plays = pb.get_plays()

    all_vars = {}
    # enumarate all available plays
    tasks = set()
    for play in plays:
        all_vars.update(variable_manager.get_vars(play=play))
        templar = Templar(loader=loader, variables=all_vars)
        new_play = play.copy()
        new_play.post_validate(templar)
        for role in new_play.get_roles():
            u = Unwrap()
            block_container = role.compile(new_play)
            u.unwrap_blocks(block_container)
            tasks.update(u.tasks)
    return tasks


def get_packages(tasks):
    packages = set()
    for task in tasks:
        ser = task.serialize()
        # we need only yum-related tasks
        if ser['action'] != 'yum' and ser['action'] != 'trix_repos':
            continue
        # skip tasks which remove packages
        if ser['action'] == 'yum' and ser['args']['state'] == 'absent':
            continue


        # pkg_name could be 'package' '{{ item }}' or '{{ item.key }}'
        # ansible 2.4
        if 'loop_args' in ser and ser['loop_args'] is not None:
            # handle '{{ item }}' or '{{ item.key }}'
            pkg_names = get_package_names(ser)
            packages.update(pkg_names)
        # ansible 2.5
        if 'loop' in ser and ser['loop'] is not None:
            # handle '{{ item }}' or '{{ item.key }}'
            pkg_names = get_package_names(ser)
            packages.update(pkg_names)
        else:
            # handle 'package' case
            pkg_name = ser['args']['name']
            packages.add(pkg_name)

    packages = list(packages)
    packages.sort()
    return packages


def main():
    args = parse_arguments()
    tasks = get_ansible_tasks(args)
    packages = get_packages(tasks)
    for p in packages:
        print p

if __name__ == '__main__':
    try:
        main()
    except:
        sys.stderr.write(traceback.format_exc(limit=10))
        sys.exit(1)

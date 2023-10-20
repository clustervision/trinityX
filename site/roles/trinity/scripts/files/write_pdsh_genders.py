
#This code is part of the TrinityX software suite
#Copyright (C) 2023  ClusterVision Solutions b.v.
#
#This program is free software: you can redistribute it and/or modify
#it under the terms of the GNU General Public License as published by
#the Free Software Foundation, either version 3 of the License, or
#(at your option) any later version.
#
#This program is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#GNU General Public License for more details.
#
#You should have received a copy of the GNU General Public License
#along with this program.  If not, see <https://www.gnu.org/licenses/>

import sys
import argparse
from typing import List

COMMENT_CHAR = '#'
CONFIG_FILEPATH = "/etc/genders"

def grey(text):
    """Return a grey string."""
    return f"\033[90m{text}\033[0m"

class ConfigFile:
    """A  config file is a collection of  groups that can be written to a file."""
    def __init__(self) -> None:
        self.prepended_lines = []
        self.managed_lines = []
        self.appended_lines = []

        # Represent groups as a dict of {group_name: [node_names]}
        self.groups = {}

    @property
    def nodes(self):
        """Return a dict of {node_name: [group_names]}."""
        nodes = {}
        for groupname in self.groups:
            for nodename in self.groups[groupname]:
                if nodename not in nodes:
                    nodes[nodename] = []
                nodes[nodename].append(groupname)
        return nodes

    @classmethod
    def _managed_block_start_delimiter(cls):
        return f"{COMMENT_CHAR*4} TrinityX Managed block start {COMMENT_CHAR*4}\n"

    @classmethod
    def _managed_block_end_delimiter(cls):
        return f"{COMMENT_CHAR*4} TrinityX Managed block end   {COMMENT_CHAR*4}\n"

    @classmethod
    def has_managed_block(cls, file_lines: List[str]):
        """Check if the given file lines contain a managed block."""
        return cls._managed_block_start_delimiter() in file_lines and cls._managed_block_end_delimiter() in file_lines

    @classmethod
    def _group_comment(cls, group_name: str = None):
        if group_name is None:
            return f"{COMMENT_CHAR} Group:"
        else:
            return f"{COMMENT_CHAR} Group: {group_name}"

    def parse_lines(self, file_lines: List[str]):
        """Parse a list of strings into a ConfigFile object."""
        if not self.has_managed_block(file_lines):
            raise SyntaxError(f"File {CONFIG_FILEPATH} does not contain a managed block")
        line_type = 'prepend'
        for line in file_lines:
            if line == self._managed_block_start_delimiter():
                line_type = 'managed'
                continue
            elif line == self._managed_block_end_delimiter():
                line_type = 'append'
                continue
            else:
                if line_type == 'prepend':
                    self.prepended_lines.append(line)
                elif line_type == 'managed':
                    if line.strip() == '':
                        continue
                    self.managed_lines.append(line)
                elif line_type == 'append':
                    self.appended_lines.append(line)

    def dump_lines(self):
        """Dump a ConfigFile object to a list of strings."""
        prepended = self.prepended_lines
        managed = self.managed_lines
        appended = self.appended_lines

        output = prepended + [self._managed_block_start_delimiter()] + managed + [self._managed_block_end_delimiter()] + appended
        return output

    def parse_groups(self):
        """Parse the managed lines into Group objects."""

        groups = {}
        for line in self.managed_lines:
            if not (line.startswith(COMMENT_CHAR) or line.strip() == ''):
                nodename, _groupnames = line.strip().split(' ')
                groupnames = _groupnames.split(',')
                for groupname in groupnames:
                    if groupname == 'all':
                        continue
                    if groupname not in groups:
                        groups[groupname] = []
                    groups[groupname].append(nodename)
        self.groups = groups

    def dump_groups(self):
        """Dump a ConfigFile object to a list of strings."""
        managed_lines = []
        for nodename, groupnames in self.nodes.items():
            managed_lines.append(f"{nodename} {','.join(['all']+groupnames)}\n")

        self.managed_lines = managed_lines

    def __repr__(self) -> str:
        return f"ConfigFile: {self.prepended_lines} {self.managed_lines} {self.appended_lines}"

class CLI:
    """CLI interface for ConfigFile."""

    @classmethod
    def create_group(cls, groupname, nodenames):
        """Update a configfile creating a new group with the given name and nodes."""

        config_file = ConfigFile()
        print(f"Editing: {CONFIG_FILEPATH}", file=sys.stderr)

        # Parse existing configuration
        with open(CONFIG_FILEPATH, "r", encoding="utf-8") as file:    
            config_file.parse_lines(file.readlines())
            config_file.parse_groups()

        # Check if supplied groupname is correct
        if groupname in config_file.groups:
            raise ValueError(f"Group {groupname} already exists in {CONFIG_FILEPATH}")
        # Update groups
        config_file.groups[groupname] = nodenames

        # Write updated configuration
        with open(CONFIG_FILEPATH, "w", encoding="utf-8") as file:
            config_file.dump_groups()
            config_file = config_file.dump_lines()
            file.writelines(config_file)
            print(grey(''.join(config_file)), file=sys.stderr)


    @classmethod
    def delete_group(cls, groupname):
        """Update a configfile deleting an existing group with given name."""

        config_file = ConfigFile()
        print(f"Editing: {CONFIG_FILEPATH}", file=sys.stderr)

        # Parse existing configuration
        with open(CONFIG_FILEPATH, "r", encoding="utf-8") as file:    
            config_file.parse_lines(file.readlines())
            config_file.parse_groups()

        # Check if supplied groupname is correct
        if groupname not in config_file.groups:
            raise LookupError(f"Group {groupname} not found in {CONFIG_FILEPATH}")
        # Update groups
        config_file.groups.pop(groupname)

        # Write updated configuration
        with open(CONFIG_FILEPATH, "w", encoding="utf-8") as file:
            config_file.dump_groups()
            config_file = config_file.dump_lines()
            file.writelines(config_file)
            print(grey(''.join(config_file)), file=sys.stderr)


    @classmethod
    def update_group(cls, groupname, nodenames):
        """Update a configfile file updateing an existing group with given name and nodes"""

        config_file = ConfigFile()
        print(f"Editing: {CONFIG_FILEPATH}", file=sys.stderr)

        # Parse existing configuration
        with open(CONFIG_FILEPATH, "r", encoding="utf-8") as file:    
            config_file.parse_lines(file.readlines())
            config_file.parse_groups()

        # Check if supplied groupname is correct
        if groupname not in config_file.groups:
            raise LookupError(f"Group {groupname} not found in {CONFIG_FILEPATH}")

        config_file.groups[groupname] = nodenames

        # Write updated configuration
        with open(CONFIG_FILEPATH, "w", encoding="utf-8") as file:
            config_file.dump_groups()
            config_file = config_file.dump_lines()
            file.writelines(config_file)
            print(grey(''.join(config_file)), file=sys.stderr)

    @classmethod
    def rename_group(cls, groupname, new_groupname):
        """Update a configfile file updateing an existing group with given name and nodes"""

        config_file = ConfigFile()
        print(f"Editing: {CONFIG_FILEPATH}", file=sys.stderr)

        # Parse existing configuration
        with open(CONFIG_FILEPATH, "r", encoding="utf-8") as file:    
            config_file.parse_lines(file.readlines())
            config_file.parse_groups()

        # Check if supplied groupname/new_groupname are correct
        if groupname not in config_file.groups:
            raise LookupError(f"Group {groupname} not found in {CONFIG_FILEPATH}")
        if new_groupname in config_file.groups:
            raise ValueError(f"Group {new_groupname} already exists in {CONFIG_FILEPATH}")

        config_file.groups[new_groupname] = config_file.groups[groupname]
        config_file.groups.pop(groupname)

        # Write updated configuration
        with open(CONFIG_FILEPATH, "w", encoding="utf-8") as file:
            config_file.dump_groups()
            config_file = config_file.dump_lines()
            file.writelines(config_file)
            print(grey(''.join(config_file)), file=sys.stderr)

    @classmethod
    def create_node(cls, nodename, groupnames):
        """Update a configfile creating a new node with the given name and groups."""

        config_file = ConfigFile()
        print(f"Editing: {CONFIG_FILEPATH}", file=sys.stderr)

        # Parse existing configuration
        with open(CONFIG_FILEPATH, "r", encoding="utf-8") as file:    
            config_file.parse_lines(file.readlines())
            config_file.parse_groups()

        # Check if supplied nodename is correct
        if nodename in config_file.nodes:
            raise ValueError(f"Node {nodename} already exists in {CONFIG_FILEPATH}")
        # Update groups
        for groupname in groupnames:
            if groupname not in config_file.groups:
                config_file.groups[groupname] = []
            config_file.groups[groupname].append(nodename)

        # Write updated configuration
        with open(CONFIG_FILEPATH, "w", encoding="utf-8") as file:
            config_file.dump_groups()
            config_file = config_file.dump_lines()
            file.writelines(config_file)
            print(grey(''.join(config_file)), file=sys.stderr)

    @classmethod
    def delete_node(cls, nodename):
        """Update a configfile deleting an existing node with given name."""

        config_file = ConfigFile()
        print(f"Editing: {CONFIG_FILEPATH}", file=sys.stderr)

        # Parse existing configuration
        with open(CONFIG_FILEPATH, "r", encoding="utf-8") as file:    
            config_file.parse_lines(file.readlines())
            config_file.parse_groups()

        # Check if supplied nodename is correct
        if nodename not in config_file.nodes:
            raise LookupError(f"Node {nodename} not found in {CONFIG_FILEPATH}")
        # Update groups
        for groupname in config_file.nodes[nodename]:
            config_file.groups[groupname].remove(nodename)

        # Write updated configuration
        with open(CONFIG_FILEPATH, "w", encoding="utf-8") as file:
            config_file.dump_groups()
            config_file = config_file.dump_lines()
            file.writelines(config_file)
            print(grey(''.join(config_file)), file=sys.stderr)

    @classmethod
    def update_node(cls, nodename, groupnames):
        """Update a configfile file updateing an existing node with given name and groups"""

        config_file = ConfigFile()
        print(f"Editing: {CONFIG_FILEPATH}", file=sys.stderr)

        # Parse existing configuration
        with open(CONFIG_FILEPATH, "r", encoding="utf-8") as file:    
            config_file.parse_lines(file.readlines())
            config_file.parse_groups()

        # Check if supplied nodename is correct
        if nodename not in config_file.nodes:
            raise LookupError(f"Node {nodename} not found in {CONFIG_FILEPATH}")

        for groupname in config_file.nodes[nodename]:
            config_file.groups[groupname].remove(nodename)
        for groupname in groupnames:
            if groupname not in config_file.groups:
                config_file.groups[groupname] = []
            config_file.groups[groupname].append(nodename)

        # Write updated configuration
        with open(CONFIG_FILEPATH, "w", encoding="utf-8") as file:
            config_file.dump_groups()
            config_file = config_file.dump_lines()
            file.writelines(config_file)
            print(grey(''.join(config_file)), file=sys.stderr)

    @classmethod
    def rename_node(cls, nodename, new_nodename):
        """Update a configfile file updateing an existing node with given name and groups"""

        config_file = ConfigFile()
        print(f"Editing: {CONFIG_FILEPATH}", file=sys.stderr)

        # Parse existing configuration
        with open(CONFIG_FILEPATH, "r", encoding="utf-8") as file:    
            config_file.parse_lines(file.readlines())
            config_file.parse_groups()

        # Check if supplied nodename/new_nodename are correct
        if nodename not in config_file.nodes:
            raise LookupError(f"Node {nodename} not found in {CONFIG_FILEPATH}")
        if new_nodename in config_file.nodes:
            raise ValueError(f"Node {new_nodename} already exists in {CONFIG_FILEPATH}")

        for groupname in config_file.nodes[nodename]:
            config_file.groups[groupname].remove(nodename)
            config_file.groups[groupname].append(new_nodename)


        # Write updated configuration
        with open(CONFIG_FILEPATH, "w", encoding="utf-8") as file:
            config_file.dump_groups()
            config_file = config_file.dump_lines()
            file.writelines(config_file)
            print(grey(''.join(config_file)), file=sys.stderr)

def main():
    """CLI interface for ConfigFile."""
    parser = argparse.ArgumentParser(description='Manage  groups.')
    # Add a subparser for each command
    subparsers = parser.add_subparsers(help='sub-command help', dest='target')

    group_parser = subparsers.add_parser('group', help='Manage  groups.')
    group_subparsers = group_parser.add_subparsers(help='sub-command help', dest='command')
    # Create a parser for the group_create command
    create_parser = group_subparsers.add_parser('create', help='Create a  group')
    create_parser.add_argument('groupname', type=str, help='Name of the group to create')
    create_parser.add_argument('nodenames', type=str, help='Names of the nodes to add to the group')
    # Create a parser for the group_delete command
    delete_parser = group_subparsers.add_parser('delete', help='Delete a  group')
    delete_parser.add_argument('groupname', type=str, help='Name of the group to delete')
    # Create a parser for the group_update command
    update_parser = group_subparsers.add_parser('update', help='update a  group')
    update_parser.add_argument('groupname', type=str, help='Name of the group to update')
    update_parser.add_argument('nodenames', type=str, help='Names of the nodes to add to the group')
    # Create a parser for the group_rename command
    rename_parser = group_subparsers.add_parser('rename', help='Rename a  group')
    rename_parser.add_argument('groupname', type=str, help='Name of the group to rename')
    rename_parser.add_argument('new_groupname', type=str, help='New name of the group')

    node_parser = subparsers.add_parser('node', help='Manage  nodes.')
    node_subparsers = node_parser.add_subparsers(help='sub-command help', dest='command')
    # Create a parser for the node_create command
    create_parser = node_subparsers.add_parser('create', help='Create a  node')
    create_parser.add_argument('nodename', type=str, help='Name of the node to create')
    create_parser.add_argument('groupnames', type=str, help='Names of the groups to add to the node')
    # Create a parser for the node_delete command
    delete_parser = node_subparsers.add_parser('delete', help='Delete a  node')
    delete_parser.add_argument('nodename', type=str, help='Name of the node to delete')
    # Create a parser for the node_update command
    update_parser = node_subparsers.add_parser('update', help='update a  node')
    update_parser.add_argument('nodename', type=str, help='Name of the node to update')
    update_parser.add_argument('groupnames', type=str, help='Names of the groups to add to the node')
    # Create a parser for the node_rename command
    rename_parser = node_subparsers.add_parser('rename', help='Rename a  node')
    rename_parser.add_argument('nodename', type=str, help='Name of the node to rename')
    rename_parser.add_argument('new_nodename', type=str, help='New name of the node')


    
    # Parse the arguments
    args = parser.parse_args()
    # Execute the command
    if args.target == 'group':
        if args.command == 'create':
            CLI.create_group(args.groupname, args.nodenames.split(','))
        elif args.command == 'delete':
            CLI.delete_group(args.groupname)
        elif args.command == 'update':
            CLI.update_group(args.groupname, args.nodenames.split(','))
        elif args.command == 'rename':
            CLI.rename_group(args.groupname, args.new_groupname)
        else:
            group_parser.print_help()
    elif args.target == 'node':
        if args.command == 'create':
            CLI.create_node(args.nodename, args.groupnames.split(','))
        elif args.command == 'delete':
            CLI.delete_node(args.nodename)
        elif args.command == 'update':
            CLI.update_node(args.nodename, args.groupnames.split(','))
        elif args.command == 'rename':
            CLI.rename_node(args.nodename, args.new_nodename)
        else:
            node_parser.print_help()
    else:
        parser.print_help()
if __name__ == "__main__":
    main()

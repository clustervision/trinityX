#!/bin/bash

# bash completion for obol

# This code is part of the TrinityX software suite
# Copyright (C) 2026  ClusterVision Solutions b.v.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>

# Install: /etc/bash_completion.d/obol.sh
#
# What completes
#   obol <Tab>                 the commands: user group import export
#   obol -<Tab>                the global options; -c/--config completes a file
#   obol user|group <Tab>      the verbs of that command
#   <verb> -<Tab>              the options of that verb
#   username / groupname       existing names where the verb acts on an existing user or
#                              group (user modify/show/delete, group modify/rename/addusers/
#                              delusers/show/delete, the usernames of addusers/delusers); not
#                              for user add / group add, which take a new name
#   --users, --groups, --group names, comma lists continued
#
# Names come from `obol --json user list` / `obol --json group list`, run with the global
# connection options already on the command line so they come from the same directory the
# command will use. The call is bounded by `timeout` and completes nothing when it fails,
# so an unreachable directory never hangs the shell. It only runs at a name position.
# Standalone: needs bash >= 4.0 (compopt, mapfile); does not need the bash-completion
# package or obol to load.

# ---- the parser ------------------------------------------------------------------------

_obol_commands='user group import export'
_obol_global_opts='-c --config -D --bind-dn -w --bind-pass -H --host -b --base-dn -U --user-ou -G --group-ou -J --json -h --help'
# the global options that take a value, short and long
_obol_global_optargs='cDwHbUG'
_obol_global_optargs_long='--config --bind-dn --bind-pass --host --base-dn --user-ou --group-ou'

_obol_verbs() {
    case $1 in
        user)  printf '%s' 'add modify show delete list' ;;
        group) printf '%s' 'add modify rename addusers delusers show delete list' ;;
    esac
}

_obol_user_attr_opts='-p --password -P --prompt-password --autogen --autogen-password --cn --sn --givenName -g --group --uid --gid --mail --phone --shell --groups --expire --home'
_obol_group_attr_opts='--gid --users'

# Options of a verb; _obol_verb_optargs are those that take a value.
_obol_verb_opts() {
    case $1/$2 in
        user/add|user/modify)   printf '%s' "$_obol_user_attr_opts -h --help" ;;
        group/add|group/modify) printf '%s' "$_obol_group_attr_opts -h --help" ;;
        *)                      printf '%s' '-h --help' ;;
    esac
}
_obol_verb_optargs='-p --password --cn --sn --givenName -g --group --uid --gid --mail --phone --shell --groups --expire --home --users'

_obol_takes_value() {  # $1 word, $2 space-separated list of options
    [[ " $2 " == *" $1 "* ]]
}

# ---- names from the directory ----------------------------------------------------------

# Names of one kind: $1 = user|group, the rest the global connection options as typed.
_obol_names() {
    local kind=$1 bin key
    shift
    bin=$(type -P obol) || return 1
    case $kind in user) key=uid ;; group) key=cn ;; esac
    timeout 5 "$bin" "$@" --json "$kind" list 2>/dev/null |
        sed -n "s/^[[:space:]]*\"$key\": \"\\(.*\\)\",\\{0,1\\}\$/\\1/p" | LC_ALL=C sort -u
}

# Complete the last element of a comma list against $2, keeping everything before it.
_obol_list_element() {
    local cur=$1 words=$2 prefix='' w
    [[ $cur == *,* ]] && { prefix=${cur%,*},; cur=${cur##*,}; }
    COMPREPLY=()
    while IFS= read -r w; do COMPREPLY+=("$prefix$w"); done < <(compgen -W "$words" -- "$cur")
    compopt -o nospace 2>/dev/null
}

# ---- completion ------------------------------------------------------------------------

# COMP_WORDS as obol sees them: readline splits on `=` and `:`, which bind DNs and ldap://
# hosts contain, so join those pieces back and find the index of the word under the cursor.
_obol_words() {
    local i w last
    words=(); cword=0
    for ((i = 0; i < ${#COMP_WORDS[@]}; i++)); do
        w=${COMP_WORDS[i]}
        last=$(( ${#words[@]} - 1 ))
        if (( i > 0 )) && [[ $w == [=:]* || ${words[last]} == *[=:] ]]; then
            words[last]+=$w
        else
            words+=("$w")
        fi
        (( i == COMP_CWORD )) && cword=$(( ${#words[@]} - 1 ))
    done
}

_obol() {
    local cur=${COMP_WORDS[COMP_CWORD]}
    local -a words conn pos
    local cword i w opt='' cmd='' verb=''
    COMPREPLY=()
    _obol_words

    # walk the line before the cursor: global options, command, verb, verb options, positionals
    for ((i = 1; i < cword; i++)); do
        w=${words[i]}
        if [[ -n $opt ]]; then                       # the value of the option before it
            [[ -z $cmd ]] && conn+=("$w")
            opt=''; continue
        fi
        if [[ -z $cmd ]]; then
            case $w in
                -[$_obol_global_optargs])  opt=$w; conn+=("$w") ;;
                -[$_obol_global_optargs]?*|--*=*) conn+=("$w") ;;
                -*) _obol_takes_value "$w" "$_obol_global_optargs_long" && { opt=$w; conn+=("$w"); } ;;
                *)  cmd=$w ;;
            esac
        elif [[ -z $verb && $cmd == @(user|group) ]]; then
            [[ $w != -* ]] && verb=$w
        else
            case $w in
                --*=*) ;;
                -*) _obol_takes_value "$w" "$_obol_verb_optargs" && opt=$w ;;
                *)  pos+=("$w") ;;
            esac
        fi
    done

    # the word under the cursor is the value of an option
    local val=$cur
    [[ -z $opt && ${words[cword]} == --*=* ]] && opt=${words[cword]%%=*}
    case $opt in
        -c|--config) compopt -o default 2>/dev/null; mapfile -t COMPREPLY < <(compgen -f -- "$val"); return ;;
        -g|--group)  [[ $cmd == user ]] && mapfile -t COMPREPLY < <(compgen -W "$(_obol_names group "${conn[@]}")" -- "$val"); return ;;
        --groups)    [[ $cmd == user ]] && _obol_list_element "$val" "$(_obol_names group "${conn[@]}")"; return ;;
        --users)     [[ $cmd == group ]] && _obol_list_element "$val" "$(_obol_names user "${conn[@]}")"; return ;;
        ?*)          return ;;                       # a DN, a host, a password: nothing to offer
    esac

    if [[ -z $cmd ]]; then
        if [[ $cur == -* ]]; then
            mapfile -t COMPREPLY < <(compgen -W "$_obol_global_opts" -- "$cur")
        else
            mapfile -t COMPREPLY < <(compgen -W "$_obol_commands" -- "$cur")
        fi
        return
    fi
    if [[ -z $verb && $cmd == @(user|group) ]]; then
        if [[ $cur == -* ]]; then
            mapfile -t COMPREPLY < <(compgen -W '-h --help' -- "$cur")
        else
            mapfile -t COMPREPLY < <(compgen -W "$(_obol_verbs "$cmd")" -- "$cur")
        fi
        return
    fi
    if [[ $cur == -* ]]; then
        mapfile -t COMPREPLY < <(compgen -W "$(_obol_verb_opts "$cmd" "$verb")" -- "$cur")
        return
    fi

    # a positional: which names it takes, if any
    local kind='' npos=${#pos[@]} required=1
    case $cmd/$verb in
        user/modify|user/show|user/delete)        (( npos == 0 )) && kind=user ;;
        group/modify|group/show|group/delete)     (( npos == 0 )) && kind=group ;;
        group/rename)                             (( npos == 0 )) && kind=group; required=2 ;;
        group/addusers|group/delusers)            if (( npos == 0 )); then kind=group; else kind=user; fi; required=99 ;;
        user/add|group/add)                       ;;
        *)                                        required=0 ;;
    esac
    if [[ -n $kind ]]; then
        mapfile -t COMPREPLY < <(compgen -W "$(_obol_names "$kind" "${conn[@]}")" -- "$cur")
    elif (( npos >= required )); then
        mapfile -t COMPREPLY < <(compgen -W "$(_obol_verb_opts "$cmd" "$verb")" -- "$cur")
    fi
}

complete -F _obol obol

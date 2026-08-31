#!/usr/bin/env bash
# Migrate TrinityX group_vars/all.yml to the current all.yml.example layout.
#
# Plain Bash implementation for the TrinityX all.yml style. It uses
# group_vars/all.yml.example as the schema/template:
#   - use all.yml.example for non-string/non-boolean variables;
#   - drop variables no longer present in all.yml.example;
#   - for booleans, suggest/use the all.yml.example value;
#   - for strings, suggest/use the all.yml value when present;
#   - for trix_version, suggest/use the all.yml.example value;
#   - for the firewall interface/port lists and the DNS forwarders, suggest/use
#     the all.yml value when present (they describe the deployed cluster);
#   - keep comments/order and the current yml check marker from all.yml.example.
# Boolean prompts accept yes/y/true and no/n/false (any case) and re-ask on any
# other answer.
# For retained string values, only the value is reused; comments come from
# all.yml.example. Before writing, the original all.yml is copied to all.yml.bkp
# next to all.yml.

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
ALL_YML="$SCRIPT_DIR/group_vars/all.yml"
EXAMPLE_YML="$SCRIPT_DIR/group_vars/all.yml.example"
OUTPUT_YML=""
KEEP_DEFAULTS=0
DRY_RUN=0

usage() {
    cat <<'EOF'
Usage: migrate_all_yml.sh [options]

Migrate group_vars/all.yml so its active top-level keys match group_vars/all.yml.example.

Options:
  --all-yml PATH      Existing all.yml to migrate
                      default: group_vars/all.yml next to this script
  --example PATH      all.yml.example schema/template
                      default: group_vars/all.yml.example next to this script
  --output PATH       Output path; default overwrites --all-yml after copying
                      --all-yml to all.yml.bkp
  --keep-defaults     Use suggested values without prompting
  --dry-run           Print migrated YAML to stdout instead of writing it
  -h, --help          Show this help

Notes:
  Before overwriting --all-yml, a copy is always written as all.yml.bkp in the
  same directory.
  This is a plain Bash/YAML-block merger for TrinityX all.yml files. It does
  not parse arbitrary YAML; it preserves top-level key blocks verbatim.
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --all-yml)
            [ "$#" -ge 2 ] || { echo "ERROR: --all-yml needs a path" >&2; exit 2; }
            ALL_YML=$2
            shift 2
            ;;
        --example)
            [ "$#" -ge 2 ] || { echo "ERROR: --example needs a path" >&2; exit 2; }
            EXAMPLE_YML=$2
            shift 2
            ;;
        --output)
            [ "$#" -ge 2 ] || { echo "ERROR: --output needs a path" >&2; exit 2; }
            OUTPUT_YML=$2
            shift 2
            ;;
        --keep-defaults)
            KEEP_DEFAULTS=1
            shift
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --no-backup)
            echo "ERROR: --no-backup is not supported; all.yml.bkp is always written before overwriting all.yml" >&2
            exit 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "ERROR: unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

[ -n "$OUTPUT_YML" ] || OUTPUT_YML=$ALL_YML

[ -f "$ALL_YML" ] || { echo "ERROR: existing all.yml not found: $ALL_YML" >&2; exit 1; }
[ -f "$EXAMPLE_YML" ] || { echo "ERROR: all.yml.example not found: $EXAMPLE_YML" >&2; exit 1; }

WORKDIR=$(mktemp -d)
cleanup() {
    rm -rf -- "$WORKDIR"
}
trap cleanup EXIT

EXAMPLE_KEYS="$WORKDIR/example.keys"
OLD_KEYS="$WORKDIR/old.keys"
NEW_KEYS="$WORKDIR/new.keys"
DROPPED_KEYS="$WORKDIR/dropped.keys"
CHANGED_KEYS="$WORKDIR/changed.keys"
MERGED="$WORKDIR/all.yml"
KEY_BLOCKS="$WORKDIR/key_blocks"
mkdir -p -- "$KEY_BLOCKS/example" "$KEY_BLOCKS/old" "$KEY_BLOCKS/new"
: > "$NEW_KEYS"
: > "$DROPPED_KEYS"
: > "$CHANGED_KEYS"

extract_blocks() {
    local input=$1
    local outdir=$2
    local keyfile=$3

    mkdir -p -- "$outdir"
    : > "$keyfile"

    awk -v outdir="$outdir" -v keyfile="$keyfile" '
        function close_block() {
            if (key != "") {
                close(file)
                key = ""
                file = ""
            }
        }
        function start_block(line, newkey) {
            close_block()
            key = newkey
            print key >> keyfile
            file = outdir "/" key
            print line > file
        }
        /^[A-Za-z_][A-Za-z0-9_]*:[[:space:]]*/ {
            split($0, parts, ":")
            start_block($0, parts[1])
            next
        }
        /^[[:space:]]/ || /^$/ {
            if (key != "") {
                print $0 >> file
            }
            next
        }
        {
            close_block()
            next
        }
        END { close_block() }
    ' "$input"
}

extract_blocks "$EXAMPLE_YML" "$KEY_BLOCKS/example" "$EXAMPLE_KEYS"
extract_blocks "$ALL_YML" "$KEY_BLOCKS/old" "$OLD_KEYS"

if [ ! -s "$EXAMPLE_KEYS" ]; then
    echo "ERROR: no top-level keys found in $EXAMPLE_YML" >&2
    exit 1
fi

is_key_in_example() {
    local wanted=$1
    awk -v wanted="$wanted" 'BEGIN { found=1 } $0 == wanted { found=0; exit } END { exit found }' "$EXAMPLE_KEYS"
}

block_kind() {
    local block=$1
    awk '
        BEGIN {
            sq = sprintf("%c", 39)
            dq = sprintf("%c", 34)
        }
        NR == 1 {
            line = $0
            sub(/^[A-Za-z_][A-Za-z0-9_]*:[[:space:]]*/, "", line)
            sub(/[[:space:]]+#.*$/, "", line)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
            if (line == "true" || line == "false" || line == "True" || line == "False" || line == "TRUE" || line == "FALSE") {
                print "bool"
            } else if ((substr(line, 1, 1) == sq && substr(line, length(line), 1) == sq) || (substr(line, 1, 1) == dq && substr(line, length(line), 1) == dq)) {
                print "string"
            } else if (line == "") {
                print "complex"
            } else if (line ~ /^\[.*\]$/ || line ~ /^\{.*\}$/) {
                print "complex"
            } else if (line ~ /^[-+]?[0-9]+(\.[0-9]+)?$/) {
                print "complex"
            } else {
                print "string"
            }
        }
    ' "$block"
}

first_value() {
    local block=$1
    awk '
        NR == 1 {
            line = $0
            sub(/^[A-Za-z_][A-Za-z0-9_]*:[[:space:]]*/, "", line)
            sub(/[[:space:]]+#.*$/, "", line)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
            print line
        }
    ' "$block"
}

render_default_prompt() {
    local block=$1
    awk '
        NR == 1 {
            sub(/^[A-Za-z_][A-Za-z0-9_]*:[[:space:]]*/, "")
            if ($0 != "") {
                print $0
                next
            }
        }
        NR > 1 {
            line = $0
            sub(/^  /, "", line)
            if (line != "") {
                if (out != "") out = out " "
                out = out line
            }
        }
        END {
            if (out != "") print out
        }
    ' "$block"
}

write_value_with_example_comments() {
    local key=$1
    local value=$2
    local example_block=$3
    local output_block=$4

    awk -v key="$key" -v value="$value" '
        NR == 1 {
            comment = ""
            line = $0
            if (match(line, /[[:space:]]+#/)) {
                comment = substr(line, RSTART)
            }
            print key ": " value comment
            next
        }
        { print }
    ' "$example_block" > "$output_block"
}

# Keys whose configured value in all.yml is authoritative and must be
# preserved on migration regardless of type. HA, fencing and the LDAP
# backend describe the deployed cluster; all.yml is the truth (TRIX-1905).
ALL_YML_AUTHORITATIVE_KEYS="ha enable_ipmilan_fencing enable_heartbeat_link trinity_ldap_backend"

is_authoritative_key() {
    local wanted=$1
    local key
    for key in $ALL_YML_AUTHORITATIVE_KEYS; do
        [ "$key" = "$wanted" ] && return 0
    done
    return 1
}

# Firewall interface and port lists describe the deployed cluster's network
# layout; the example's [ens3]/[ens6] defaults would wipe the real NICs, so
# all.yml is the truth (TRIX-1905). These are single-line inline lists and go
# through the normal suggest/prompt path with all.yml as the source.
FIREWALL_ALL_YML_KEYS="firewalld_public_interfaces firewalld_trusted_interfaces firewalld_public_tcp_ports firewalld_public_udp_ports"

# DNS forwarders (the cluster's nameservers) likewise come from the deployed
# cluster (TRIX-1905). This is a multi-line block list, so the whole block is
# taken from all.yml rather than offered for inline editing.
NAMESERVER_ALL_YML_KEYS="trix_dns_forwarders"

key_in_list() {
    local wanted=$1
    local list=$2
    local key
    for key in $list; do
        [ "$key" = "$wanted" ] && return 0
    done
    return 1
}

is_firewall_key() {
    key_in_list "$1" "$FIREWALL_ALL_YML_KEYS"
}

is_nameserver_key() {
    key_in_list "$1" "$NAMESERVER_ALL_YML_KEYS"
}

# Normalise a boolean answer. Accepts yes/y/true and no/n/false in any case;
# prints the canonical true/false. Returns non-zero for anything else so the
# caller can re-ask.
normalize_bool() {
    local answer
    answer=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
    case "$answer" in
        y|yes|true) printf 'true\n' ;;
        n|no|false) printf 'false\n' ;;
        *) return 1 ;;
    esac
}

suggested_value() {
    local key=$1
    local kind=$2
    local old_block=$3
    local example_block=$4

    if is_authoritative_key "$key" && [ -n "$old_block" ] && [ -f "$old_block" ]; then
        first_value "$old_block"
    elif [ "$kind" = "string" ] && [ "$key" != "trix_version" ] && [ -n "$old_block" ] && [ -f "$old_block" ]; then
        first_value "$old_block"
    elif [ "$key" = "trinity_ldap_backend" ]; then
        # Backend key absent from all.yml means a pre-16 cluster, which ran
        # openldap; never migrate it onto the new ds389 default (TRIX-1905).
        printf "%s\n" "'openldap'"
    else
        first_value "$example_block"
    fi
}

suggestion_source() {
    local key=$1
    local kind=$2
    local old_block=$3

    if is_authoritative_key "$key" && [ -n "$old_block" ] && [ -f "$old_block" ]; then
        printf '%s\n' "all.yml"
    elif [ "$kind" = "string" ] && [ "$key" != "trix_version" ] && [ -n "$old_block" ] && [ -f "$old_block" ]; then
        printf '%s\n' "all.yml"
    elif [ "$key" = "trinity_ldap_backend" ]; then
        printf '%s\n' "migration default"
    else
        printf '%s\n' "all.yml.example"
    fi
}

prompt_value() {
    local reason=$1
    local key=$2
    local current_block=$3
    local example_block=$4
    local suggested=$5
    local source=$6
    local output_block=$7
    local kind=$8
    local current_text answer normalized

    current_text=""
    if [ -n "$current_block" ] && [ -f "$current_block" ]; then
        current_text=$(render_default_prompt "$current_block")
    fi

    while :; do
        if [ -n "$current_text" ]; then
            printf '%s %s (current: %s, suggested from %s: %s): ' "$reason" "$key" "$current_text" "$source" "$suggested" >&2
        else
            printf '%s %s [suggested from %s: %s]: ' "$reason" "$key" "$source" "$suggested" >&2
        fi
        IFS= read -r answer || answer=""

        if [ -z "$answer" ]; then
            write_value_with_example_comments "$key" "$suggested" "$example_block" "$output_block"
            return
        fi

        if [ "$kind" = "bool" ]; then
            if normalized=$(normalize_bool "$answer"); then
                write_value_with_example_comments "$key" "$normalized" "$example_block" "$output_block"
                return
            fi
            printf 'Please answer yes/y/true or no/n/false.\n' >&2
            continue
        fi

        write_value_with_example_comments "$key" "$answer" "$example_block" "$output_block"
        return
    done
}

should_prompt() {
    [ "$KEEP_DEFAULTS" -eq 0 ]
}

while IFS= read -r key; do
    if ! is_key_in_example "$key"; then
        printf '%s\n' "$key" >> "$DROPPED_KEYS"
    fi
done < "$OLD_KEYS"

while IFS= read -r key <&3; do
    old_block="$KEY_BLOCKS/old/$key"
    example_block="$KEY_BLOCKS/example/$key"
    new_block="$KEY_BLOCKS/new/$key"
    kind=$(block_kind "$example_block")

    if [ -f "$old_block" ]; then
        old_value=$(first_value "$old_block")
        example_value=$(first_value "$example_block")
        if is_nameserver_key "$key"; then
            # Multi-line block list: keep the deployed cluster's forwarders
            # verbatim; comments still come from all.yml.example around it.
            cp -- "$old_block" "$new_block"
            if ! diff -q -- "$old_block" "$example_block" >/dev/null 2>&1; then
                printf '%s\n' "$key" >> "$CHANGED_KEYS"
            fi
        elif is_firewall_key "$key"; then
            # Single-line inline list: suggest the deployed cluster's value.
            suggested=$old_value
            source="all.yml"
            if [ "$old_value" != "$example_value" ]; then
                printf '%s\n' "$key" >> "$CHANGED_KEYS"
            fi
            if should_prompt; then
                prompt_value "Firewall option" "$key" "$old_block" "$example_block" "$suggested" "$source" "$new_block" "$kind"
            else
                write_value_with_example_comments "$key" "$suggested" "$example_block" "$new_block"
            fi
        elif [ "$kind" != "string" ] && [ "$kind" != "bool" ]; then
            cp -- "$example_block" "$new_block"
        else
            suggested=$(suggested_value "$key" "$kind" "$old_block" "$example_block")
            source=$(suggestion_source "$key" "$kind" "$old_block")
            if [ "$old_value" != "$example_value" ]; then
                printf '%s\n' "$key" >> "$CHANGED_KEYS"
                if should_prompt; then
                    prompt_value "Changed option" "$key" "$old_block" "$example_block" "$suggested" "$source" "$new_block" "$kind"
                else
                    write_value_with_example_comments "$key" "$suggested" "$example_block" "$new_block"
                fi
            else
                write_value_with_example_comments "$key" "$suggested" "$example_block" "$new_block"
            fi
        fi
    else
        printf '%s\n' "$key" >> "$NEW_KEYS"
        if [ "$kind" = "string" ] || [ "$kind" = "bool" ]; then
            suggested=$(suggested_value "$key" "$kind" "" "$example_block")
            source=$(suggestion_source "$key" "$kind" "")
            if should_prompt; then
                prompt_value "New option" "$key" "" "$example_block" "$suggested" "$source" "$new_block" "$kind"
            else
                write_value_with_example_comments "$key" "$suggested" "$example_block" "$new_block"
            fi
        else
            cp -- "$example_block" "$new_block"
        fi
    fi
done 3< "$EXAMPLE_KEYS"

awk -v blocks="$KEY_BLOCKS/new" '
    function print_block(key) {
        while ((getline block_line < (blocks "/" key)) > 0) {
            print block_line
        }
        close(blocks "/" key)
    }
    /^[A-Za-z_][A-Za-z0-9_]*:[[:space:]]*/ {
        split($0, parts, ":")
        print_block(parts[1])
        skip = 1
        next
    }
    /^[[:space:]]/ || /^$/ {
        if (skip) next
        print
        next
    }
    {
        skip = 0
        print
    }
' "$EXAMPLE_YML" > "$MERGED"

extract_blocks "$MERGED" "$WORKDIR/merged_blocks" "$WORKDIR/merged.keys"
if ! diff -u -- "$EXAMPLE_KEYS" "$WORKDIR/merged.keys" > "$WORKDIR/key.diff"; then
    echo "ERROR: generated key order does not match all.yml.example:" >&2
    sed 's/^/  /' "$WORKDIR/key.diff" >&2
    exit 1
fi

if ! awk '/#[[:space:]]*DO NOT REMOVE:[[:space:]]*yml check:[[:space:]]*[0-9]+/ { found=1 } END { exit found ? 0 : 1 }' "$MERGED"; then
    echo "ERROR: generated all.yml is missing the all.yml.example yml check marker" >&2
    exit 1
fi

print_key_list() {
    local label=$1
    local file=$2
    if [ -s "$file" ]; then
        printf '%s: ' "$label" >&2
        awk 'BEGIN { first=1 } { if (!first) printf ", "; printf "%s", $0; first=0 } END { printf "\n" }' "$file" >&2
    fi
}

print_key_list "New options added" "$NEW_KEYS"
print_key_list "Changed options reviewed" "$CHANGED_KEYS"
print_key_list "Dropped obsolete options" "$DROPPED_KEYS"

if [ ! -s "$NEW_KEYS" ] && [ ! -s "$CHANGED_KEYS" ] && [ ! -s "$DROPPED_KEYS" ]; then
    echo "No schema key additions, removals, or string/boolean default changes detected." >&2
fi

if [ "$DRY_RUN" -eq 1 ]; then
    awk '{ print }' "$MERGED"
    exit 0
fi

make_all_yml_bkp() {
    local path=$1
    local backup
    backup="$(dirname -- "$path")/all.yml.bkp"
    cp -p -- "$path" "$backup"
    printf '%s\n' "$backup"
}

canonical_path() {
    local path=$1
    local dir base
    dir=$(dirname -- "$path")
    base=$(basename -- "$path")
    mkdir -p -- "$dir"
    printf '%s/%s\n' "$(cd -- "$dir" && pwd -P)" "$base"
}

if [ "$(canonical_path "$OUTPUT_YML")" = "$(canonical_path "$ALL_YML")" ]; then
    backup=$(make_all_yml_bkp "$ALL_YML")
    echo "Backup written: $backup" >&2
fi

mkdir -p -- "$(dirname -- "$OUTPUT_YML")"
cp -- "$MERGED" "$OUTPUT_YML"
echo "Migrated all.yml written: $OUTPUT_YML" >&2

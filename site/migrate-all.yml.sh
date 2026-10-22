#!/usr/bin/env bash
# Migrate TrinityX group_vars/all.yml to the current all.yml.example layout.
#
# Plain Bash implementation for the TrinityX all.yml style. It uses
# group_vars/all.yml.example as the schema/template:
#   - use all.yml.example for non-string/non-boolean variables;
#   - drop variables no longer present in all.yml.example;
#   - for booleans, suggest/use the all.yml.example value;
#   - for strings, suggest/use the all.yml value when present;
#   - trix_version is always taken from all.yml.example and never prompted;
#   - for the firewall interface/port lists, suggest/use the all.yml value when
#     present (they describe the deployed cluster);
#   - for the network settings, the DNS forwarders and the user names/passwords,
#     keep the all.yml block verbatim when present, without prompting;
#   - keep comments/order and the current yml check marker from all.yml.example.
# Boolean prompts accept yes/y/true and no/n/false (any case) and re-ask on any
# other answer.
# Values are resolved up front: the script first reads the latest
# all.yml.example (and its yml check version), works out the value to use for
# every key from all.yml / all.yml.example, and only then walks through the
# options that need a confirmation. On a terminal the resolved value is
# pre-filled in the input line, so pressing Enter accepts it and moves on to
# the next step; it can also be edited in place. Without a terminal (piped
# input) an empty answer accepts the resolved value, as before.
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
  --keep-defaults     Use the resolved values without prompting
  --dry-run           Print migrated YAML to stdout instead of writing it
  -h, --help          Show this help

Notes:
  Before overwriting --all-yml, a copy is always written as all.yml.bkp in the
  same directory.
  Values are resolved from all.yml / all.yml.example first; the options that
  need a confirmation are then shown one by one ([n/total]) with the value
  pre-filled, so Enter accepts it and moves to the next step.
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

yml_check_version() {
    awk '
        /#[[:space:]]*DO NOT REMOVE:[[:space:]]*yml check:[[:space:]]*[0-9]+/ {
            line = $0
            sub(/.*yml check:[[:space:]]*/, "", line)
            sub(/[^0-9].*$/, "", line)
            print line
            exit
        }
    ' "$1"
}

EXAMPLE_VERSION=$(yml_check_version "$EXAMPLE_YML")
OLD_VERSION=$(yml_check_version "$ALL_YML")
printf 'Latest all.yml.example: %s (yml check: %s)\n' "$EXAMPLE_YML" "${EXAMPLE_VERSION:-unknown}" >&2
printf 'Current all.yml:        %s (yml check: %s)\n' "$ALL_YML" "${OLD_VERSION:-none}" >&2
if [ -n "$EXAMPLE_VERSION" ] && [ -n "$OLD_VERSION" ] && [ "$OLD_VERSION" -gt "$EXAMPLE_VERSION" ] 2>/dev/null; then
    printf 'WARNING: all.yml (yml check %s) is newer than all.yml.example (yml check %s); is all.yml.example up to date?\n' "$OLD_VERSION" "$EXAMPLE_VERSION" >&2
fi

is_key_in_example() {
    local wanted=$1
    awk -v wanted="$wanted" 'BEGIN { found=1 } $0 == wanted { found=0; exit } END { exit found }' "$EXAMPLE_KEYS"
}

# awk function: index of the whitespace before a trailing YAML comment in a
# value, or 0. A "#" inside a quoted scalar is part of the value.
YAML_COMMENT_AWK='
    function comment_at(s,    sq, dq, q, c, i, n, start) {
        sq = sprintf("%c", 39)
        dq = sprintf("%c", 34)
        n = length(s)
        start = 1
        i = match(s, /[^[:space:]]/)
        q = (i > 0) ? substr(s, i, 1) : ""
        if (q == sq || q == dq) {
            for (i++; i <= n; i++) {
                c = substr(s, i, 1)
                if (q == dq && c == "\\") {
                    i++
                } else if (c == q) {
                    if (q == sq && substr(s, i + 1, 1) == sq) {
                        i++
                    } else {
                        break
                    }
                }
            }
            # An unterminated quote keeps the plain-scalar rule.
            if (i <= n) start = i + 1
        }
        if (match(substr(s, start), /[[:space:]]+#/)) return start + RSTART - 1
        return 0
    }
'

block_kind() {
    local block=$1
    awk "$YAML_COMMENT_AWK"'
        BEGIN {
            sq = sprintf("%c", 39)
            dq = sprintf("%c", 34)
        }
        NR == 1 {
            line = $0
            sub(/^[A-Za-z_][A-Za-z0-9_]*:[[:space:]]*/, "", line)
            if ((c = comment_at(line)) > 0) line = substr(line, 1, c - 1)
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
    awk "$YAML_COMMENT_AWK"'
        NR == 1 {
            line = $0
            sub(/^[A-Za-z_][A-Za-z0-9_]*:[[:space:]]*/, "", line)
            if ((c = comment_at(line)) > 0) line = substr(line, 1, c - 1)
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

    # Through the environment: awk -v would expand backslash escapes.
    MIGRATE_VALUE=$value awk -v key="$key" "$YAML_COMMENT_AWK"'
        NR == 1 {
            comment = ""
            line = substr($0, index($0, ":") + 1)
            if ((c = comment_at(line)) > 0) {
                comment = substr(line, c)
            }
            print key ": " ENVIRON["MIGRATE_VALUE"] comment
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

# Network settings, the DNS forwarders and user names/passwords describe the
# deployed cluster; their whole block is kept from all.yml, without a prompt.
CLUSTER_ALL_YML_KEYS="trix_domain trix_external_fqdn trix_login_fqdn resolv_search_domains \
trix_dns_forwarders \
trix_cluster_net trix_cluster_netprefix trix_cluster_dhcp_start trix_cluster_dhcp_end \
trix_infiniband_net trix_infiniband_netprefix trix_bmc_net trix_bmc_netprefix \
trix_ctrl1_ip trix_ctrl1_bmcip trix_ctrl1_heartbeat_ip trix_ctrl1_hostname \
trix_ctrl2_ip trix_ctrl2_bmcip trix_ctrl2_heartbeat_ip trix_ctrl2_hostname \
trix_ctrl_ip trix_ctrl_hostname \
fence_ipmilan_login fence_ipmilan_passwd luna_username luna_password \
luna_bmcsetup_user luna_bmcsetup_password luna_redfish_user luna_redfish_password \
easybuild_user"

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

is_cluster_key() {
    key_in_list "$1" "$CLUSTER_ALL_YML_KEYS"
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

# Read one answer. On a terminal the resolved value is pre-filled in the
# input line (readline), so Enter accepts it; otherwise fall back to a plain
# read where an empty answer means "accept".
# The answer is returned in PREFILLED_ANSWER (no command substitution, so
# readline keeps talking to the terminal).
read_prefilled() {
    local label=$1
    local default=$2

    PREFILLED_ANSWER=""
    if [ -t 0 ] && [ -t 2 ]; then
        IFS= read -r -e -p "$label" -i "$default" PREFILLED_ANSWER || PREFILLED_ANSWER=""
    else
        printf '%s[%s]: ' "$label" "$default" >&2
        IFS= read -r PREFILLED_ANSWER || PREFILLED_ANSWER=""
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
    local step=${9:-}
    local current_text answer normalized prefix

    current_text=""
    if [ -n "$current_block" ] && [ -f "$current_block" ]; then
        current_text=$(render_default_prompt "$current_block")
    fi

    prefix=""
    [ -n "$step" ] && prefix="[$step] "

    if [ -n "$current_text" ]; then
        printf '\n%s%s %s (current: %s; value taken from %s)\n' "$prefix" "$reason" "$key" "$current_text" "$source" >&2
    else
        printf '\n%s%s %s (value taken from %s)\n' "$prefix" "$reason" "$key" "$source" >&2
    fi

    while :; do
        read_prefilled "  $key: " "$suggested"
        answer=$PREFILLED_ANSWER

        if [ -z "$answer" ]; then
            answer=$suggested
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

# Prompts are queued while values are resolved and asked afterwards, so the
# user sees how many confirmations follow and steps through them in order.
PROMPTS="$WORKDIR/prompts"
: > "$PROMPTS"
FS=$(printf '\037')

queue_prompt() {
    # reason key old_block suggested source kind
    printf '%s\037%s\037%s\037%s\037%s\037%s\n' "$1" "$2" "$3" "$4" "$5" "$6" >> "$PROMPTS"
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
        if is_cluster_key "$key"; then
            # Keep the deployed cluster's block verbatim; comments still come
            # from all.yml.example around it.
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
            write_value_with_example_comments "$key" "$suggested" "$example_block" "$new_block"
            if should_prompt; then
                queue_prompt "Firewall option" "$key" "$old_block" "$suggested" "$source" "$kind"
            fi
        elif [ "$kind" != "string" ] && [ "$kind" != "bool" ]; then
            cp -- "$example_block" "$new_block"
        else
            suggested=$(suggested_value "$key" "$kind" "$old_block" "$example_block")
            source=$(suggestion_source "$key" "$kind" "$old_block")
            if [ "$old_value" != "$example_value" ]; then
                printf '%s\n' "$key" >> "$CHANGED_KEYS"
                write_value_with_example_comments "$key" "$suggested" "$example_block" "$new_block"
                if should_prompt && [ "$key" != "trix_version" ]; then
                    queue_prompt "Changed option" "$key" "$old_block" "$suggested" "$source" "$kind"
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
            write_value_with_example_comments "$key" "$suggested" "$example_block" "$new_block"
            if should_prompt && [ "$key" != "trix_version" ]; then
                queue_prompt "New option" "$key" "" "$suggested" "$source" "$kind"
            fi
        else
            cp -- "$example_block" "$new_block"
        fi
    fi
done 3< "$EXAMPLE_KEYS"

TOTAL_PROMPTS=$(awk 'END { print NR }' "$PROMPTS")
TOTAL_KEYS=$(awk 'END { print NR }' "$EXAMPLE_KEYS")
printf 'Resolved values for %s options from all.yml / all.yml.example.\n' "$TOTAL_KEYS" >&2
if [ "$TOTAL_PROMPTS" -gt 0 ]; then
    printf '%s option(s) to confirm; each value is pre-filled: press Enter to accept, or edit it first.\n' "$TOTAL_PROMPTS" >&2
    step=0
    while IFS="$FS" read -r p_reason p_key p_old p_suggested p_source p_kind <&3; do
        step=$((step + 1))
        prompt_value "$p_reason" "$p_key" "$p_old" "$KEY_BLOCKS/example/$p_key" \
            "$p_suggested" "$p_source" "$KEY_BLOCKS/new/$p_key" "$p_kind" "$step/$TOTAL_PROMPTS"
    done 3< "$PROMPTS"
    printf '\nAll %s option(s) confirmed.\n' "$TOTAL_PROMPTS" >&2
fi

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

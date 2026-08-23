#!/bin/sh
# Wire SayIP into ASL3 rpt.conf for a node number:
#   - ensure #tryinclude loads custom/rpt/*.conf (where sayip.conf lives)
#   - ensure [functions-NODE] inherits functions-sayip
#   - set functions / phone_functions / link_functions on [NODE]
#     (IAX phone-mode DTMF uses phone_functions, not functions)
#   - optional --unwire NODE removes functions-sayip from that node's table
set -e

unwire=0
if [ "${1-}" = "--unwire" ]; then
    unwire=1
    shift
fi

node="$1"
rpt="${RPT_CONF:-/etc/asterisk/rpt.conf}"

if [ -z "$node" ]; then
    echo "Usage: configure-rpt-sayip.sh [--unwire] <node_number>" >&2
    exit 1
fi

if ! echo "$node" | grep -qE '^[0-9]{1,10}$'; then
    echo "Invalid node number: $node" >&2
    exit 1
fi

if [ ! -f "$rpt" ]; then
    echo "Note: $rpt not found; skipping repeater function table setup."
    exit 0
fi

if [ "$unwire" -eq 0 ] && ! grep -qE "^\[${node}\]" "$rpt"; then
    echo "Warning: Node [$node] not found in $rpt; skipping repeater setup."
    echo "Add the node with asl-menu first, then reinstall or run:"
    echo "  sudo /usr/lib/sayip-node-utils/configure-rpt-sayip.sh $node"
    exit 0
fi

# Preserve original mode/owner across atomic replacement.
rpt_mode="$(stat -c '%a' "$rpt" 2>/dev/null || echo 644)"
rpt_uid="$(stat -c '%u' "$rpt" 2>/dev/null || echo 0)"
rpt_gid="$(stat -c '%g' "$rpt" 2>/dev/null || echo 0)"

fn="functions-${node}"
stage1="$(mktemp "${rpt}.sayip.XXXXXX")"
stage2="$(mktemp "${rpt}.sayip.XXXXXX")"
trap 'rm -f "$stage1" "$stage2"' EXIT

if [ "$unwire" -eq 1 ]; then
    # Strip functions-sayip from [functions-NODE] inheritance only.
    awk -v fn="$fn" '
    BEGIN { fn_re = "^\\[" fn "\\]" }
    {
        line = $0
        if (line ~ fn_re && line ~ /functions-sayip/) {
            # ",functions-sayip)" or "(functions-sayip," or ",functions-sayip,"
            gsub(/,functions-sayip/, "", line)
            gsub(/\(functions-sayip,/, "(", line)
            gsub(/\(functions-sayip\)/, "", line)
            # If inheritance list became empty, leave a bare stanza header.
            if (line ~ /^\[[^]]+\]\(\)$/) {
                sub(/\(\)$/, "", line)
            }
        }
        print line
    }
    ' "$rpt" > "$stage2"

    chmod "$rpt_mode" "$stage2"
    chown "$rpt_uid:$rpt_gid" "$stage2"
    mv "$stage2" "$rpt"
    trap - EXIT
    rm -f "$stage1"
    echo "Removed functions-sayip inheritance from $fn in $rpt (if present)."
    exit 0
fi

# Stage 1: ensure ASL3 custom rpt includes exist before node-related stanzas.
# Keep the result in stage1; do not replace rpt.conf until stage 2 succeeds.
awk '
BEGIN {
    has_rpt = 0
    has_glob = 0
    inserted = 0
}
{
    if ($0 ~ /^#tryinclude[[:space:]]+"custom\/rpt\.conf"/) has_rpt = 1
    if ($0 ~ /^#tryinclude[[:space:]]+"custom\/rpt\/\*\.conf"/) has_glob = 1
    lines[NR] = $0
}
END {
    for (i = 1; i <= NR; i++) {
        if (!inserted && (lines[i] ~ /^\[functions-[0-9]+\]/ || lines[i] ~ /^\[[0-9]+\]/)) {
            if (!has_rpt) print "#tryinclude \"custom/rpt.conf\""
            if (!has_glob) print "#tryinclude \"custom/rpt/*.conf\""
            if (!has_rpt || !has_glob) print ""
            inserted = 1
        }
        print lines[i]
    }
    if (!inserted) {
        if (!has_rpt) print "#tryinclude \"custom/rpt.conf\""
        if (!has_glob) print "#tryinclude \"custom/rpt/*.conf\""
    }
}
' "$rpt" > "$stage1"

# Stage 2: wire function table + phone/link overrides, reading staged stage1.
awk -v node="$node" -v fn="$fn" '
BEGIN {
    node_re = "^\\[" node "\\]"
    fn_re = "^\\[" fn "\\]"
    fn_stanza_seen = 0
    in_node = 0
    node_functions_set = 0
    node_phone_set = 0
    node_link_set = 0
}

function emit_node_overrides() {
    if (!node_functions_set) {
        print "functions = " fn
    }
    if (!node_phone_set) {
        print "phone_functions = " fn
    }
    if (!node_link_set) {
        print "link_functions = " fn
    }
}

function print_functions_stanza() {
    print "[" fn "](functions-main,functions-sayip)"
    fn_stanza_seen = 1
}

{
    line = $0

    if (line ~ fn_re) {
        fn_stanza_seen = 1
        if (line ~ /functions-sayip/) {
            print line
            next
        }
        if (line ~ /^\[[^]]+\]\([^)]+\)/) {
            sub(/\)$/, ",functions-sayip)", line)
            print line
            next
        }
        print_functions_stanza()
        next
    }

    if (line ~ node_re) {
        if (!fn_stanza_seen) {
            print_functions_stanza()
        }
        in_node = 1
        node_functions_set = 0
        node_phone_set = 0
        node_link_set = 0
        print line
        next
    }

    if (in_node && line ~ /^[[:space:]]*functions[[:space:]]*=/) {
        print "functions = " fn
        node_functions_set = 1
        next
    }

    if (in_node && line ~ /^[[:space:]]*phone_functions[[:space:]]*=/) {
        print "phone_functions = " fn
        node_phone_set = 1
        next
    }

    if (in_node && line ~ /^[[:space:]]*link_functions[[:space:]]*=/) {
        print "link_functions = " fn
        node_link_set = 1
        next
    }

    if (in_node && line ~ /^\[/) {
        emit_node_overrides()
        in_node = 0
    }

    print line
}

END {
    if (in_node) {
        emit_node_overrides()
    }
}
' "$stage1" > "$stage2"

# Apply metadata to the staged file first; only replace rpt.conf if that succeeds
# so a chmod/chown failure leaves the original untouched.
chmod "$rpt_mode" "$stage2"
chown "$rpt_uid:$rpt_gid" "$stage2"
mv "$stage2" "$rpt"
trap - EXIT
rm -f "$stage1"

echo "Updated $rpt for node $node (functions, phone_functions, link_functions)."
echo "Reload Asterisk when ready: sudo asterisk -rx \"rpt reload\""

exit 0

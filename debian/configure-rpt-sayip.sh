#!/bin/sh
# Wire SayIP into ASL3 rpt.conf for a node number:
#   - ensure #tryinclude loads custom/rpt/*.conf BEFORE tables that inherit it
#   - ensure [functions-NODE] inherits functions-sayip
#   - set functions / phone_functions / link_functions on [NODE]
#     (IAX phone-mode DTMF uses phone_functions, not functions)
#   - optional --unwire NODE removes the exact functions-sayip parent token
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
    # Strip only the exact functions-sayip inheritance token (POSIX awk).
    awk -v fn="$fn" '
    BEGIN { fn_re = "^\\[" fn "\\]" }

    function strip_comment(s,    p) {
        p = index(s, ";")
        if (p > 0) return substr(s, 1, p - 1)
        return s
    }

    function get_comment(s,    p) {
        p = index(s, ";")
        if (p > 0) return substr(s, p)
        return ""
    }

    function get_parents(s,    op, cp) {
        op = index(s, "(")
        cp = index(s, ")")
        if (op < 1 || cp <= op) return ""
        return substr(s, op + 1, cp - op - 1)
    }

    function get_header(s,    op) {
        op = index(s, "(")
        if (op < 1) {
            gsub(/[[:space:]]+$/, "", s)
            return s
        }
        s = substr(s, 1, op - 1)
        gsub(/[[:space:]]+$/, "", s)
        return s
    }

    function remove_exact_parent(list, token,    n, i, parts, out, p, c) {
        n = split(list, parts, ",")
        out = ""
        c = 0
        for (i = 1; i <= n; i++) {
            p = parts[i]
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", p)
            if (p == "" || p == token) continue
            if (c++) out = out ","
            out = out p
        }
        return out
    }

    {
        line = $0
        if (line ~ fn_re && index(strip_comment(line), "(") > 0) {
            body = strip_comment(line)
            comment = get_comment(line)
            parents = remove_exact_parent(get_parents(body), "functions-sayip")
            header = get_header(body)
            if (parents == "") {
                line = header
            } else {
                line = header "(" parents ")"
            }
            if (comment != "") {
                line = line " " comment
                sub(/[[:space:]]+;/, " ;", line)
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

# Discover the nodes current functions= target so a newly created
# [functions-NODE] table can inherit that table (preserving custom commands).
current_functions="$(awk -v node="$node" '
BEGIN { node_re = "^\\[" node "\\]"; in_node = 0 }
{
    line = $0
    sub(/;.*$/, "", line)
    if (line ~ node_re) { in_node = 1; next }
    if (in_node && line ~ /^\[/) exit
    if (in_node && line ~ /^[[:space:]]*functions[[:space:]]*=/) {
        sub(/^[[:space:]]*functions[[:space:]]*=[[:space:]]*/, "", line)
        gsub(/[[:space:]]+$/, "", line)
        print line
        exit
    }
}
' "$rpt")"
if [ -z "$current_functions" ]; then
    current_functions="functions-main"
fi
# Avoid circular inheritance if the node already points at functions-NODE.
if [ "$current_functions" = "$fn" ]; then
    current_functions="functions-main"
fi

# Stage 1: ensure ASL3 custom rpt includes exist before the first table that
# may inherit functions-sayip. An include that appears only after those tables
# does not count.
awk '
BEGIN {
    first_table = 0
    include_rpt_before = 0
    include_glob_before = 0
}
{
    lines[NR] = $0
    if (!first_table && ($0 ~ /^\[functions-[0-9]+\]/ || $0 ~ /^\[[0-9]+\]/)) {
        first_table = NR
    }
    if ($0 ~ /^#tryinclude[[:space:]]+"custom\/rpt\.conf"/) {
        if (!first_table || NR < first_table) include_rpt_before = 1
    }
    if ($0 ~ /^#tryinclude[[:space:]]+"custom\/rpt\/\*\.conf"/) {
        if (!first_table || NR < first_table) include_glob_before = 1
    }
}
END {
    inserted = 0
    for (i = 1; i <= NR; i++) {
        if (!inserted && (lines[i] ~ /^\[functions-[0-9]+\]/ || lines[i] ~ /^\[[0-9]+\]/)) {
            if (!include_rpt_before) print "#tryinclude \"custom/rpt.conf\""
            if (!include_glob_before) print "#tryinclude \"custom/rpt/*.conf\""
            if (!include_rpt_before || !include_glob_before) print ""
            inserted = 1
        }
        print lines[i]
    }
    if (!inserted) {
        if (!include_rpt_before) print "#tryinclude \"custom/rpt.conf\""
        if (!include_glob_before) print "#tryinclude \"custom/rpt/*.conf\""
    }
}
' "$rpt" > "$stage1"

# Stage 2: wire function table + phone/link overrides from staged stage1.
# Load all lines first so we know whether [functions-NODE] already exists and
# avoid emitting a duplicate header before the node stanza.
awk -v node="$node" -v fn="$fn" -v base_fn="$current_functions" '
BEGIN {
    node_re = "^\\[" node "\\]"
    fn_re = "^\\[" fn "\\]"
    fn_stanza_seen = 0
    fn_exists = 0
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

function strip_comment(s,    p) {
    p = index(s, ";")
    if (p > 0) return substr(s, 1, p - 1)
    return s
}

function get_comment(s,    p) {
    p = index(s, ";")
    if (p > 0) return substr(s, p)
    return ""
}

function get_parents(s,    op, cp) {
    op = index(s, "(")
    cp = index(s, ")")
    if (op < 1 || cp <= op) return ""
    return substr(s, op + 1, cp - op - 1)
}

function get_header(s,    op) {
    op = index(s, "(")
    if (op < 1) {
        gsub(/[[:space:]]+$/, "", s)
        return s
    }
    s = substr(s, 1, op - 1)
    gsub(/[[:space:]]+$/, "", s)
    return s
}

function has_exact_parent(list, token,    n, i, parts, p) {
    n = split(list, parts, ",")
    for (i = 1; i <= n; i++) {
        p = parts[i]
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", p)
        if (p == token) return 1
    }
    return 0
}

function print_functions_stanza() {
    # Preserve the nodes prior functions table as a parent so custom
    # commands defined there remain available through inheritance.
    if (base_fn != "" && base_fn != "functions-main" && base_fn != "functions-sayip") {
        print "[" fn "](" base_fn ",functions-sayip)"
    } else {
        print "[" fn "](functions-main,functions-sayip)"
    }
    fn_stanza_seen = 1
}

function close_node_if_open() {
    if (in_node) {
        emit_node_overrides()
        in_node = 0
    }
}

function add_sayip_to_header(line,    body, comment, parents, header) {
    body = strip_comment(line)
    comment = get_comment(line)
    if (index(body, "(") > 0 && index(body, ")") > index(body, "(")) {
        parents = get_parents(body)
        if (!has_exact_parent(parents, "functions-sayip")) {
            if (parents == "") {
                parents = "functions-sayip"
            } else {
                parents = parents ",functions-sayip"
            }
        }
        header = get_header(body)
        line = header "(" parents ")"
        if (comment != "") {
            line = line " " comment
            sub(/[[:space:]]+;/, " ;", line)
        }
        return line
    }
    # No inheritance list: emit a full SayIP-aware header instead.
    print_functions_stanza()
    return ""
}

# First pass: remember whether [functions-NODE] exists anywhere.
{
    lines[NR] = $0
    if ($0 ~ fn_re) fn_exists = 1
}
END {
    for (i = 1; i <= NR; i++) {
        line = lines[i]

        # Close an open node stanza before any new section header.
        if (in_node && line ~ /^\[/) {
            close_node_if_open()
        }

        if (line ~ fn_re) {
            fn_stanza_seen = 1
            updated = add_sayip_to_header(line)
            if (updated != "") print updated
            continue
        }

        if (line ~ node_re) {
            if (!fn_stanza_seen && !fn_exists) {
                print_functions_stanza()
            }
            in_node = 1
            node_functions_set = 0
            node_phone_set = 0
            node_link_set = 0
            print line
            continue
        }

        if (in_node && line ~ /^[[:space:]]*functions[[:space:]]*=/) {
            print "functions = " fn
            node_functions_set = 1
            continue
        }

        if (in_node && line ~ /^[[:space:]]*phone_functions[[:space:]]*=/) {
            print "phone_functions = " fn
            node_phone_set = 1
            continue
        }

        if (in_node && line ~ /^[[:space:]]*link_functions[[:space:]]*=/) {
            print "link_functions = " fn
            node_link_set = 1
            continue
        }

        print line
    }

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
echo "Reload Asterisk when ready: sudo asterisk -rx \"module reload app_rpt.so\""

exit 0

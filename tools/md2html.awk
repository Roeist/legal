# md2html.awk — the tiny Markdown subset used by store-listing/privacy-policy.md
#
# Emits an HTML *fragment* (no <html>/<head>); build.sh wraps it in the page skeleton.
# Deliberately supports only what the policies actually use, so there are no surprises:
#
#   # H1 / ## H2      headings
#   _line_            a whole line in underscores -> <p class="meta"> (the "Last updated" line)
#   - item            bullet list, with 2-space-indented continuation lines
#   | a | b |         table with a |---|---| separator row
#   **bold**  `code`  [text](url)     inline
#   blank-separated   paragraphs (soft-wrapped lines are joined)
#
# Emphasis with _underscores_ is honoured ONLY for a whole line. Doing it inline would
# corrupt identifiers like `screen_opened`, which appear all over these policies.
#
# POSIX awk only (no gensub) so this runs under gawk, mawk and BSD awk alike.

function esc(s) {
    gsub(/&/, "\\&amp;", s)
    gsub(/</, "\\&lt;", s)
    gsub(/>/, "\\&gt;", s)
    return s
}

# Inline markup. Order matters: escape first, then code spans (so their contents are
# never re-scanned for bold), then bold, then links.
function inline(s,   out, pre, mid) {
    s = esc(s)

    # `code`
    out = ""
    while (match(s, /`[^`]+`/)) {
        pre = substr(s, 1, RSTART - 1)
        mid = substr(s, RSTART + 1, RLENGTH - 2)
        out = out pre "<code>" mid "</code>"
        s = substr(s, RSTART + RLENGTH)
    }
    s = out s

    # **bold**
    out = ""
    while (match(s, /\*\*[^*]+\*\*/)) {
        pre = substr(s, 1, RSTART - 1)
        mid = substr(s, RSTART + 2, RLENGTH - 4)
        out = out pre "<strong>" mid "</strong>"
        s = substr(s, RSTART + RLENGTH)
    }
    s = out s

    # [text](url)
    out = ""
    while (match(s, /\[[^]]+\]\([^)]+\)/)) {
        pre = substr(s, 1, RSTART - 1)
        mid = substr(s, RSTART, RLENGTH)
        out = out pre linkify(mid)
        s = substr(s, RSTART + RLENGTH)
    }
    s = out s

    return s
}

function linkify(m,   p, text, url) {
    p = index(m, "](")
    text = substr(m, 2, p - 2)
    url = substr(m, p + 2, length(m) - p - 2)
    return "<a href=\"" url "\">" text "</a>"
}

function trim(s) {
    sub(/^[ \t]+/, "", s)
    sub(/[ \t]+$/, "", s)
    return s
}

# ---- block flushing -------------------------------------------------------

function flush_para() {
    if (para != "") {
        # A whole line wrapped in underscores is the "Last updated" meta line.
        if (para ~ /^_.*_$/) {
            print "<p class=\"meta\">" inline(substr(para, 2, length(para) - 2)) "</p>"
        } else {
            print "<p>" inline(para) "</p>"
        }
        para = ""
    }
}

function flush_list() {
    if (in_list) {
        print "<li>" inline(item) "</li>"
        print "</ul>"
        in_list = 0
        item = ""
    }
}

function flush_table() {
    if (in_table) {
        if (in_tbody) print "</tbody>"
        print "</table></div>"
        in_table = 0
        in_tbody = 0
        ncols = 0
    }
}

function flush_all() {
    flush_para()
    flush_list()
    flush_table()
}

BEGIN {
    para = ""; item = ""
    in_list = 0; in_table = 0; in_tbody = 0; ncols = 0
}

# ---- headings -------------------------------------------------------------

/^# / {
    flush_all()
    print "<h1>" inline(substr($0, 3)) "</h1>"
    next
}

/^## / {
    flush_all()
    print "<h2>" inline(substr($0, 4)) "</h2>"
    next
}

/^### / {
    flush_all()
    print "<h3>" inline(substr($0, 5)) "</h3>"
    next
}

# ---- tables ---------------------------------------------------------------

/^[ \t]*\|/ {
    flush_para()
    flush_list()

    line = trim($0)

    # |---|---| separator: switch from thead to tbody
    if (line ~ /^\|[ :|-]+\|$/) {
        if (in_table) {
            print "</thead>"
            print "<tbody>"
            in_tbody = 1
        }
        next
    }

    if (!in_table) {
        print "<div class=\"tw\"><table>"
        print "<thead>"
        in_table = 1
        in_tbody = 0
        ncols = 0
    }

    # Strip the leading and trailing pipe, then split on the remaining pipes.
    sub(/^\|/, "", line)
    sub(/\|$/, "", line)
    n = split(line, cells, "|")

    print "<tr>"
    for (i = 1; i <= n; i++) {
        c = trim(cells[i])
        if (!in_tbody) {
            headers[i] = c            # remembered for the mobile data-label
            if (i > ncols) ncols = i
            print "<th>" inline(c) "</th>"
        } else {
            # data-label drives the stacked card layout on narrow screens.
            print "<td data-label=\"" esc(headers[i]) "\">" inline(c) "</td>"
        }
    }
    print "</tr>"
    next
}

# ---- lists ----------------------------------------------------------------

/^- / {
    flush_para()
    flush_table()
    if (in_list) {
        print "<li>" inline(item) "</li>"
    } else {
        print "<ul>"
        in_list = 1
    }
    item = substr($0, 3)
    next
}

# Indented continuation of the current bullet (the policies soft-wrap at ~100 cols).
in_list && /^[ \t]+[^ \t]/ {
    item = item " " trim($0)
    next
}

# ---- blank lines and paragraphs -------------------------------------------

/^[ \t]*$/ {
    flush_all()
    next
}

{
    flush_table()
    if (in_list) {
        # A non-indented line right after a list ends it and starts a paragraph.
        flush_list()
    }
    if (para == "") para = trim($0)
    else para = para " " trim($0)
}

END {
    flush_all()
}

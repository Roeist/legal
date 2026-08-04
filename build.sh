#!/usr/bin/env bash
#
# build.sh — regenerate the privacy-policy site from the app repos' Markdown.
#
# The Markdown in each app's store-listing/privacy-policy.md is the SINGLE SOURCE OF TRUTH.
# Never hand-edit the generated .html files: edit the Markdown and re-run this script.
#
#   ./build.sh
#
# Requires only bash + awk (no Node, no Ruby, no Jekyll, no network).
# Regenerated pages are written next to this script, ready to commit and push.

set -euo pipefail

cd "$(dirname "$0")"

# Where the app repos live, relative to this directory.
APPS_ROOT="${APPS_ROOT:-..}"

# The public base URL of the published site. Used only for the <link rel="canonical">
# and the footer; change it here if the repo or account is renamed.
BASE_URL="${BASE_URL:-https://roeist.github.io/legal}"

CONTACT_EMAIL="roei2mberg@gmail.com"

# slug|Directory name (under $APPS_ROOT)|Display name
APPS=(
  "sleepcycleai|SleepCycleAI|SleepCycleAI"
  "moodtrack|MoodTrack|MoodTrack"
  "cycleluna|CycleLuna|CycleLuna"
  "linguasprint|LinguaSprint|LinguaSprint"
  "flashbrain|FlashBrain|FlashBrain"
)

# ---------------------------------------------------------------------------
# Shared stylesheet. Inlined into every page: no external CSS, JS, fonts or CDN,
# so the page renders with no network beyond the HTML itself.
# ---------------------------------------------------------------------------
read -r -d '' STYLE <<'CSS' || true
:root{
  --bg:#ffffff; --fg:#1a1c1e; --muted:#5b6166; --rule:#e2e5e8;
  --accent:#0b5cab; --code-bg:#f2f4f6; --card:#f8f9fa;
}
@media (prefers-color-scheme:dark){
  :root{
    --bg:#14161a; --fg:#e6e8ea; --muted:#a3abb2; --rule:#2b3036;
    --accent:#79b3f5; --code-bg:#1e2229; --card:#191d22;
  }
}
*{box-sizing:border-box}
html{-webkit-text-size-adjust:100%}
body{
  margin:0 auto; padding:1.5rem 1.15rem 4rem; max-width:44rem;
  background:var(--bg); color:var(--fg);
  font:400 17px/1.65 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,"Helvetica Neue",Arial,sans-serif;
}
h1{font-size:1.6rem; line-height:1.25; margin:0 0 .35rem}
h2{font-size:1.2rem; line-height:1.3; margin:2.2rem 0 .6rem; padding-top:1rem; border-top:1px solid var(--rule)}
h3{font-size:1.05rem; margin:1.6rem 0 .4rem}
p{margin:0 0 1rem}
ul{margin:0 0 1rem; padding-left:1.25rem}
li{margin:0 0 .5rem}
a{color:var(--accent)}
strong{font-weight:600}
.meta{color:var(--muted); font-size:.95rem; margin:0 0 1.75rem}
code{
  font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,"Liberation Mono",monospace;
  font-size:.86em; background:var(--code-bg); padding:.12em .35em; border-radius:4px;
  /* permission names such as BIND_GET_INSTALL_REFERRER_SERVICE are long: never let
     one of them push the page into horizontal scrolling on a phone. */
  overflow-wrap:anywhere; word-break:break-word;
}
.tw{overflow-x:auto; margin:0 0 1.25rem}
table{border-collapse:collapse; width:100%; font-size:.95rem}
th,td{text-align:left; vertical-align:top; padding:.6rem .7rem; border-bottom:1px solid var(--rule)}
th{font-weight:600; color:var(--muted); font-size:.82rem; letter-spacing:.02em; text-transform:uppercase}
nav{margin:0 0 1.5rem; font-size:.92rem}
footer{margin-top:3rem; padding-top:1rem; border-top:1px solid var(--rule); color:var(--muted); font-size:.9rem}
footer a{color:var(--accent)}
.apps{list-style:none; padding:0; margin:1.5rem 0 0}
.apps li{margin:0 0 .75rem}
.apps a{
  display:block; padding:.9rem 1rem; background:var(--card);
  border:1px solid var(--rule); border-radius:10px;
  text-decoration:none; color:var(--fg); font-weight:600;
}
.apps a span{display:block; font-weight:400; font-size:.9rem; color:var(--muted); margin-top:.15rem}
/* Phones: a 3-column table is unreadable, so stack each row as a labelled card. */
@media (max-width:640px){
  body{padding:1.25rem 1rem 3rem; font-size:16px}
  h1{font-size:1.4rem}
  table,tbody,tr,td{display:block; width:100%}
  thead{position:absolute; left:-9999px}
  tr{margin:0 0 1rem; padding:.25rem .9rem .5rem; background:var(--card);
     border:1px solid var(--rule); border-radius:10px}
  td{border:0; padding:.55rem 0}
  td+td{border-top:1px solid var(--rule)}
  td::before{
    content:attr(data-label); display:block; margin-bottom:.2rem;
    font-size:.72rem; font-weight:600; letter-spacing:.04em;
    text-transform:uppercase; color:var(--muted);
  }
}
CSS

# page <slug> <title> <canonical-path> <body-file>
page() {
  local out="$1" title="$2" canonical="$3" bodyfile="$4" nav="$5"
  {
    printf '<!doctype html>\n<html lang="en">\n<head>\n'
    printf '<meta charset="utf-8">\n'
    printf '<meta name="viewport" content="width=device-width, initial-scale=1">\n'
    printf '<title>%s</title>\n' "$title"
    printf '<link rel="canonical" href="%s">\n' "$canonical"
    printf '<meta name="robots" content="index,follow">\n'
    printf '<style>\n%s\n</style>\n' "$STYLE"
    printf '</head>\n<body>\n'
    [ -n "$nav" ] && printf '<nav>%s</nav>\n' "$nav"
    printf '<main>\n'
    cat "$bodyfile"
    printf '</main>\n'
    printf '<footer>\n'
    printf '<p>Contact: <a href="mailto:%s">%s</a></p>\n' "$CONTACT_EMAIL" "$CONTACT_EMAIL"
    printf '<p>This page is generated from the app&rsquo;s privacy-policy source file. Do not edit it by hand.</p>\n'
    printf '</footer>\n</body>\n</html>\n'
  } >"$out"
}

# ---------------------------------------------------------------------------
# Per-app pages
# ---------------------------------------------------------------------------
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

index_items=""

for entry in "${APPS[@]}"; do
  IFS='|' read -r slug dir name <<<"$entry"
  src="$APPS_ROOT/$dir/store-listing/privacy-policy.md"

  if [ ! -f "$src" ]; then
    echo "ERROR: missing $src" >&2
    exit 1
  fi

  mkdir -p "$slug"
  awk -f tools/md2html.awk "$src" >"$tmp"

  page "$slug/index.html" \
       "$name — Privacy Policy" \
       "$BASE_URL/$slug/" \
       "$tmp" \
       '<a href="../">All apps</a>'

  updated="$(sed -n 's/^_Last updated: \(.*\)_$/\1/p' "$src" | head -n1)"
  index_items="$index_items      <li><a href=\"$slug/\">$name<span>Privacy policy — updated $updated</span></a></li>
"
  echo "built  $slug/index.html   (from $src)"
done

# ---------------------------------------------------------------------------
# Landing page
# ---------------------------------------------------------------------------
{
  printf '<h1>Privacy policies</h1>\n'
  printf '<p class="meta">Privacy policies for the apps listed below.</p>\n'
  printf '<p>Each app keeps your content on your device. Each policy states exactly what the app does send, to which company, and why &mdash; including where your data is stored and whether it is encrypted.</p>\n'
  printf '<ul class="apps">\n%s</ul>\n' "$index_items"
} >"$tmp"

page "index.html" \
     "Privacy policies" \
     "$BASE_URL/" \
     "$tmp" \
     ""

echo "built  index.html"

# Tell GitHub Pages to serve the files verbatim (no Jekyll processing).
touch .nojekyll

echo
echo "Done. Review, then commit and push; GitHub Pages will publish within a minute or two."

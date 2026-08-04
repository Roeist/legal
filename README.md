# Privacy policy site

A self-contained static site hosting the privacy policy for five Play Store apps.
Google Play requires a **publicly reachable** privacy policy URL per app; a Markdown file
inside a private repo does not satisfy that. This publishes them.

No build system, no dependencies, no network calls from the page. Every generated page
inlines its own CSS — no external stylesheet, script, font or CDN — so it renders on a
phone with nothing else to fetch.

```
.legal/
├── build.sh              regenerate everything (bash + awk only)
├── tools/md2html.awk     the Markdown -> HTML converter
├── index.html            landing page, links to all five  (generated)
├── sleepcycleai/index.html                                (generated)
├── moodtrack/index.html                                   (generated)
├── cycleluna/index.html                                   (generated)
├── linguasprint/index.html                                (generated)
├── flashbrain/index.html                                  (generated)
└── .nojekyll           tells Pages to serve files verbatim
```

## The Markdown is the source of truth

Each page is generated from that app's policy file in its own repo:

    ../<AppName>/store-listing/privacy-policy.md

**Never hand-edit the generated `.html`.** It is overwritten on the next build.

## Publish (one time)

1. Create a **PUBLIC** repository named `legal` on GitHub under the `Roeist` account.
   It must be public — GitHub Pages on a private repo requires a paid plan, and Play
   needs the URL reachable while signed out.

   ```sh
   gh repo create Roeist/legal --public
   ```

2. Push the contents of this directory to it:

   ```sh
   cd /c/Compose_Projects/.legal
   git init -b main
   git add .
   git commit -m "Privacy policies for SleepCycleAI, MoodTrack, CycleLuna, LinguaSprint, FlashBrain"
   git remote add origin https://github.com/Roeist/legal.git
   git push -u origin main
   ```

3. Enable Pages: repo **Settings -> Pages -> Build and deployment**.
   Source: **Deploy from a branch**. Branch: **main**, folder: **/ (root)**. Save.

4. Wait about a minute, then confirm each URL loads **in a private/incognito window**
   (that proves it is reachable while signed out, which is what Play checks).

## The URLs

| App | Privacy policy URL |
|---|---|
| SleepCycleAI | `https://roeist.github.io/legal/sleepcycleai/` |
| MoodTrack    | `https://roeist.github.io/legal/moodtrack/` |
| CycleLuna    | `https://roeist.github.io/legal/cycleluna/` |
| LinguaSprint | `https://roeist.github.io/legal/linguasprint/` |
| FlashBrain   | `https://roeist.github.io/legal/flashbrain/` |

Landing page: `https://roeist.github.io/legal/`

Paste the per-app URL into Play Console at
**Policy -> App content -> Privacy policy**, and into the Data safety form where it asks
for a privacy policy URL. The same URL is already wired into each app's Settings screen
(string `privacy_policy_url`).

If the repo or account is ever renamed, change `BASE_URL` at the top of `build.sh`,
re-run it, and update the `privacy_policy_url` string in each app.

## Regenerate after editing a policy

```sh
cd /c/Compose_Projects/.legal
./build.sh
git add -A && git commit -m "Update privacy policies" && git push
```

Pages redeploys automatically on push. `build.sh` fails loudly if any source Markdown is
missing, so a renamed or deleted policy cannot silently produce a stale page.

To preview locally before pushing, just open `index.html` in a browser — the pages are
plain files and need no server.

## Supported Markdown

`build.sh` calls `tools/md2html.awk`, which handles exactly the subset these policies use:
`#`/`##`/`###` headings, `- ` bullets (including 2-space-indented continuation lines),
`| … |` tables with a `|---|` separator row, `**bold**`, `` `code` ``, `[text](url)`, and
a whole line wrapped in `_underscores_` (used for the "Last updated" line).

Two deliberate limits, so that edits to the Markdown do not silently render wrong:

- **Single-asterisk `*italic*` is not supported** — use `**bold**`. A stray `*word*`
  renders literally, which is visible on inspection rather than silently dropped.
- Underscore emphasis works only for a *whole line*. Inline `_..._` would corrupt the
  identifiers these policies are full of (`screen_opened`, `ACCESS_ADSERVICES_AD_ID`).

After any policy edit, skim the generated page. A quick check for markup that failed to
convert:

```sh
grep -o '\*\*\|`\||---|' */index.html index.html   # expect no output
```

## Contact address

Every page shows **roei2mberg@gmail.com** as the contact, because that is the only address
that exists today. Before these apps have real users, move this to a dedicated support
address (e.g. `support@…` on a domain you control) and re-run `build.sh`: a personal
Gmail address on a public store listing is permanently scrapeable, cannot be handed to
anyone else, and gives users no way to reach "the company" rather than a person.

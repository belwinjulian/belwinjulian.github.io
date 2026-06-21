#!/usr/bin/env bash
# push-lessons.sh — Regenerate index.html and push lessons to GitHub Pages.
# Called automatically by Claude Code's PostToolUse hook after lesson writes.
# Also safe to run manually: bash push-lessons.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── 1. Hook filter: exit early if this isn't a lesson write ──────────────────

HOOK_INPUT=""
if [ -p /dev/stdin ]; then
  HOOK_INPUT=$(cat)
fi

if [ -n "$HOOK_INPUT" ]; then
  FILE_PATH=$(echo "$HOOK_INPUT" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get('tool_input', {}).get('file_path', ''), end='')
except Exception:
    pass
" 2>/dev/null || true)

  if [[ "$FILE_PATH" != */lessons/* ]]; then
    exit 0
  fi
fi

cd "$REPO_ROOT"

# ── 2. Regenerate index.html ─────────────────────────────────────────────────

generate_index() {
  local sections=""

  for subject_dir_raw in */; do
    local subject_dir="${subject_dir_raw%/}"
    [ -d "$subject_dir/lessons" ] || continue

    local subject_title=""
    if [ -f "$subject_dir/MISSION.md" ]; then
      subject_title=$(grep -m1 '^# ' "$subject_dir/MISSION.md" | sed 's/^# //')
    fi
    if [ -z "$subject_title" ]; then
      subject_title=$(echo "$subject_dir" | tr '-' ' ')
    fi

    local lesson_links=""
    local lesson_count=0
    for html_file in "$subject_dir/lessons"/[0-9]*.html; do
      [ -f "$html_file" ] || continue
      local filename
      filename=$(basename "$html_file")
      local title
      title=$(grep -m1 '<title>' "$html_file" \
              | sed 's/.*<title>//;s/<\/title>.*//' \
              | sed 's/^ *//;s/ *$//')
      [ -z "$title" ] && title="$filename"
      lesson_links="${lesson_links}
      <li><a href=\"${subject_dir}/lessons/${filename}\">${title}</a></li>"
      lesson_count=$((lesson_count + 1))
    done

    [ "$lesson_count" -eq 0 ] && continue

    local plural="lessons"
    [ "$lesson_count" -eq 1 ] && plural="lesson"

    sections="${sections}
  <section class=\"subject\">
    <h2>${subject_title}</h2>
    <p class=\"meta\">${lesson_count} ${plural}</p>
    <ol>${lesson_links}
    </ol>
  </section>"
  done

  cat > index.html <<HTMLEOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>BRAIN — Learning Library</title>
  <style>
    :root {
      --orange: #FF3621;
      --navy:   #1B3A4B;
      --ink:    #1a1a1a;
      --muted:  #5a5a5a;
      --border: #d8d8d0;
      --font-ui: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
      --font-body: Georgia, 'Times New Roman', serif;
    }
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: var(--font-body);
      font-size: 18px;
      line-height: 1.65;
      color: var(--ink);
      background: #fff;
    }
    .site-header {
      background: var(--navy);
      color: #fff;
      padding: 2.5rem 1.5rem;
      border-bottom: 4px solid var(--orange);
    }
    .site-header h1 {
      font-family: var(--font-ui);
      font-size: 2rem;
      font-weight: 700;
    }
    .site-header p {
      font-family: var(--font-ui);
      font-size: 0.88rem;
      margin-top: 0.3rem;
      opacity: 0.65;
    }
    main {
      max-width: 680px;
      margin: 0 auto;
      padding: 3rem 1.5rem 6rem;
    }
    .subject {
      margin-bottom: 3rem;
      padding-bottom: 2.5rem;
      border-bottom: 1px solid var(--border);
    }
    .subject:last-child { border-bottom: none; }
    .subject h2 {
      font-family: var(--font-ui);
      font-size: 1.25rem;
      font-weight: 700;
      color: var(--navy);
      margin-bottom: 0.25rem;
    }
    .meta {
      font-family: var(--font-ui);
      font-size: 0.75rem;
      text-transform: uppercase;
      letter-spacing: 0.07em;
      color: var(--muted);
      margin-bottom: 1rem;
    }
    ol { padding-left: 1.5rem; }
    li { margin-bottom: 0.45rem; }
    a {
      font-family: var(--font-ui);
      font-size: 0.95rem;
      color: var(--navy);
      text-decoration: none;
    }
    a:hover { color: var(--orange); text-decoration: underline; }
    footer {
      max-width: 680px;
      margin: 0 auto;
      padding: 1rem 1.5rem 2rem;
      font-family: var(--font-ui);
      font-size: 0.75rem;
      color: var(--muted);
      border-top: 1px solid var(--border);
    }
  </style>
</head>
<body>
<header class="site-header">
  <h1>BRAIN</h1>
  <p>Personal learning library · auto-published from Claude Code teach sessions</p>
</header>
<main>
${sections}
</main>
<footer>
  Auto-generated · <a href="https://github.com/belwinjulian/belwinjulian.github.io">Source</a>
</footer>
</body>
</html>
HTMLEOF
}

generate_index
echo "[push-lessons] index.html regenerated."

# ── 3. Stage, commit, push ───────────────────────────────────────────────────

git add index.html .nojekyll 2>/dev/null || true

find . -not -path './.git/*' \( \
  -path '*/lessons/*.html' \
  -o -path '*/assets/*.css' \
  -o -path '*/assets/*.js' \
\) -print0 | xargs -0 git add 2>/dev/null || true

find . -not -path './.git/*' \( \
  -name 'MISSION.md' \
  -o -name 'RESOURCES.md' \
\) -print0 | xargs -0 git add 2>/dev/null || true

if git diff --cached --quiet; then
  echo "[push-lessons] Nothing new to push — GitHub Pages is already current."
  exit 0
fi

TIMESTAMP=$(date '+%Y-%m-%d %H:%M')
LESSON_FILE=$(basename "${FILE_PATH:-updated}")

git commit -m "lessons: auto-push ${LESSON_FILE} (${TIMESTAMP})"
git push origin main

echo ""
echo "[push-lessons] Done. Live at: https://belwinjulian.github.io/"

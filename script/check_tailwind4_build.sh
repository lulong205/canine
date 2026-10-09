#!/usr/bin/env bash
# Builds the CSS and checks the Tailwind 4 + DaisyUI 5 output (B1 upgrade).
set -euo pipefail
cd "$(dirname "$0")/.."
yarn -s build:css >/dev/null
css=app/assets/builds/tailwind.css
fail=0
for needle in '--color-primary:oklch(60.67' '.border-none' '.text-cyan-400' '.btn' '.form-control' '.label-text' '.label-text-alt' '.card-bordered' '.tabs-bordered' '.tabs-boxed'; do
  grep -qF -- "$needle" "$css" || { echo "missing: $needle"; fail=1; }
done
# The Tailwind 3 config set text-xs/sm/base as bare sizes, so they inherited the parent's line-height
for size in xs sm base; do
  grep -qF -- ".text-$size{font-size:var(--text-$size)}" "$css" || { echo "text-$size sets a line-height"; fail=1; }
done
# main.css's body font must sit in a layer, so font-sans on the logged-out layout's <body> still wins
ruby -e 'c = File.read(ARGV[0]); i = c.index("body{font-family:var(--body-font-family)") or abort("missing: body font rule")
  exit(c[0, i].count("{") > c[0, i].count("}") ? 0 : 1)' "$css" || { echo "body font rule is unlayered"; fail=1; }
for banned in 'oklch(var(--' '--fallback-'; do
  if grep -qF -- "$banned" "$css"; then echo "still present: $banned"; fail=1; fi
done
exit $fail

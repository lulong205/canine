#!/usr/bin/env bash
# Builds the CSS and checks the Tailwind 4 + DaisyUI 5 output (B1 upgrade).
set -euo pipefail
cd "$(dirname "$0")/.."
yarn -s build:css >/dev/null
css=app/assets/builds/tailwind.css
fail=0
for needle in '--color-primary:oklch(60.67' '.border-none' '.text-cyan-400' '.btn'; do
  grep -qF -- "$needle" "$css" || { echo "missing: $needle"; fail=1; }
done
for banned in 'oklch(var(--' '--fallback-'; do
  if grep -qF -- "$banned" "$css"; then echo "still present: $banned"; fail=1; fi
done
exit $fail

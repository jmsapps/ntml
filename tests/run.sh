#!/usr/bin/env bash
# Full NTML test suite: builds everything, then runs direct-Node and real-browser tiers.
#
#   ./tests/run.sh
#
# Exits non-zero if ANY build or tier fails. Compilation is a hard gate: if a single
# example or test module fails to compile, the run stops before executing anything.
# Running on stale build output silently tests old code -- that has bitten this project
# twice -- so a broken build must never fall through to a green suite.
#
# Build output goes outside the repository by default. NTML_TEST_OUT overrides it.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

OUT="${NTML_TEST_OUT:-/tmp/ntml-tests}"
case "$OUT" in
  /tmp/*) ;;
  *) echo "NTML_TEST_OUT must be under /tmp to safely recreate it: $OUT"; exit 2 ;;
esac
rm -rf "$OUT"
EX_OUT="$OUT/examples"
mkdir -p "$EX_OUT"

# Test modules. Browser coverage is a Playwright module, not a Nim test module.
LOGIC_MODULES=(tsmoke tlogic)
BROWSER_MODULES=(browser_cleanup)

say() { printf '\n\033[1m%s\033[0m\n' "$*"; }

# ---------------------------------------------------------------- prerequisites
if [ ! -d "$ROOT/tests/node_modules/playwright" ]; then
  say "Installing Playwright (test dependency, first run only)"
  npm install --prefix tests --silent || { echo "Playwright install failed"; exit 1; }
fi

# chromium | firefox | webkit -- all three verified. Override with NTML_BROWSER.
BROWSER="${NTML_BROWSER:-chromium}"
if ! node -e "const pw=require('./tests/node_modules/playwright'); require('fs').accessSync(pw['$BROWSER'].executablePath())" 2>/dev/null; then
  say "Installing Playwright $BROWSER (test browser, first run only)"
  npx --prefix tests playwright install "$BROWSER" || { echo "Playwright $BROWSER install failed"; exit 1; }
fi
export NTML_BROWSER="$BROWSER"

# ---------------------------------------------------------------- build (hard gate)
say "Building examples"
build_failed=0
for f in examples/*.nim; do
  name="$(basename "$f" .nim)"
  if ! err="$(nim js --hints:off --warnings:off --out:"$EX_OUT/$name.js" "$f" 2>&1)"; then
    echo "  COMPILE FAIL  $f"
    echo "$err" | grep -iE "error" | head -3 | sed 's/^/      /'
    build_failed=1
  fi
done

say "Building test modules"
for m in "${LOGIC_MODULES[@]}" "${BROWSER_MODULES[@]}"; do
  if ! err="$(nim js --hints:off --out:"$OUT/$m.js" "tests/$m.nim" 2>&1)"; then
    echo "  COMPILE FAIL  tests/$m.nim"
    echo "$err" | grep -iE "error" | head -3 | sed 's/^/      /'
    build_failed=1
  fi
done

if [ "$build_failed" -ne 0 ]; then
  say "BUILD FAILED — not running any tests (stale output would give a false pass)"
  exit 1
fi

# ---------------------------------------------------------------- run
export NTML_EXAMPLE_SRC="$ROOT/examples"

overall=0
declare -a results=()

run_tier() {
  local label="$1"; shift
  say "$label"
  if "$@"; then
    results+=("PASS  $label")
  else
    results+=("FAIL  $label")
    overall=1
  fi
}

for m in "${LOGIC_MODULES[@]}"; do
  run_tier "$m (bare node)" node "$OUT/$m.js"
done

run_tier "browser examples and cleanup (Playwright $BROWSER)" node tests/browser-tests.js

# ---------------------------------------------------------------- summary
say "Summary"
for r in "${results[@]}"; do echo "  $r"; done

if [ "$overall" -ne 0 ]; then
  say "SUITE FAILED"
else
  say "All tiers passed"
fi
exit "$overall"

version       = "0.5.5"
author        = "jmsapps"
license       = "MIT"
description   = "A reactive, client-side single-page application (SPA) renderer written in Nim."
packageName   = "ntml"
srcDir        = "src"

# The suite is JS-only (this package targets `nim js`), so it cannot use Nimble's default
# C-backend test runner. Delegate to the shell runner, which builds every example and test
# module, aborts on any compile error, and runs all three tiers headless.
task test, "build and run the full test suite (logic + Playwright Chromium tiers)":
  exec "./tests/run.sh"

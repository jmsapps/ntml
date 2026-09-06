## Shared test-runner core for NTML's JS-backend test suite.
##
## Why this exists: on the JS backend a failing `unittest` exits 0, because
## `setProgramResult` is unavailable there (the compiler warns about it). A suite that
## cannot report failure is worse than no suite, so this module counts failures itself
## and sets the process exit code explicitly.
##
## Test files should `import harness` (which re-exports `unittest`) and call `finish()`
## as their final statement.

import unittest
export unittest

# Node-only interop, deliberately NOT in src/lib/shims.nim: `elements.nim` re-exports
# shims into the package's public API, and `process.exitCode` is meaningless in a
# browser. Test-harness interop stays in tests/.
proc setExitCode(code: int) {.importjs: "process.exitCode = #".}

type FailCounter = ref object of OutputFormatter
  failures: int

method testEnded*(f: FailCounter, res: TestResult) =
  if res.status == TestStatus.FAILED:
    inc f.failures

var failCounter = FailCounter(failures: 0)

# The default console formatter is only installed when no formatter has been registered,
# so adding ours would silently suppress all human-readable output. Add it back first.
addOutputFormatter(newConsoleOutputFormatter())
addOutputFormatter(failCounter)

proc failureCount*(): int = failCounter.failures

proc finish*() =
  ## Call as the last statement of every test file. Uses `process.exitCode` rather than
  ## `process.exit()` (which truncates piped stdout) or Nim's `quit()` (which compiles to
  ## an `exit()` call that does not exist in Node).
  setExitCode(if failCounter.failures > 0: 1 else: 0)

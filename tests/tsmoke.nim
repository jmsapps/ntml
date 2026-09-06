## Harness self-test. Kept permanently: it proves the runner's plumbing still works.
##
## This file is all-passing by design. The runner's *failure* path is verified as a
## step in the test command's own verification (flip an assertion, confirm a non-zero
## exit), not by committing a failing test.

import harness

suite "harness plumbing":
  test "assertions run":
    check 1 + 1 == 2

  test "failure counter is readable":
    # Deliberately order-independent: asserting == 0 here would cascade a second,
    # confusing failure whenever an earlier test in this file fails.
    check failureCount() >= 0

finish()

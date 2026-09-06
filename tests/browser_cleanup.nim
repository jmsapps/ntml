## Browser-executed regression probe. It runs against the listener instrumentation that
## tests/browser-runner.js installs before this compiled artifact executes.
##
## Every check is wrapped so a failure reports WHICH assertion broke. A bare `doAssert`
## here only ever surfaced as "probe did not complete", which tells you nothing when the
## gate fires.

import ../src/ntml

proc listenerCount(el: Node, evType: cstring): int {.importjs: "__ntmlListenerCount(#, #)".}
proc totalListeners(): int {.importjs: "__ntmlTotalListeners()".}
proc typeInto(el: Node, value: cstring) {.importjs: "((e, v) => { e.value = v; e.dispatchEvent(new Event('input', {bubbles: true})); })(#, #)".}
proc markPassed() {.importjs: "(window.__ntmlCleanupProbePassed = true)".}
proc recordFailure(message: cstring) {.importjs: "(window.__ntmlCleanupProbeError = #)".}

var failures = 0
var firstFailure = ""

proc check(label: string, condition: bool) =
  if not condition:
    # Keep the FIRST failure: later ones are usually knock-on effects of it.
    if failures == 0: firstFailure = label
    inc failures

proc run() =
  # bindValue: attached, then released, and inert afterwards.
  let value = signal("before")
  let valueInput = input(value = value)
  discard jsAppendChild(document.body, valueInput)
  check("bindValue should attach an input listener", listenerCount(valueInput, cstring"input") == 1)
  check("bindValue should attach a change listener", listenerCount(valueInput, cstring"change") == 1)
  cleanupSubtree(valueInput)
  check("cleanup should remove the input listener", listenerCount(valueInput, cstring"input") == 0)
  check("cleanup should remove the change listener", listenerCount(valueInput, cstring"change") == 0)
  typeInto(valueInput, cstring"ignored")
  check("typing after cleanup must not mutate the signal", value.get() == "before")

  # bindChecked: the handler is an inline closure upstream, so it needs hoisting to be
  # removable at all.
  let checked = signal(true)
  let checkedInput = input(`type` = "checkbox", checked = checked)
  discard jsAppendChild(document.body, checkedInput)
  check("bindChecked should attach a change listener", listenerCount(checkedInput, cstring"change") == 1)
  cleanupSubtree(checkedInput)
  check("cleanup should remove bindChecked's change listener", listenerCount(checkedInput, cstring"change") == 0)

  # Churn: repeated mount/unmount must not accumulate. Compared as a delta because the
  # tally is page-wide and earlier nodes above are intentionally left attached-then-freed.
  let baseline = totalListeners()
  for i in 0 .. 4:
    let el = input(value = signal("churn"))
    discard jsAppendChild(document.body, el)
    cleanupSubtree(el)
    discard jsRemoveChild(document.body, el)
  check("mount/unmount churn must not accumulate listeners", totalListeners() == baseline)

try:
  run()
  if failures == 0:
    markPassed()
  else:
    recordFailure(cstring(firstFailure & "  [" & $failures & " assertion(s) failed]"))
except:
  recordFailure(cstring("probe raised: " & getCurrentExceptionMsg()))

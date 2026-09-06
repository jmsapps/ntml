## Logic tier: the reactive core and the router, with no DOM whatsoever.
##
## Runs under bare Node -- no browser harness wrapper:
##   nim js --out:<out>.js tests/tlogic.nim && node <out>.js
##
## Keeping this tier DOM-free is deliberate: it is fast and has no dependency surface.
## If a case here needs a document, it belongs in the DOM tier instead.

import harness
import tables
import ../src/ntml

suite "signals":
  test "get returns the initial value":
    let s = signal(41)
    check s.get() == 41

  test "set updates the value":
    let s = signal(0)
    s.set(7)
    check s.get() == 7

  test "set notifies subscribers":
    let s = signal(0)
    var seen: seq[int] = @[]
    let stop = s.sub(proc (v: int) = seen.add(v), fire = false)
    s.set(1)
    s.set(2)
    stop()
    check seen == @[1, 2]

  test "sub fires immediately by default":
    let s = signal(99)
    var seen: seq[int] = @[]
    let stop = s.sub(proc (v: int) = seen.add(v))
    check seen == @[99]
    stop()

  test "sub with fire = false does not fire on subscribe":
    let s = signal(99)
    var seen: seq[int] = @[]
    let stop = s.sub(proc (v: int) = seen.add(v), fire = false)
    check seen.len == 0
    stop()

  test "unsub stops delivery":
    let s = signal(0)
    var count = 0
    let stop = s.sub(proc (v: int) = count += 1, fire = false)
    s.set(1)
    stop()
    s.set(2)
    check count == 1

  test "setting an unchanged value does not notify":
    # `set` compares against the current value before assigning, so re-setting the
    # same value is a no-op for subscribers.
    let s = signal(5)
    var count = 0
    let stop = s.sub(proc (v: int) = count += 1, fire = false)
    s.set(5)
    check count == 0
    s.set(6)
    check count == 1
    stop()

suite "derived":
  test "seeds from the source's current value":
    let src = signal(2)
    let d = derived(src, proc (x: int): string = $(x * 3))
    check d.get() == "6"

  test "recomputes when the source changes":
    let src = signal(2)
    let d = derived(src, proc (x: int): string = $(x * 3))
    src.set(4)
    check d.get() == "12"

  test "can change type across the derivation":
    let src = signal(3)
    let isOdd = derived(src, proc (x: int): bool = x mod 2 == 1)
    check isOdd.get()
    src.set(4)
    check not isOdd.get()

  test "derived notifies its own subscribers":
    let src = signal(1)
    let doubled = derived(src, proc (x: int): int = x * 2)
    var seen: seq[int] = @[]
    let stop = doubled.sub(proc (v: int) = seen.add(v), fire = false)
    src.set(5)
    stop()
    check seen == @[10]

suite "effect":
  test "no-dep void effect runs once at setup":
    var runs = 0
    discard effect(proc () = inc runs)
    check runs == 1

  test "no-dep Unsub effect runs once at setup":
    var runs = 0
    discard effect(proc (): Unsub =
      inc runs
      result = proc () = discard
    )
    check runs == 1

  test "one-dep effect runs at setup and on change":
    let a = signal(0)
    var runs = 0
    let stop = effect(proc (): Unsub =
      inc runs
      result = proc () = discard
    , [a])
    check runs == 1
    a.set(1)
    check runs == 2
    stop()

  test "one-dep effect does not re-run for an unchanged value":
    let a = signal(0)
    var runs = 0
    let stop = effect(proc (): Unsub =
      inc runs
      result = proc () = discard
    , [a])
    a.set(1)
    a.set(1)
    check runs == 2
    stop()

  test "a multi-dep effect runs once PER DEP at setup":
    # Current behaviour, deliberately pinned: `effect` subscribes every dep with
    # `sub(..., fire = true)`, so setup cost scales with the number of deps. This is
    # surprising and worth knowing about; it is not "fixed" here.
    let b1 = signal(0)
    let b2 = signal(0)
    var runs = 0
    let stop = effect(proc (): Unsub =
      inc runs
      result = proc () = discard
    , [b1, b2])
    check runs == 2
    b1.set(5)
    check runs == 3
    stop()

  test "the previous cleanup runs before each re-run":
    let c = signal(0)
    var runs = 0
    var cleanups = 0
    let stop = effect(proc (): Unsub =
      inc runs
      result = proc () = inc cleanups
    , [c])
    check runs == 1
    check cleanups == 0
    c.set(1)
    check runs == 2
    check cleanups == 1
    stop()

  test "disposing an effect runs its final cleanup":
    let c = signal(0)
    var cleanups = 0
    let stop = effect(proc (): Unsub =
      result = proc () = inc cleanups
    , [c])
    stop()
    check cleanups == 1

  test "a disposed effect stops reacting":
    let c = signal(0)
    var runs = 0
    let stop = effect(proc (): Unsub =
      inc runs
      result = proc () = discard
    , [c])
    stop()
    c.set(1)
    check runs == 1

suite "matchRoute":
  # Helper: run a match and hand back both the result and the captured params.
  proc match(pattern, path: string): (bool, Table[string, string]) =
    var params = initTable[string, string]()
    let ok = matchRoute(pattern, path, params)
    (ok, params)

  test "exact paths match":
    let (ok, _) = match("/a/b", "/a/b")
    check ok

  test "a literal mismatch fails":
    let (ok, _) = match("/x", "/y")
    check not ok

  test "a shorter path than the pattern fails":
    let (ok, _) = match("/a/b", "/a")
    check not ok

  test "a longer path than the pattern fails":
    let (ok, _) = match("/a", "/a/b")
    check not ok

  test "a named parameter is captured":
    let (ok, params) = match("/users/:id", "/users/42")
    check ok
    check params["id"] == "42"

  test "multiple named parameters are captured":
    let (ok, params) = match("/u/:a/p/:b", "/u/1/p/2")
    check ok
    check params["a"] == "1"
    check params["b"] == "2"

  test "a wildcard matches a deep remainder":
    let (ok, _) = match("/files/*", "/files/x/y/z")
    check ok

  test "a wildcard also matches the bare prefix":
    # `/files/*` returns true as soon as it reaches `*`, without requiring anything
    # after it -- so the prefix alone matches.
    let (ok, _) = match("/files/*", "/files")
    check ok

  test "a wildcard captures no remainder":
    let (ok, params) = match("/files/*", "/files/x/y")
    check ok
    check params.len == 0

  test "a bare wildcard matches anything":
    let (ok, _) = match("*", "/any/deep/path")
    check ok

  test "a trailing slash is tolerated":
    let (ok, _) = match("/a/b", "/a/b/")
    check ok

finish()

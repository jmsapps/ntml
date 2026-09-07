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

proc observers[T](s: Signal[T]): int =
  s.signalSubs.len + s.signalDependents.len

suite "computed lifetime":

  test "creating computeds without an observer attaches nothing":
    let src = signal(0)
    for i in 0 ..< 100:
      discard derived(src, proc (x: int): int = x * 2)
    check observers(src) == 0

  test "a computed detaches from its source when its last observer goes":
    let src = signal(0)
    let d = derived(src, proc (x: int): int = x * 2)
    let stop = d.sub(proc (v: int) = discard, fire = false)
    check observers(src) == 1
    stop()
    check observers(src) == 0

  test "a detached computed stops doing work":
    let src = signal(0)
    var runs = 0
    let d = derived(src, proc (x: int): int =
      inc(runs)
      x * 2
    )
    let stop = d.sub(proc (v: int) = discard, fire = false)
    src.set(1)
    let before = runs
    stop()
    src.set(2)
    check runs == before

  test "detaching cascades up a chain":
    let a = signal(1)
    let b = derived(a, proc (x: int): int = x + 1)
    let c = derived(b, proc (x: int): int = x * 2)
    let stop = c.sub(proc (v: int) = discard, fire = false)
    check observers(a) == 1
    check observers(b) == 1
    stop()
    check observers(a) == 0
    check observers(b) == 0

  test "operator overloads detach with their consumer":
    let x = signal(1)
    let y = signal(2)
    let eq = x == y
    let stop = eq.sub(proc (v: bool) = discard, fire = false)
    check observers(x) == 1
    check observers(y) == 1
    stop()
    check observers(x) == 0
    check observers(y) == 0

  test "get on a detached computed still returns a fresh value":
    let src = signal(1)
    let d = derived(src, proc (x: int): int = x * 10)
    let stop = d.sub(proc (v: int) = discard, fire = false)
    stop()
    src.set(7)
    check d.get() == 70

  test "reattaching resyncs a computed that went stale while detached":
    let src = signal(1)
    let d = derived(src, proc (x: int): int = x * 10)
    let stop = d.sub(proc (v: int) = discard, fire = false)
    stop()
    src.set(5)
    var seen: seq[int] = @[]
    let stop2 = d.sub(proc (v: int) = seen.add(v))
    check seen == @[50]
    stop2()

  test "a reattached computed is reactive again":
    let src = signal(1)
    let d = derived(src, proc (x: int): int = x * 10)
    let first = d.sub(proc (v: int) = discard, fire = false)
    first()
    var seen: seq[int] = @[]
    let second = d.sub(proc (v: int) = seen.add(v), fire = false)
    src.set(3)
    second()
    check seen == @[30]

  test "attach/detach churn does not accumulate subscribers":
    let src = signal(0)
    let d = derived(src, proc (x: int): int = x * 2)
    for i in 0 ..< 20:
      let stop = d.sub(proc (v: int) = discard, fire = false)
      src.set(i)
      stop()
    check observers(src) == 0
    check observers(d) == 0

suite "glitch-free propagation":

  test "a tautology never emits a value it cannot hold":
    let a = signal(1)
    let b = a == 1
    let c = a != 1
    let d = b or c
    var seen: seq[bool] = @[]
    let stop = d.sub(proc (v: bool) = seen.add(v), fire = false)
    check d.get()
    a.set(2)
    stop()
    check not seen.contains(false)
    check d.get()

  test "a settled value reaches a consumer once per source change":
    let a = signal(1)
    let b = derived(a, proc (x: int): int = x + 1)
    let c = derived(a, proc (x: int): int = x * 10)
    let d = combine2(b, c, proc (x, y: int): int = x + y)
    var seen: seq[int] = @[]
    let stop = d.sub(proc (v: int) = seen.add(v), fire = false)
    a.set(2)
    stop()
    check seen == @[23]

  test "chain width does not multiply emissions":
    for width in [2, 4, 8]:
      let src = signal(0)
      var legs: seq[Signal[string]] = @[]
      for i in 0 ..< width:
        legs.add(derived(src, proc (x: int): string = $x))
      var acc = legs[0]
      for i in 1 ..< width:
        acc = acc & legs[i]
      var emissions = 0
      let stop = acc.sub((proc (v: string) = inc(emissions)), fire = false)
      src.set(1)
      stop()
      check emissions == 1

  test "an unchanged computed does not emit at all":
    let a = signal(1)
    let parity = derived(a, proc (x: int): bool = x mod 2 == 1)
    var seen: seq[bool] = @[]
    let stop = parity.sub(proc (v: bool) = seen.add(v), fire = false)
    a.set(3)
    stop()
    check seen.len == 0

  test "a diamond consumer never observes an inconsistent pair":
    let a = signal(0)
    let doubled = derived(a, proc (x: int): int = x * 2)
    let quadrupled = derived(a, proc (x: int): int = x * 4)
    var bad = 0
    let stop = combine2(doubled, quadrupled, proc (x, y: int): int = y - 2 * x).sub(
      proc (v: int) = (if v != 0: inc(bad)), fire = false)
    for i in 1 .. 5:
      a.set(i)
    stop()
    check bad == 0

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

type NilProbe = ref object
  name: string

suite "nil comparison with the signal operator overloads in scope":
  test "a ref type compares to nil in both directions":
    let present = NilProbe(name: "x")
    var absent: NilProbe
    check present != nil
    check not (present == nil)
    check absent == nil
    check not (absent != nil)

  test "a cstring compares to nil":
    var absent: cstring
    check absent == nil
    check not (absent != nil)

  test "a signal compares to nil":
    var absent: Signal[int]
    check absent == nil
    check signal(1) != nil

suite "signal comparison overloads still return signals":
  test "signal on the left compares to a value":
    let s = signal("a")
    check (s == "a").get()
    check (s != "b").get()

  test "value on the left compares to a signal":
    let s = signal("a")
    check ("a" == s).get()
    check ("b" != s).get()

  test "two signals compare":
    let a = signal(3)
    let b = signal(3)
    let c = signal(4)
    check (a == b).get()
    check (a != c).get()

  test "a signal comparison stays reactive":
    let s = signal(1)
    let isTwo = s == 2
    check not isTwo.get()
    s.set(2)
    check isTwo.get()

finish()

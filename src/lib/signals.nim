when defined(js):
  from dom import Node
  import tables

  import
    shims,
    types

  var
    cleanupRegistry: Table[system.int, seq[Unsub]] = initTable[int, seq[Unsub]]()
    nodeDisposers*: seq[NodeDisposer] = @[]
    nextId = 0
    cleanupHook*: proc (u: Unsub) = nil
    currentKeyedResult*: ptr KeyRenderResult = nil
    notifyQueue: seq[proc ()] = @[]
    propagationDepth = 0
    draining = false


  proc nodeKey(n: Node): int
    {.importjs: """
    (function(x) {
      if (x.__nid === undefined) {
        if (window.__nid === undefined) window.__nid = 0;
        window.__nid = window.__nid + 1;
        x.__nid = window.__nid;
      }
      return x.__nid;
    })(#)
    """.}


  proc registerCleanup*(el: Node, fn: Unsub) =
    let k = nodeKey(el)
    if k notin cleanupRegistry:
      cleanupRegistry[k] = @[]

    cleanupRegistry[k].add(fn)

    if cleanupHook != nil and fn != nil:
      cleanupHook(fn)


  proc setCleanupHook*(h: proc (u: Unsub)) =
    cleanupHook = h


  proc clearCleanupHook*() =
    cleanupHook = nil


  proc runCleanups*(el: Node) =
    let k = nodeKey(el)

    if k in cleanupRegistry:
      for fn in cleanupRegistry[k]:
        if fn != nil:
          fn()

      cleanupRegistry.del(k)

    for hook in nodeDisposers:
      if hook != nil:
        hook(el)


  proc cleanupSubtree*(el: Node) =
    if el == nil:
      return

    runCleanups(el)

    var child = jsGetNodeProp(el, cstring("firstChild"))
    while child != nil:
      let next = jsGetNodeProp(child, cstring("nextSibling"))
      cleanupSubtree(child)
      child = next


  proc debugId(): string =
    inc(nextId)

    return "signal_" & $nextId


  proc get*[T](src: Signal[T]): T =
    if (
      src.signalRecompute != nil and not src.signalComputing and
      (src.signalDirty or src.signalDisconnect == nil)
    ):
      src.signalComputing = true
      try:
        src.signalRecompute()
      finally:
        src.signalComputing = false
        src.signalDirty = false

    src.signalValue


  proc enqueueNotify[T](src: Signal[T]) =
    if src.signalQueued or src.signalSubs.len == 0 or src.signalNotify == nil:
      return

    src.signalQueued = true
    notifyQueue.add(src.signalNotify)


  proc markDependentsDirty[T](src: Signal[T]) =
    let snapshot = src.signalDependents

    for mark in snapshot:
      if mark != nil:
        mark()


  proc drainNotifications() =
    if draining:
      return

    draining = true
    var i = 0

    while i < notifyQueue.len:
      let notify = notifyQueue[i]
      inc i

      if notify != nil:
        notify()

    notifyQueue.setLen(0)
    draining = false


  proc signal*[T](initial: T): Signal[T] =
    new(result)
    result.signalId = debugId()
    result.signalValue = initial
    result.signalSubs = @[]
    result.signalWriteThrough = nil
    result.signalInternalUpdate = false
    result.signalConnect = nil
    result.signalDisconnect = nil
    result.signalRecompute = nil
    result.signalDependents = @[]
    result.signalDirty = false
    result.signalQueued = false
    result.signalComputing = false

    let self = result

    self.signalNotify = proc () =
      if self.signalRecompute == nil:
        self.signalQueued = false
        let snapshot = self.signalSubs

        for f in snapshot:
          f(self.signalValue)

      else:
        let previous = self.signalValue
        let settled = self.get()
        self.signalQueued = false

        if settled != previous:
          let snapshot = self.signalSubs

          for f in snapshot:
            f(settled)


  proc set*[T](src: Signal[T], newValue: T) =
    if (not src.signalInternalUpdate) and src.signalWriteThrough != nil:
      src.signalWriteThrough(newValue)
      return

    if newValue == src.signalValue:
      return

    src.signalValue = newValue

    inc propagationDepth
    enqueueNotify(src)
    markDependentsDirty(src)
    dec propagationDepth

    if propagationDepth == 0:
      drainNotifications()


  proc setInternal*[T](src: Signal[T], newValue: T) =
    src.signalInternalUpdate = true
    try:
      src.set(newValue)
    finally:
      src.signalInternalUpdate = false


  proc ensureConnected[T](src: Signal[T]) =
    if src.signalConnect != nil and src.signalDisconnect == nil:
      src.signalDisconnect = src.signalConnect()
      discard src.get()


  proc releaseIfUnobserved[T](src: Signal[T]) =
    if src.signalSubs.len == 0 and src.signalDependents.len == 0 and
       src.signalDisconnect != nil:
      let disconnect = src.signalDisconnect
      src.signalDisconnect = nil
      disconnect()


  proc addDependent*[T](src: Signal[T], mark: proc ()): Unsub =
    ensureConnected(src)
    src.signalDependents.add(mark)

    result = proc() =
      var i: int = -1

      for idx, g in src.signalDependents:
        if g == mark:
          i = idx
          break

      if i >= 0:
        src.signalDependents.delete(i)
        releaseIfUnobserved(src)


  proc sub*[T](src: Signal[T], fn: Subscriber[T], fire = true): Unsub =
    ensureConnected(src)
    src.signalSubs.add(fn)

    if fire:
      fn(src.get())

    result = proc() =
      var i: int = -1

      for idx, g in src.signalSubs:
        if g == fn:
          i = idx
          break

      if i >= 0:
        src.signalSubs.delete(i)
        releaseIfUnobserved(src)


  proc asComputed*[T](
    res: Signal[T];
    recompute: proc ();
    connect: proc (mark: proc ()): Unsub
  ): Signal[T] =
    res.signalRecompute = recompute

    let mark = proc () =
      if res.signalDirty:
        return

      res.signalDirty = true
      enqueueNotify(res)
      markDependentsDirty(res)

    res.signalConnect = proc (): Unsub =
      res.signalDirty = true
      connect(mark)

    res


  proc derived*[A, B](src: Signal[A], fn: proc(a: A): B): Signal[B] =
    let res = signal[B](fn(src.get()))

    asComputed(
      res,
      proc () = res.setInternal(fn(src.get())),
      proc (mark: proc ()): Unsub = src.addDependent(mark)
    )


  template track*(src, expr: untyped): untyped =
    derived(src, proc(_: typeof(src.signalValue)): auto = expr)


  proc effect*[T](fn: proc(): Unsub, deps: openArray[Signal[T]]): Unsub =
    var cleanup: Unsub

    proc run() =
      if cleanup != nil: cleanup()
      cleanup = fn()

    var unsubs: seq[Unsub] = @[]

    for d in deps:
      unsubs.add(d.sub(proc (v: type(d.signalValue)) = run()))

    result = proc() =
      for u in unsubs:
        if u != nil: u()

      if cleanup != nil: cleanup()



  proc effect*[T](fn: proc(): void, deps: openArray[Signal[T]]): Unsub =
    var cleanup: Unsub

    proc run() =
      if cleanup != nil: cleanup()
      fn()
      cleanup = nil

    var unsubs: seq[Unsub] = @[]

    for d in deps:
      unsubs.add(d.sub(proc (v: type(d.signalValue)) = run()))

    result = proc() =
      for u in unsubs:
        if u != nil: u()

      if cleanup != nil:
        cleanup()



  proc effect*(fn: proc(): Unsub): Unsub =
    var cleanup = fn()

    result = proc() =
      if cleanup != nil:
        cleanup()


  proc effect*(fn: proc(): void): Unsub =
    fn()
    result = proc() = discard


  proc addNodeDisposer*(hook: NodeDisposer) =
    nodeDisposers.add(hook)

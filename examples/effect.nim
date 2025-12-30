when isMainModule and defined(js):
  import ../src/ntml

  proc jsSetTimeout(cb: proc (); delay: int): int {.importjs: "window.setTimeout(#,#)".}
  proc jsClearTimeout(id: int) {.importjs: "window.clearTimeout(#)".}

  styled AppShell = d:
    """
      min-height: 100vh;
      margin: 0;
      background: radial-gradient(circle at top, #d2e9ff, #f8fbff);
      font-family: "Inter", system-ui, -apple-system, BlinkMacSystemFont, sans-serif;
      color: #0f172a;
      padding: 2rem 1rem 3rem;
      display: flex;
      justify-content: center;
    """

  styled DemoPanel = d:
    """
      width: min(760px, 100%);
      background: white;
      border-radius: 24px;
      padding: 2rem;
      box-shadow: 0 25px 65px rgba(15, 23, 42, 0.15);
      display: flex;
      flex-direction: column;
      gap: 1.5rem;
    """

  styled SectionHeading = h1:
    """margin: 0; font-size: 2.4rem;"""

  styled PanelSection = d:
    """
      border: 1px solid #e2e8f0;
      border-radius: 18px;
      padding: 1.25rem;
      display: flex;
      flex-direction: column;
      gap: 0.75rem;
    """

  styled PanelTitle = h2:
    """margin: 0; font-size: 1.15rem; color: #0f172a;"""

  styled PanelNote = p:
    """margin: 0; color: #475569; line-height: 1.6;"""

  styled ControlRow = d:
    """display: flex; gap: 0.6rem; flex-wrap: wrap;"""

  styled PrimaryButton = button:
    """padding: 0.65rem 1.3rem; border-radius: 12px; border: none; background: #2563eb; color: white; font-weight: 600; cursor: pointer;"""

  styled NeutralButton = PrimaryButton:
    """background: #0f172a;"""

  styled LogList = ul:
    """list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: 0.35rem;"""

  styled LogItem = li:
    """padding: 0.35rem 0.5rem; background: #f1f5f9; border-radius: 8px; font-family: "SFMono-Regular", monospace; font-size: 0.85rem;"""

  proc App(): Node =
    let counter = signal(0)
    let autoStart = signal(false)
    let delayed = signal("idle")
    let delayToken = signal(0)

    var logEntries = @["Effects demo ready"]
    let logs = signal(logEntries)

    proc log(msg: string) =
      var xs = logs.get()
      xs.add(msg)
      if xs.len > 10:
        xs = xs[xs.len - 10 ..< xs.len]
      logs.set(xs)

    proc increment() =
      counter.set(counter.get() + 1)

    discard effect(proc (): Unsub =
      log("[counter effect] value=" & $counter.get())
      result = proc () = discard
    , [counter])

    discard effect(proc (): Unsub =
      if not autoStart.get():
        log("[auto runner] stopped")
        return proc () = discard
      log("[auto runner] started")
      var cancelled = false
      var timerId: int
      proc tick() =
        if cancelled or not autoStart.get(): return
        increment()
        timerId = jsSetTimeout(tick, 700)
      timerId = jsSetTimeout(tick, 700)
      result = proc () =
        cancelled = true
        jsClearTimeout(timerId)
        log("[auto runner] cleanup")
    , [autoStart])

    discard effect(proc (): Unsub =
      let token = delayToken.get()
      if token == 0:
        return proc () = discard
      delayed.set("waiting (" & $token & ")")
      let t = jsSetTimeout(proc () = delayed.set("finished (" & $token & ")"), 1200)
      result = proc () =
        jsClearTimeout(t)
        delayed.set("cancelled (" & $token & ")")
    , [delayToken])

    AppShell:
      DemoPanel:
        SectionHeading: "Effects Cookbook"

        PanelSection:
          PanelTitle: "Manual effect"
          PanelNote: "Click the button to increment; the effect logs each change."
          ControlRow:
            PrimaryButton(`type`="button", onClick = proc (e: Event) = increment()):
              "Increment"
          p:
            "Counter value: "; counter

        PanelSection:
          PanelTitle: "Auto runner"
          PanelNote: "Demonstrates effect cleanup by toggling an auto increment loop."
          ControlRow:
            NeutralButton(`type`="button", onClick = proc (e: Event) = autoStart.set(not autoStart.get())):
              if autoStart:
                "Stop auto"
              else:
                "Start auto"
          p:
            "Auto runner: "; if autoStart: "running" else: "stopped"

        PanelSection:
          PanelTitle: "Delayed update"
          PanelNote: "Schedules an update and cancels it if you trigger again before it fires."
          ControlRow:
            NeutralButton(`type`="button", onClick = proc (e: Event) = delayToken.set(delayToken.get() + 1)):
              "Trigger delayed update"
          p:
            "Delayed status: "; delayed

        PanelSection:
          PanelTitle: "Effect logs"
          PanelNote: "Shows the latest effect messages (max 10)."
          LogList:
            for entry in logs:
              LogItem: entry

  let component: Node = App()
  discard jsAppendChild(document.body, component)

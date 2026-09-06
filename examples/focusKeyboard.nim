when isMainModule and defined(js):
  import ../src/ntml

  # No local `importjs` here: the event and focus interop this example needs lives in
  # src/lib/shims.nim (the `# Events` and `# Focus` groups) and reaches us through the
  # re-export chain.

  styled Page = d:
    """
      min-height: 100vh;
      padding: 3rem clamp(1.5rem, 4vw, 4rem);
      background: #0f172a;
      color: #e2e8f0;
      font-family: "IBM Plex Sans", "Segoe UI", sans-serif;
    """

  styled Card = d:
    """
      max-width: 36rem;
      padding: 1.75rem 2rem;
      background: #1e293b;
      border: 1px solid #334155;
      border-radius: 14px;
    """

  styled Title = h1:
    """
      margin: 0 0 0.35rem;
      font-size: 1.5rem;
    """

  styled Copy = p:
    """
      margin: 0 0 1.5rem;
      color: #94a3b8;
      font-size: 0.95rem;
      line-height: 1.5;
    """

  styled Toolbar = d:
    """
      display: flex;
      gap: 0.6rem;
      margin-bottom: 1.25rem;
    """

  styled Chip = button:
    """
      padding: 0.5rem 0.9rem;
      border: 1px solid #475569;
      border-radius: 999px;
      background: #0f172a;
      color: #e2e8f0;
      cursor: pointer;
      font-size: 0.9rem;
    """

  styled Field = input:
    """
      width: 100%;
      padding: 0.6rem 0.75rem;
      margin-bottom: 1rem;
      border: 1px solid #475569;
      border-radius: 8px;
      background: #0f172a;
      color: #e2e8f0;
      font-size: 0.95rem;
    """

  styled Action = button:
    """
      padding: 0.55rem 1rem;
      border: none;
      border-radius: 8px;
      background: #38bdf8;
      color: #0f172a;
      font-weight: 600;
      cursor: pointer;
    """

  styled Status = p:
    """
      margin: 1.25rem 0 0;
      padding: 0.6rem 0.8rem;
      border-radius: 8px;
      background: #0f172a;
      border: 1px solid #334155;
      font-size: 0.9rem;
    """

  let focused = signal("nothing")
  let chipIds = @["chip-one", "chip-two", "chip-three"]

  proc focusById(id: string) =
    let el = jsQuerySelector(cstring("#" & id))
    # `isNil` rather than `el != nil`: ntml's signal operator overloads make `!=` against
    # nil ambiguous for a Node (system.== for ref T vs the Signal comparison overload).
    if not el.isNil:
      jsFocus(el)

  proc chip(id, label: string): Node =
    Chip(
      `type` = "button",
      id = id,
      onFocus = proc (e: Event) = focused.set(label),
      onKeyDown = proc (e: Event) =
        let key = jsEventKey(e)
        let idx = chipIds.find(id)
        case key
        of "ArrowRight":
          jsPreventDefault(e)
          if idx + 1 < chipIds.len: focusById(chipIds[idx + 1])
        of "ArrowLeft":
          jsPreventDefault(e)
          if idx - 1 >= 0: focusById(chipIds[idx - 1])
        else: discard
    ):
      label

  let component: Node =
    Page:
      Card:
        Title: "Focus and keyboard handling"
        Copy:
          """Left/Right arrows move focus along the chip row. The button below moves focus
          programmatically. The status line tracks whichever control currently holds
          focus, driven by focus events rather than by clicks."""

        Toolbar:
          chip("chip-one", "Chip one")
          chip("chip-two", "Chip two")
          chip("chip-three", "Chip three")

        Field(
          id = "notes",
          `type` = "text",
          placeholder = "A focusable text field",
          onFocus = proc (e: Event) = focused.set("Notes field")
        )

        Action(
          `type` = "button",
          id = "focus-notes",
          onClick = proc (e: Event) = focusById("notes")
        ):
          "Focus the notes field"

        Status(id = "focus-status"):
          "Focused: "; focused

  discard jsAppendChild(document.body, component)

  # Focus must be set AFTER the tree is attached to the document -- calling focus() on a
  # detached node silently does nothing. There is no onMount hook yet (root ROADMAP.md
  # lists it under v0.8.0), so an effect created here, post-append, is the mechanism.
  discard effect(proc () = focusById("chip-one"))

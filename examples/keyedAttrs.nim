when isMainModule and defined(js):
  import ../src/ntml

  type Row = object
    id: int
    n: int

  styled Page = d:
    """
      min-height: 100vh;
      padding: 3rem clamp(1.5rem, 4vw, 4rem);
      color: #0f172a;
      background: #f8fafc;
      font-family: "IBM Plex Sans", "Segoe UI", sans-serif;
    """

  styled Card = d:
    """
      max-width: 720px;
      margin: 0 auto;
      padding: clamp(1.5rem, 3vw, 2.5rem);
      border-radius: 24px;
      background: rgba(255, 255, 255, 0.94);
      box-shadow: 0 26px 70px rgba(15, 23, 42, 0.12);
    """

  proc App(): Node =
    let rows = signal(@[Row(id: 1, n: 0), Row(id: 2, n: 0)])
    let tone = signal("calm")   # independent of the row value

    proc bump() =
      var next: seq[Row] = @[]
      for r in rows.get(): next.add(Row(id: r.id, n: r.n + 1))
      rows.set(next)

    Page:
      Card:
        h1: "Keyed attribute patching"
        p: "Stable keys, changing values. Attributes must follow the patch."

        d(id = "list"):
          for r in rows:
            d(key = r.id, id = "row-" & $r.id, `data-n` = $r.n, `data-tone` = tone):
              span(`data-inner` = $r.n): "row " & $r.id & " = " & $r.n

        button(id = "bump", `type` = "button", onClick = proc (e: Event) = bump()):
          "Bump values"
        button(
          id = "tone",
          `type` = "button",
          onClick = proc (e: Event) = tone.set(if tone.get() == "calm": "loud" else: "calm")
        ):
          "Toggle tone"

  render(App())

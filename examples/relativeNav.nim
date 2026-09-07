when isMainModule and defined(js):
  import ../src/ntml

  styled Page = d:
    """
      min-height: 100vh;
      padding: 3.5rem clamp(1.5rem, 4vw, 4.5rem);
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

  styled Row = d:
    """
      display: flex;
      gap: 0.75rem;
      margin: 1.25rem 0 0 0;
    """

  styled Btn = button:
    """
      padding: 0.6rem 1.1rem;
      border-radius: 999px;
      border: 1px solid rgba(15, 23, 42, 0.14);
      background: #0ea5e9;
      color: white;
      font-weight: 600;
      cursor: pointer;
    """

  styled Code = code:
    """
      display: block;
      margin-top: 0.5rem;
      padding: 0.5rem 0.75rem;
      border-radius: 10px;
      background: rgba(15, 23, 42, 0.06);
      font-family: "IBM Plex Mono", monospace;
    """

  proc App(): Node =
    let router = router()

    Page:
      Card:
        h1: "Relative navigation"
        p:
          "`+/seg` descends one segment, `-/seg` replaces the last one. Both resolve "
          "against the current path only -- any query string or hash is dropped, so a "
          "stale `?tab=` cannot leak into the new route."

        p: "location:"
        Code(id = "location"): router.location
        p: "path:"
        Code(id = "path"): router.path

        Row:
          Btn(id = "descend", onClick = proc (e: Event) = navigate("+/edit")):
            "Descend +/edit"
          Btn(id = "ascend", onClick = proc (e: Event) = navigate("-/settings")):
            "Ascend -/settings"
          Btn(id = "descend-q", onClick = proc (e: Event) = navigate("+/edit?mode=raw")):
            "Descend +/edit?mode=raw"

  render(App())

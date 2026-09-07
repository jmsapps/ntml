when isMainModule and defined(js):
  import ../src/ntml
  import strutils

  const Base = "/relativeNav/users/1"

  proc segmentsOf(path: string): seq[string] =
    result = @[]
    for part in path.strip(chars = {'/'}).split('/'):
      if part.len > 0:
        result.add(part)

  proc parentOf(path: string): string =
    var parts = segmentsOf(path)
    if parts.len > 0:
      discard parts.pop()
    if parts.len == 0: "" else: "/" & parts.join("/")

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
      max-width: 760px;
      margin: 0 auto 1.25rem auto;
      padding: clamp(1.25rem, 3vw, 2rem);
      border-radius: 20px;
      background: rgba(255, 255, 255, 0.96);
      box-shadow: 0 20px 55px rgba(15, 23, 42, 0.10);
    """

  styled Lede = p:
    """
      margin: 0 0 1rem 0;
      color: rgba(15, 23, 42, 0.72);
      line-height: 1.65;
    """

  styled Crumbs = d:
    """
      display: flex;
      flex-wrap: wrap;
      align-items: center;
      gap: 0.4rem;
      margin: 0.25rem 0 0.75rem 0;
    """

  styled Crumb = span:
    """
      padding: 0.3rem 0.7rem;
      border-radius: 999px;
      background: rgba(14, 165, 233, 0.14);
      color: #0369a1;
      font-family: "IBM Plex Mono", monospace;
      font-size: 0.85rem;
    """

  styled Slash = span:
    """
      color: rgba(15, 23, 42, 0.35);
    """

  styled Full = code:
    """
      display: block;
      padding: 0.6rem 0.85rem;
      border-radius: 10px;
      background: rgba(15, 23, 42, 0.06);
      font-family: "IBM Plex Mono", monospace;
      font-size: 0.9rem;
      overflow-wrap: anywhere;
    """

  styled Row = d:
    """
      display: flex;
      flex-wrap: wrap;
      gap: 0.75rem;
      margin-top: 1rem;
    """

  styled Action = button:
    """
      flex: 1 1 14rem;
      text-align: left;
      padding: 0.7rem 1rem;
      border-radius: 14px;
      border: 1px solid rgba(15, 23, 42, 0.14);
      background: white;
      cursor: pointer;
      font: inherit;
      line-height: 1.5;
    """

  styled Reset = button:
    """
      padding: 0.55rem 1rem;
      border-radius: 999px;
      border: none;
      background: #0f172a;
      color: white;
      font-weight: 600;
      cursor: pointer;
    """

  styled Call = strong:
    """
      font-family: "IBM Plex Mono", monospace;
      color: #0369a1;
    """

  styled Preview = span:
    """
      display: block;
      font-family: "IBM Plex Mono", monospace;
      font-size: 0.82rem;
      color: rgba(15, 23, 42, 0.6);
      overflow-wrap: anywhere;
    """

  styled Depth = p:
    """
      margin: 0;
      font-size: 0.85rem;
      color: rgba(15, 23, 42, 0.55);
    """

  proc App(): Node =
    let router = router()
    let segments = derived(router.path, segmentsOf)
    let depth = derived(router.path, proc (p: string): int = segmentsOf(p).len)
    let descendTo = derived(router.path, proc (p: string): string = p & "/edit")
    let replaceTo = derived(router.path, proc (p: string): string = parentOf(p) & "/settings")
    let queryTo = derived(router.path, proc (p: string): string = p & "/edit?mode=raw")

    Page:
      Card:
        h1: "Relative navigation"
        Lede:
          Call: "+/seg"
          " appends a segment. "
          Call: "-/seg"
          " replaces the last one. Both resolve against the path alone, so a query "
          "string or hash on the current URL is dropped rather than carried forward."

        Crumbs:
          Slash: "/"
          for seg in segments:
            Crumb: seg
            Slash: "/"

        Full(id = "path"): router.path
        Depth: "depth: "; depth; " — appending is unbounded, so this grows until you reset"

        Row:
          Reset(id = "reset", onClick = proc (e: Event) = navigate(Base, true)):
            "Reset to " & Base

        Row:
          Action(id = "descend", onClick = proc (e: Event) = navigate("+/edit")):
            Call: "navigate(\"+/edit\")"
            Preview: descendTo
          Action(id = "ascend", onClick = proc (e: Event) = navigate("-/settings")):
            Call: "navigate(\"-/settings\")"
            Preview: replaceTo
          Action(id = "descend-q", onClick = proc (e: Event) = navigate("+/edit?mode=raw")):
            Call: "navigate(\"+/edit?mode=raw\")"
            Preview: queryTo

  render(App())

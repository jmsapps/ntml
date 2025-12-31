when isMainModule and defined(js):
  import ../src/ntml
  import strutils
  import tables

  styled Page = d:
    """
      min-height: 100vh;
      padding: 3.5rem clamp(1.5rem, 4vw, 4.5rem);
      color: #0f172a;
      background: radial-gradient(circle at 10% 15%, rgba(14, 116, 144, 0.18), transparent 55%),
                  radial-gradient(circle at 80% 85%, rgba(59, 130, 246, 0.14), transparent 55%),
                  #f8fafc;
      font-family: "IBM Plex Sans", "Segoe UI", sans-serif;
    """

  styled Card = d:
    """
      max-width: 880px;
      margin: 0 auto;
      padding: clamp(1.5rem, 3vw, 2.75rem);
      border-radius: 24px;
      background: rgba(255, 255, 255, 0.92);
      box-shadow: 0 26px 70px rgba(15, 23, 42, 0.12);
      border: 1px solid rgba(148, 163, 184, 0.2);
      backdrop-filter: blur(18px);
    """

  styled Heading = h1:
    """
      margin: 0 0 0.75rem 0;
      font-size: clamp(2rem, 3vw, 2.75rem);
      letter-spacing: -0.03em;
    """

  styled Paragraph = p:
    """
      margin: 0 0 1rem 0;
      color: rgba(15, 23, 42, 0.78);
      line-height: 1.6;
    """

  styled LinkRow = d:
    """
      display: flex;
      flex-wrap: wrap;
      gap: 0.8rem;
      margin: 1rem 0 1.5rem 0;
    """

  styled PillLink = Link:
    """
      padding: 0.45rem 0.9rem;
      border-radius: 999px;
      background: rgba(15, 118, 110, 0.12);
      color: #0f766e;
      text-decoration: none;
      font-weight: 600;
      border: 1px solid rgba(15, 118, 110, 0.2);
    """

  styled Panel = d:
    """
      margin-top: 1rem;
      padding: 1.25rem 1.5rem;
      border-radius: 16px;
      background: rgba(15, 23, 42, 0.04);
      border: 1px solid rgba(148, 163, 184, 0.2);
    """

  styled CodeBlock = pre:
    """
      margin: 0.75rem 0 0 0;
      padding: 0.85rem 1rem;
      border-radius: 12px;
      background: rgba(15, 23, 42, 0.08);
      font-family: "IBM Plex Mono", "SFMono-Regular", Menlo, monospace;
      font-size: 0.9rem;
      white-space: pre-wrap;
    """

  proc paramsToText(params: Table[string, string]): string =
    if params.len == 0:
      return "(no params)"
    var entries: seq[string] = @[]
    for k, v in params:
      entries.add(k & " = " & v)
    entries.join("\n")

  proc RouteOverview(): Node =
    Panel:
      Paragraph:
        "NTML now supports dynamic path segments like /users/:id and wildcards like /files/* ."
      CodeBlock:
        "/users/:id\n/teams/:teamId/members/:memberId\n/files/*"

  proc RouteUser(): Node =
    Panel:
      Paragraph:
        "This route uses a single dynamic segment: /users/:id"

  proc RouteTeamMember(): Node =
    Panel:
      Paragraph:
        "This route matches multiple params: /teams/:teamId/members/:memberId"

  proc RouteFiles(): Node =
    Panel:
      Paragraph:
        "Wildcard route: /files/* (matches any trailing segments)"

  proc App(): Node =
    let router = router()
    let params = routeParams()
    let paramsText = derived(params, proc (p: Table[string, string]): string = paramsToText(p))

    Page:
      Card:
        Heading: "Routing wildcards"
        Paragraph:
          "Use dynamic segments with :param and wildcard segments with *. Query and hash remain available."

        LinkRow:
          PillLink(href = "/routerWildcards"):
            "Overview"
          PillLink(href = "/routerWildcards/users/42"):
            "User 42"
          PillLink(href = "/routerWildcards/teams/alpha/members/7"):
            "Team Member"
          PillLink(href = "/routerWildcards/files/docs/readme"):
            "Files wildcard"
          PillLink(href = "/routerWildcards/users/99?utm_source=demo"):
            "With query"

        Paragraph:
          "Current path: "
        CodeBlock: router.path

        Paragraph:
          "Search: "
        CodeBlock: router.search

        Paragraph:
          "Hash: "
        CodeBlock: router.hash

        Paragraph:
          "Matched params: "
        CodeBlock: paramsText

        Routes(router.location):
          Route(path = "/routerWildcards", component = RouteOverview)
          Route(path = "/routerWildcards/users/:id", component = RouteUser)
          Route(path = "/routerWildcards/teams/:teamId/members/:memberId", component = RouteTeamMember)
          Route(path = "/routerWildcards/files/*", component = RouteFiles)
          Route(path = "*", component = RouteOverview)

  render(App())

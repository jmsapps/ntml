when isMainModule and defined(js):
  import ../src/ntml

  styled Page = d:
    """
      min-height: 100vh;
      padding: 3.5rem clamp(1.5rem, 4vw, 4.5rem);
      color: #0f172a;
      background: radial-gradient(circle at 10% 15%, rgba(37, 99, 235, 0.12), transparent 55%),
                  radial-gradient(circle at 85% 85%, rgba(14, 116, 144, 0.16), transparent 55%),
                  #f8fafc;
      font-family: "IBM Plex Sans", "Segoe UI", sans-serif;
    """

  styled Card = d:
    """
      max-width: 860px;
      margin: 0 auto;
      padding: clamp(1.5rem, 3vw, 2.75rem);
      border-radius: 24px;
      background: rgba(255, 255, 255, 0.9);
      box-shadow: 0 24px 60px rgba(15, 23, 42, 0.12);
      border: 1px solid rgba(148, 163, 184, 0.2);
      backdrop-filter: blur(18px);
    """

  styled Heading = h1:
    """
      margin: 0 0 0.75rem 0;
      font-size: clamp(2rem, 3vw, 2.75rem);
      letter-spacing: -0.03em;
    """

  styled Subheading = p:
    """
      margin: 0 0 2rem 0;
      color: rgba(15, 23, 42, 0.75);
      font-size: 1.05rem;
    """

  styled SectionTitle = h2:
    """
      font-size: 1.05rem;
      margin: 2rem 0 0.75rem 0;
      text-transform: uppercase;
      letter-spacing: 0.12em;
      color: rgba(15, 23, 42, 0.55);
    """

  styled Paragraph = p:
    """
      margin: 0 0 1rem 0;
      color: rgba(15, 23, 42, 0.78);
      line-height: 1.6;
    """

  styled DemoRow = d:
    """
      display: flex;
      flex-wrap: wrap;
      gap: 0.85rem;
      align-items: center;
      margin: 0.75rem 0 1.25rem 0;
    """

  styled StyledLink = Link:
    """
      color: #1d4ed8;
      text-decoration: none;
      font-weight: 600;
      position: relative;
    """

  styled StyledLinkUnderline = Link:
    """
      color: #0f172a;
      text-decoration: none;
      font-weight: 600;
      position: relative;
    """

  styled ChipLink = Link:
    """
      display: inline-flex;
      align-items: center;
      gap: 0.35rem;
      padding: 0.35rem 0.7rem;
      border-radius: 999px;
      background: rgba(37, 99, 235, 0.12);
      color: #1e3a8a;
      text-decoration: none;
      border: 1px solid rgba(37, 99, 235, 0.25);
    """

  styled CodeBadge = d:
    """
      display: inline-flex;
      align-items: center;
      gap: 0.35rem;
      padding: 0.35rem 0.6rem;
      border-radius: 10px;
      background: rgba(15, 23, 42, 0.08);
      font-family: "IBM Plex Mono", "SFMono-Regular", Menlo, monospace;
      font-size: 0.85rem;
    """

  styled RoutePanel = d:
    """
      padding: 1.25rem 1.5rem;
      margin-top: 0.75rem;
      border-radius: 16px;
      border: 1px solid rgba(148, 163, 184, 0.2);
      background: rgba(15, 23, 42, 0.03);
    """

  proc HeroLinks(): Node =
    DemoRow:
      Link(
        href = "/links",
        `aria-label` = "Go to the overview section",
        `data-tracking` = "links-overview"
      ):
        "Overview"

      StyledLink(href = "/links/router"):
        "Router"

      StyledLinkUnderline(href = "/links/styled?utm_source=jmsapps"):
        "Styled"

      ChipLink(
        href = "/links/attrs#fragment",
        `aria-label` = "See custom attribute examples"
      ):
        span: "🧭"
        span: "Attrs"

      Link(
        href = "https://github.com/jmsapps/ntml",
        target = "_blank",
        `aria-label` = "Visit the NTML repo"
      ):
        "GitHub"

  proc RouteOverview(): Node =
    RoutePanel:
      Paragraph:
        "Use Link to keep native anchor behavior and still integrate with navigate()."
      CodeBadge:
        "Link(href=\"/links\", `aria-label`=\"Go\")"

  proc RouteRouter(): Node =
    RoutePanel:
      Paragraph:
        "Unmodified left-clicks call navigate(), while modified clicks and external URLs behave normally."
      CodeBadge:
        "Link(href=\"/links/router\", onClick=proc (e: Event) = discard)"

  proc RouteStyled(): Node =
    RoutePanel:
      Paragraph:
        "Link is compatible with styled so you can build design-system variants."
      CodeBadge:
        "styled PrimaryLink = Link: \"\"\"...\"\"\""

  proc RouteAttrs(): Node =
    RoutePanel:
      Paragraph:
        "Extra attributes are allowed only for data-* and aria-* for safety."
      CodeBadge:
        "Link(href=\"/links/attrs\", `data-id`=\"42\")"

  proc App(): Node =
    let router = router()
    let location = router.location

    discard effect(proc () =
      echo "location: " & router.location.get()
      echo "path: " & router.path.get()
      echo "search: " & router.search.get()
      echo "hash: " & router.hash.get()

    , [router.location])

    Page:
      Card:
        Heading: "Link helper"
        Subheading:
          "This example shows how Link preserves anchor semantics while still using NTML routing."

        SectionTitle: "Navigation"
        Paragraph:
          "Use the Link helper instead of button + navigate() to keep accessible markup."
        HeroLinks()

        SectionTitle: "Routes"
        Paragraph:
          "Each link updates the route signal. The panel below is rendered with Routes()."

        Paragraph:
          b: "Location: "
          router.location
          br()
          b: "Path: "
          router.path
          br()
          b: "Search: "
          router.search
          br()
          b: "Hash: "
          router.hash; br()

        Routes(location):
          Route(path = "/links", component = RouteOverview)
          Route(path = "/links/router", component = RouteRouter)
          Route(path = "/links/styled", component = RouteStyled)
          Route(path = "/links/attrs", component = RouteAttrs)
          Route(path = "*", component = RouteOverview)

  render(App())

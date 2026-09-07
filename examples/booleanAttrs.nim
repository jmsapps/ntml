when isMainModule and defined(js):
  import ../src/ntml

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
    let required = signal(false)

    Page:
      Card:
        h1: "Boolean attributes"
        p: "Falsey values remove the attribute rather than writing it as a string."

        form(id = "demo", novalidate = "false"):
          input(id = "a", `type` = "text", autofocus = "false")
          input(id = "b", `type` = "text", autofocus = "true")
          input(id = "c", `type` = "text", required = required)
          video(id = "v", controls = "false", loop = "true", muted = "false")

        button(
          id = "toggle",
          `type` = "button",
          onClick = proc (e: Event) = required.set(not required.get())
        ):
          "Toggle required"

  render(App())

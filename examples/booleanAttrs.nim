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
      max-width: 760px;
      margin: 0 auto 1.25rem auto;
      padding: clamp(1.25rem, 3vw, 2rem);
      border-radius: 20px;
      line-height: 1.7;
      background: rgba(255, 255, 255, 0.96);
      box-shadow: 0 20px 55px rgba(15, 23, 42, 0.10);
    """

  styled Lede = p:
    """
      margin: 0 0 1.25rem 0;
      color: rgba(15, 23, 42, 0.72);
      line-height: 1.65;
    """

  styled Legend = h2:
    """
      margin: 0 0 0.35rem 0;
      font-size: 1.05rem;
      letter-spacing: -0.01em;
    """

  styled Hint = p:
    """
      margin: 0 0 1rem 0;
      font-size: 0.9rem;
      color: rgba(15, 23, 42, 0.6);
      line-height: 1.6;
    """

  styled Row = d:
    """
      display: flex;
      flex-wrap: wrap;
      gap: 0.75rem;
      align-items: center;
      margin-bottom: 0.75rem;
    """

  styled NativeBtn = button:
    """
      padding: 0.6rem 1.1rem;
      border-radius: 999px;
      font: inherit;
      font-weight: 600;
      cursor: pointer;
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

  styled Field = input:
    """
      padding: 0.55rem 0.8rem;
      border-radius: 10px;
      border: 1px solid rgba(15, 23, 42, 0.2);
      font: inherit;
      min-width: 15rem;
    """

  styled Panel = details:
    """
      margin-bottom: 0.6rem;
      padding: 0.5rem 0.75rem;
      border-radius: 10px;
      background: rgba(15, 23, 42, 0.04);
    """

  styled Placeholder = video:
    """
      border: 1px dashed rgba(15, 23, 42, 0.3);
      border-radius: 10px;
      background: rgba(15, 23, 42, 0.04);
    """

  styled Tally = p:
    """
      margin: 0;
      font-family: "IBM Plex Mono", monospace;
      font-size: 0.9rem;
      color: rgba(15, 23, 42, 0.75);
    """

  proc App(): Node =
    let clicks = signal(0)
    let submits = signal(0)
    let locked = signal(false)

    Page:
      Card:
        h1: "Boolean attributes"
        Lede:
          "An HTML boolean attribute is true whenever it is "
          strong: "present"
          ", whatever its value — so a falsey value has to remove it, not write the "
          "string \"false\". Every control below is written with a string or a signal, "
          "and you can check each one by using it."

      Card:
        Legend: "disabled"
        Hint: "The left button works. The right one does not. Both were written the same way, with different values."
        Row:
          NativeBtn(id = "btn-false", disabled = "false", onClick = proc (e: Event) = clicks.set(clicks.get() + 1)):
            "disabled = \"false\" — try me"
          NativeBtn(id = "btn-true", disabled = "true", onClick = proc (e: Event) = clicks.set(clicks.get() + 1)):
            "disabled = \"true\" — inert"
        Tally: "clicks registered: "; clicks

      Card:
        Legend: "open and readonly"
        Hint: "One panel starts expanded, one collapsed. One field accepts typing, one refuses."
        Panel(id = "det-false", open = "false"):
          summary: "open = \"false\" — starts collapsed"
          p: "If this were expanded on load, the attribute was written rather than removed."
        Panel(id = "det-true", open = "true"):
          summary: "open = \"true\" — starts expanded"
          p: "Present means true."
        Row:
          Field(id = "ro-false", readonly = "false", value = "readonly = \"false\" — type here")
          Field(id = "ro-true", readonly = "true", value = "readonly = \"true\" — refuses input")

      Card:
        Legend: "novalidate and required, driven by a signal"
        Hint:
          "Submit with the field empty. The browser blocks it, which proves novalidate "
          "was removed rather than written as \"false\". Untick the box and submit again."
        form(id = "demo", novalidate = "false", onSubmit = proc (e: Event) =
          jsPreventDefault(e)
          submits.set(submits.get() + 1)
        ):
          Row:
            Field(id = "c", `type` = "text", required = locked, placeholder = "required follows the checkbox")
            Btn(`type` = "submit"): "Submit"
          Row:
            label:
              input(id = "toggle", `type` = "checkbox", checked = locked)
              " required is "
              span(id = "required-state"):
                if locked:
                  "present"
                else:
                  "absent"
        Tally: "successful submits: "; submits

      Card:
        Legend: "no visible effect on this page"
        Hint:
          "autofocus, controls, loop and muted are asserted by the test suite rather than "
          "shown. The second field takes focus on load because its autofocus is present."
        Row:
          Field(id = "a", `type` = "text", autofocus = "false", placeholder = "autofocus = \"false\"")
          Field(id = "b", `type` = "text", autofocus = "true", placeholder = "autofocus = \"true\"")
        Row:
          Placeholder(id = "v", controls = "false", loop = "true", muted = "false", width = "220", height = "80")
          Hint: "video with no source — controls absent, loop present, muted absent"

  render(App())

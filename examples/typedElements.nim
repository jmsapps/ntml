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

  styled Code = code:
    """
      padding: 0.15rem 0.4rem;
      border-radius: 6px;
      background: rgba(15, 23, 42, 0.06);
      font-family: "IBM Plex Mono", monospace;
      font-size: 0.85rem;
    """

  proc App(): Node =
    let expanded = signal(false)
    let tone = signal("calm")
    let camelOpen = signal(false)
    let camelChecked = signal(false)

    Page:
      Card:
        h1: "Typed elements"
        Lede:
          "Attribute names, element/attribute combinations and value types are checked "
          "when this file compiles. Nothing here changed how NTML is written — the same "
          "markup as every other example, now with the compiler checking it."

      Card:
        Legend: "Checked at compile time"
        Hint:
          "Each attribute below is valid on its element. Writing "
          Code: "href"
          " on a div, or "
          Code: "hreff"
          " anywhere, stops the build with the offending line and column."
        Hint:
          "Nothing in this card reacts to a click. The demonstration already happened "
          "when the file compiled — these controls are here to carry the attributes."
        Row:
          Field(
            id = "typed-field",
            `type` = "text",
            placeholder = "type is valid on input",
            autocomplete = "off",
            required = false
          )
          Btn(id = "typed-btn", `type` = "button", disabled = false): "button type"

      Card:
        Legend: "ARIA booleans serialize, they do not disappear"
        Hint:
          "An ARIA attribute is not an HTML boolean attribute. Bound to a "
          Code: "Signal[bool]"
          ", false must render as the string \"false\" so assistive technology can read "
          "the collapsed state."
        Row:
          Btn(
            id = "aria-toggle",
            `aria-expanded` = expanded,
            `aria-controls` = "aria-panel",
            onClick = proc (e: Event) = expanded.set(not expanded.get())
          ): "toggle aria-expanded"
        d(id = "aria-panel", hidden = derived(expanded, proc (x: bool): bool = not x)):
          p: "Panel contents."

      Card:
        Legend: "camelCase spellings, no backticks"
        Hint:
          "Hyphenated names are not Nim identifiers, so "
          Code: "`aria-label`"
          " needs backticks. The camelCase spelling is accepted instead and resolves to "
          "the real attribute: "
          Code: "ariaLabel"
          " sets "
          Code: "aria-label"
          ", "
          Code: "dataRevealDelay"
          " sets "
          Code: "data-reveal-delay"
          ", and "
          Code: "htmlFor"
          " sets "
          Code: "for"
          "."
        Row:
          label(htmlFor = "camel-check", id = "camel-label"):
            "Click this label — htmlFor points it at the checkbox:"
          input(
            id = "camel-check",
            `type` = "checkbox",
            checked = camelChecked,
            ariaLabel = "written as ariaLabel"
          )
        Row:
          Btn(
            id = "camel-toggle",
            ariaExpanded = camelOpen,
            ariaControls = "camel-panel",
            onClick = proc (e: Event) = camelOpen.set(not camelOpen.get())
          ): "toggle (written ariaExpanded)"
        d(
          id = "camel-panel",
          dataRevealDelay = "200",
          hidden = derived(camelOpen, proc (x: bool): bool = not x)
        ):
          p: "Shown by a signal bound through the camelCase spelling."

      Card:
        Legend: "Escape hatch for nonstandard attributes"
        Hint:
          "Unknown attribute names are compile errors. Deliberate nonstandard attributes "
          "go through "
          Code: "customAttrs"
          ", which forwards names verbatim."
        Row:
          d(id = "raw-table", customAttrs = {"x-state": "ready", "x-tone": tone}):
            "customAttrs = {\"x-state\": \"ready\", \"x-tone\": tone}"
        Row:
          d(id = "raw-tuples", customAttrs = rawAttrs(("hx-get", "/api"), ("hx-swap", "outerHTML"))):
            "customAttrs = rawAttrs((\"hx-get\", \"/api\"))"
        Row:
          Btn(
            id = "tone-btn",
            onClick = proc (e: Event) =
              tone.set(if tone.get() == "calm": "alert" else: "calm")
          ): "toggle x-tone"
          Hint:
            "x-tone is currently "
            Code(id = "tone-state"): tone
            ". The attribute is not visible on the page, so the value is mirrored here; "
            "inspect the element above to see it change." 

      Card:
        Legend: "data-* and aria-* still pass through"
        Hint: "Both prefixes are accepted on every element without being enumerated."
        Row:
          span(id = "prefixed", `data-kind` = "demo", `aria-label` = "prefixed span"):
            "data-kind and aria-label"

  render(App())

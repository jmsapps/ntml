when isMainModule and defined(js):
  import strutils

  import ../src/ntml

  proc jsEventKey(e: Event): string {.importjs: "cstrToNimstr(#.key)".}
  proc jsEventTargetValue(e: Event): string {.importjs: "cstrToNimstr(#.target.value)".}
  proc jsPreventDefault(e: Event) {.importjs: "#.preventDefault()".}

  styled Page = d:
    """
      min-height: 100vh;
      padding: 3.5rem clamp(1.5rem, 4vw, 4.5rem);
      color: #0f172a;
      background: radial-gradient(circle at 15% 20%, rgba(59, 130, 246, 0.16), transparent 55%),
                  radial-gradient(circle at 85% 80%, rgba(16, 185, 129, 0.14), transparent 55%),
                  #f8fafc;
      font-family: "IBM Plex Sans", "Segoe UI", sans-serif;
    """

  styled Card = d:
    """
      max-width: 760px;
      margin: 0 auto;
      padding: clamp(1.5rem, 3vw, 2.5rem);
      border-radius: 22px;
      background: rgba(255, 255, 255, 0.92);
      box-shadow: 0 24px 60px rgba(15, 23, 42, 0.12);
      border: 1px solid rgba(148, 163, 184, 0.2);
      backdrop-filter: blur(16px);
    """

  styled Heading = h1:
    """
      margin: 0 0 0.75rem 0;
      font-size: clamp(2rem, 3vw, 2.6rem);
      letter-spacing: -0.03em;
    """

  styled Paragraph = p:
    """
      margin: 0 0 1rem 0;
      color: rgba(15, 23, 42, 0.78);
      line-height: 1.6;
    """

  styled InputWrap = d:
    """
      margin-top: 1.25rem;
      position: relative;
    """

  styled Input = input:
    """
      width: calc(100% - 2rem);
      padding: 0.8rem 1rem;
      border-radius: 12px;
      border: 1px solid rgba(148, 163, 184, 0.4);
      font-size: 1rem;
      outline: none;
    """

  styled Listbox = ul:
    """
      position: absolute;
      top: calc(100% + 0.6rem);
      left: 0;
      right: 0;
      list-style: none;
      margin: 0;
      padding: 0.35rem;
      border-radius: 14px;
      background: #ffffff;
      border: 1px solid rgba(148, 163, 184, 0.25);
      box-shadow: 0 18px 45px rgba(15, 23, 42, 0.12);
      max-height: 220px;
      overflow-y: auto;
      z-index: 2;
    """

  styled Option = li:
    """
      padding: 0.55rem 0.75rem;
      border-radius: 10px;
      cursor: pointer;
      font-size: 0.98rem;
      transition: background 160ms ease, color 160ms ease;
    """

  styled HelpText = p:
    """
      margin-top: 1.25rem;
      color: rgba(15, 23, 42, 0.65);
      font-size: 0.95rem;
    """

  proc App(): Node =
    let allOptions = @[
      "Almond",
      "Apricot",
      "Blueberry",
      "Cantaloupe",
      "Coconut",
      "Dragonfruit",
      "Grapefruit",
      "Kiwi",
      "Lychee",
      "Mango",
      "Nectarine",
      "Peach",
      "Pineapple",
      "Raspberry",
      "Strawberry"
    ]

    let query = signal("")
    let isOpen = signal(false)
    let activeIndex = signal(-1)

    let filtered = derived(query, proc (q: string): seq[string] =
      let trimmed = q.strip().toLowerAscii()
      if trimmed.len == 0:
        return allOptions
      result = @[]
      for item in allOptions:
        if trimmed in item.toLowerAscii():
          result.add(item)
    )

    let activeDesc = derived(activeIndex, proc (idx: int): string =
      if idx < 0: "" else: "cb-option-" & $idx
    )

    proc selectIndex(idx: int) =
      let options = filtered.get()
      if idx < 0 or idx >= options.len:
        return
      query.set(options[idx])
      isOpen.set(false)
      activeIndex.set(-1)

    Page:
      Card:
        Heading: "Combobox a11y example"
        Paragraph:
          "This demo uses proper combobox/listbox roles with aria-expanded and aria-activedescendant."
        Paragraph:
          "Use Arrow keys to move, Enter to select, and Escape to close."

        InputWrap:
          Input(
            `role` = "combobox",
            `aria-autocomplete` = "list",
            `aria-controls` = "cb-listbox",
            `aria-expanded` = isOpen,
            `aria-activedescendant` = activeDesc,
            value = query,
            onInput = proc (e: Event) =
              query.set(jsEventTargetValue(e))
              isOpen.set(true)
              activeIndex.set(-1)
            ,
            onFocus = proc (e: Event) =
              isOpen.set(true)
            ,
            onBlur = proc (e: Event) =
              isOpen.set(false)
              activeIndex.set(-1)
            ,
            onKeyDown = proc (e: Event) =
              let key = jsEventKey(e)
              let options = filtered.get()
              if key == "ArrowDown":
                jsPreventDefault(e)
                isOpen.set(true)
                if options.len > 0:
                  activeIndex.set(min(activeIndex.get() + 1, options.len - 1))
              elif key == "ArrowUp":
                jsPreventDefault(e)
                if options.len > 0:
                  activeIndex.set(max(activeIndex.get() - 1, 0))
              elif key == "Enter":
                if activeIndex.get() >= 0:
                  jsPreventDefault(e)
                  selectIndex(activeIndex.get())
              elif key == "Escape":
                jsPreventDefault(e)
                isOpen.set(false)
                activeIndex.set(-1)
          )

          if isOpen and filtered.len > 0:
            Listbox(id = "cb-listbox", `role` = "listbox"):
              for i, option in filtered:
                Option(
                  id = "cb-option-" & $i,
                  `role` = "option",
                  `aria-selected` = derived(activeIndex, proc (idx: int): string = (if idx == i: "true" else: "false")),
                  style = derived(activeIndex, proc (idx: int): string =
                    if idx == i:
                      "background: rgba(37, 99, 235, 0.12); color: #1d4ed8;"
                    else:
                      ""
                  ),
                  onMouseDown = proc (e: Event) =
                    jsPreventDefault(e)
                    selectIndex(i)
                ):
                  option

        HelpText:
          "Tip: Use data-*/aria-* attributes for accessibility and keep keyboard support in sync with focus."

  render(App())

when defined(js):
  import ../src/ntml

  when isMainModule:
    type
      SubObj = object
        subList: seq[string]

      Object = object
        subObj: SubObj

      Entry = tuple[id: string, label: string]

    proc defaultKeyedItems(): seq[Entry] =
      @[
        (id: "alpha", label: "Alpha"),
        (id: "bravo", label: "Bravo"),
        (id: "charlie", label: "Charlie")
      ]

    proc defaultDuplicateItems(): seq[Entry] =
      @[
        (id: "dup-1", label: "One"),
        (id: "dup-2", label: "Two"),
        (id: "dup-3", label: "Three")
      ]

    let obj = signal[Object](Object(subObj: SubObj(subList: @["*", "-", "-", "-", "-"])))
    let list = signal[seq[string]](@["-"])
    let keyedItems = signal[seq[Entry]](defaultKeyedItems())
    let duplicateItems = signal[seq[Entry]](defaultDuplicateItems())

    static:
      doAssert obj.subObj is Signal[SubObj]
      doAssert obj.subObj.subList is Signal[seq[string]]
      doAssert not compiles(obj.n)

    let component: Node =
      d(class="layout"):
        section(class="panel"):
          h1(class="panel-title"): "For Statements"

          ul(class="symbol-list", id="symbols"):
            for i, v in obj.subObj.subList:
              li(key=i, class="symbol-item"):
                span(class="symbol-index"): "#" & $(i + 1)
                span(class="symbol-value"): obj.subObj.subList[i]
                span(class="symbol-prev"): v

          button(class="panel-button", onClick =
            proc (e: Event) =
              var oldList = get(obj).subObj.subList
              let popped = @[oldList.pop()]
              let newList = popped & oldList

              set(obj, Object(subObj: SubObj(subList: newList)))
          ):
            "Cycle list order"

          hr(class="panel-rule")

          h2(class="section-title"):
            "Number of items in list: "
            span(class="count-value"): len(list)

          d(class="panel-actions"):
            button(class="panel-button", onClick =
              proc (e: Event) =
                list.set(list() & @["-"])
            ):
              "Add to list"

            button(
              class="panel-button is-secondary",
              onClick=(proc (e: Event) =
                list.set(list()[0 ..< max(0, len(list()) - 1)])
              ),
              disabled=(len(list) == 0)
            ):
              "Remove from list"

          ul(class="list-output"):
            for i, val in list:
              li(key=i, class="list-item"):
                span(class="symbol-index"): "#" & $(i + 1)
                span(class="symbol-value"): val

          hr(class="panel-rule")

          h2(class="section-title"): "Keyed list (swap + update)"

          ul(class="list-output"):
            for item in keyedItems:
              li(key=item.id, class="list-item"):
                span(class="symbol-index"): item.id
                span(class="symbol-value"): item.label

          d(class="panel-actions"):
            button(class="panel-button", onClick =
              proc (e: Event) =
                var current = keyedItems()
                if current.len >= 2:
                  let tmp = current[0]
                  current[0] = current[1]
                  current[1] = tmp
                  keyedItems.set(current)
            ):
              "Swap first two"

            button(class="panel-button is-secondary", onClick =
              proc (e: Event) =
                var current = keyedItems()
                if current.len > 0:
                  current[^1].label = current[^1].label & " •"
                  keyedItems.set(current)
            ):
              "Mutate last label"

            button(
              class="panel-button is-secondary",
              onClick=(proc (e: Event) = keyedItems.set(defaultKeyedItems()))
            ):
              "Reset keyed list"

          hr(class="panel-rule")

          h2(class="section-title"): "Duplicate key guard (debug build logs duplicates)"

          ul(class="list-output", id="duplicate-keys"):
            for idx, item in duplicateItems:
              li(key=item.id, class="list-item"):
                span(class="symbol-index"): "#" & $(idx + 1)
                span(class="symbol-value"): item.label
                span(class="symbol-prev"): "key=" & item.id

          d(class="panel-actions"):
            button(class="panel-button", onClick =
              proc (e: Event) =
                var current = duplicateItems()
                if current.len > 0:
                  var dup = current[0]
                  dup.label = dup.label
                  current.add(dup)
                  duplicateItems.set(current)
            ):
              "Add duplicate key"

            button(class="panel-button is-secondary", onClick =
              proc (e: Event) =
                var current = duplicateItems()
                if current.len > 0:
                  let last = current[^1]
                  current.setLen(current.len - 1)
                  duplicateItems.set(@[last] & current)
            ):
              "Rotate order"

            button(
              class="panel-button is-secondary",
              onClick=(proc (e: Event) = duplicateItems.set(defaultDuplicateItems()))
            ):
              "Reset duplicate list"

        style:
          """
            :root {
              background: #020617;
              color: #e2e8f0;
              font-family: 'Inter', system-ui, sans-serif;
            }

            body {
              margin: 0;
              min-height: 100vh;
              display: flex;
              align-items: center;
              justify-content: center;
              padding: 3.5rem 1rem;
              background: radial-gradient(circle at 15% 20%, rgba(86, 62, 245, 0.18), transparent 55%),
                          radial-gradient(circle at 85% 85%, rgba(56, 189, 248, 0.18), transparent 60%),
                          #020617;
            }

            .layout {
              width: min(720px, 100%);
            }

            .panel {
              background: rgba(15, 23, 42, 0.8);
              border-radius: 24px;
              padding: 2.5rem 3rem;
              box-shadow: 0 32px 60px rgba(8, 15, 35, 0.45);
              border: 1px solid rgba(148, 163, 184, 0.2);
              display: flex;
              flex-direction: column;
              gap: 1.75rem;
            }

            .panel-title {
              margin: 0;
              font-size: clamp(2rem, 4vw, 2.6rem);
              letter-spacing: -0.03em;
            }

            .symbol-list,
            .list-output {
              margin: 0;
              padding: 0;
              list-style: none;
              display: flex;
              flex-direction: column;
              gap: 0.75rem;
            }

            .symbol-item,
            .list-item {
              display: flex;
              align-items: center;
              gap: 0.75rem;
              padding: 0.85rem 1.1rem;
              border-radius: 16px;
              background: rgba(30, 41, 59, 0.6);
              border: 1px solid rgba(148, 163, 184, 0.12);
            }

            .symbol-index {
              font-size: 0.85rem;
              letter-spacing: 0.08em;
              text-transform: uppercase;
              color: rgba(148, 163, 184, 0.65);
            }

            .symbol-value {
              font-weight: 600;
              font-size: 1.05rem;
            }

            .symbol-prev {
              margin-left: auto;
              color: rgba(148, 163, 184, 0.55);
            }

            .panel-button {
              border: none;
              border-radius: 999px;
              padding: 0.85rem 1.6rem;
              font-weight: 600;
              color: #0f172a;
              background: linear-gradient(135deg, #38bdf8, #8b5cf6);
              cursor: pointer;
              transition: transform 0.15s ease, box-shadow 0.15s ease;
              align-self: flex-start;
            }

            .panel-button:hover {
              transform: translateY(-1px);
              box-shadow: 0 16px 35px rgba(139, 92, 246, 0.35);
            }

            .panel-button.is-secondary {
              background: transparent;
              color: #e2e8f0;
              border: 1px solid rgba(148, 163, 184, 0.35);
              box-shadow: none;
            }

            .panel-button.is-secondary:hover {
              background: rgba(148, 163, 184, 0.12);
              transform: none;
            }

            .panel-rule {
              border: none;
              height: 1px;
              background: linear-gradient(90deg, transparent, rgba(148, 163, 184, 0.35), transparent);
              margin: 1rem 0;
            }

            .section-title {
              margin: 0;
              font-size: 1.25rem;
              letter-spacing: -0.01em;
            }

            .count-value {
              font-weight: 700;
              color: #38bdf8;
              margin-left: 0.4rem;
            }

            .panel-actions {
              display: flex;
              gap: 0.75rem;
              flex-wrap: wrap;
            }
          """

    discard jsAppendChild(document.body, component)

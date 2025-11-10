when isMainModule and defined(js):
  import ../src/ntml
  import std/[sequtils]

  type
    Item = object
      id: int
      text: string

    Book = object
      id: int
      title: string

    Shelf = object
      id: int
      name: string
      books: seq[Book]

    Metric = object
      id: int
      label: string
      value: string

    Task = object
      id: int
      label: string
      done: bool

    EffectEntry = object
      id: int
      label: string

  styled AppShell = d:
    """
      min-height: 100vh;
      padding: 2.5rem 1rem 3.5rem;
      background: radial-gradient(circle at top, #dbeafe, #eff6ff 55%, #e0f2fe);
      font-family: "Inter", system-ui, -apple-system, BlinkMacSystemFont, sans-serif;
      color: #0f172a;
    """

  styled DemoPanel = AppShell:
    """
      margin: 0 auto;
      background: #fff;
      border-radius: 28px;
      padding: 2.5rem;
      box-shadow: 0 30px 90px rgba(15, 23, 42, 0.12);
      display: flex;
      flex-direction: column;
      gap: 1.75rem;
    """

  styled SectionHeading = h1:
    """
      margin: 0;
      font-size: clamp(2.1rem, 4vw, 2.8rem);
      color: #111827;
    """

  styled PanelSection = d:
    """
      border: 1px solid #e2e8f0;
      border-radius: 20px;
      padding: 1.5rem;
      background: #f8fafc;
      display: flex;
      flex-direction: column;
      gap: 1rem;
    """

  styled PanelTitle = h3:
    """
      margin: 0;
      font-size: 1.15rem;
      color: #0f172a;
    """

  styled PanelNote = p:
    """
      margin: 0;
      color: #475569;
      line-height: 1.6;
      font-size: 0.95rem;
    """

  styled InstructionList = ul:
    """
      margin: 0;
      padding-left: 1.4rem;
      color: #475569;
      line-height: 1.65;
    """

  styled ControlRow = d:
    """
      display: flex;
      flex-wrap: wrap;
      gap: 0.75rem;
    """

  styled PrimaryButton = button:
    """
      border: none;
      border-radius: 999px;
      padding: 0.75rem 1.4rem;
      font-weight: 600;
      font-size: 0.95rem;
      cursor: pointer;
      transition: transform 0.15s ease, box-shadow 0.15s ease, opacity 0.15s ease;
      color: #fff;
      background: linear-gradient(135deg, #2563eb, #3b82f6);
      box-shadow: 0 12px 20px rgba(37, 99, 235, 0.25);
    """

  styled NeutralButton = PrimaryButton:
    """
      background: #0f172a;
      box-shadow: 0 12px 25px rgba(15, 23, 42, 0.25);
    """

  styled KeyedList = ul:
    """
      list-style: none;
      margin: 0;
      padding: 0;
      display: flex;
      flex-direction: column;
      gap: 0.9rem;
    """

  styled KeyedItem = li:
    """
      background: #f8fafc;
      border-radius: 18px;
      padding: 1rem 1.25rem;
      box-shadow: 0 10px 25px rgba(15, 23, 42, 0.06);
      border: 1px solid #e2e8f0;
      display: flex;
      flex-direction: column;
      gap: 0.65rem;
    """

  styled ItemHeader = d:
    """
      display: flex;
      align-items: center;
      gap: 0.75rem;
      font-weight: 600;
      color: #0f172a;
    """

  styled ItemBadge = span:
    """
      min-width: 48px;
      padding: 0.2rem 0.65rem;
      border-radius: 999px;
      background: rgba(37, 99, 235, 0.12);
      color: #2563eb;
      text-align: center;
      font-variant-numeric: tabular-nums;
    """

  styled ItemButtons = d:
    """
      display: flex;
      flex-wrap: wrap;
      gap: 0.5rem;
    """

  styled ItemButton = button:
    """
      border-radius: 10px;
      border: 1px solid #d4dbe8;
      padding: 0.45rem 0.85rem;
      font-size: 0.85rem;
      font-weight: 600;
      color: #0f172a;
      background: #fff;
      cursor: pointer;
      transition: background 0.15s ease, color 0.15s ease, box-shadow 0.15s ease;
      box-shadow: 0 5px 12px rgba(15, 23, 42, 0.05);
    """

  styled ItemDangerButton = ItemButton:
    """
      background: #ef4444;
      border-color: #ef4444;
      color: #fff;
      box-shadow: 0 6px 16px rgba(239, 68, 68, 0.3);
    """

  styled NestedList = ul:
    """
      list-style: none;
      margin: 0;
      padding: 0;
      display: flex;
      flex-wrap: wrap;
      gap: 0.5rem;
    """

  styled NestedPill = span:
    """
      padding: 0.35rem 0.75rem;
      border-radius: 999px;
      background: rgba(14, 116, 144, 0.12);
      color: #0f766e;
      font-weight: 600;
      font-size: 0.85rem;
    """

  styled MixedDivider = span:
    """
      color: #cbd5f5;
      font-weight: 700;
      padding: 0 0.35rem;
    """

  styled AccentCard = d:
    """
      border-radius: 18px;
      padding: 1rem 1.25rem;
      background: rgba(15, 23, 42, 0.85);
      color: white;
      display: flex;
      align-items: center;
      justify-content: space-between;
      box-shadow: 0 25px 35px rgba(15, 23, 42, 0.35);
    """

  styled AccentBadge = span:
    """
      font-weight: 700;
      letter-spacing: 0.08em;
      color: var(--accent, #38bdf8);
    """

  styled CheckboxRow = label:
    """
      display: flex;
      align-items: center;
      gap: 0.75rem;
      padding: 0.65rem 0.85rem;
      border-radius: 12px;
      border: 1px solid #e2e8f0;
      background: white;
      cursor: pointer;
    """

  styled CheckboxInput = input:
    """
      width: 16px;
      height: 16px;
    """

  styled CheckboxLabel = span:
    """
      font-weight: 600;
      color: #0f172a;
    """

  proc App(): Node =
    let items = signal(@[
      Item(id: 1, text: "A"),
      Item(id: 2, text: "B"),
      Item(id: 3, text: "C"),
    ])
    let nextId = signal(4)

    let shelves = signal(@[
      Shelf(
        id: 1,
        name: "Shelf A",
        books: @[
          Book(id: 11, title: "Alpha"),
          Book(id: 12, title: "Beta"),
          Book(id: 13, title: "Gamma")
        ]
      ),
      Shelf(
        id: 2,
        name: "Shelf B",
        books: @[
          Book(id: 21, title: "Delta"),
          Book(id: 22, title: "Epsilon")
        ]
      )
    ])
    let nextBookId = signal(30)

    let metrics = signal(@[
      Metric(id: 1, label: "Latency", value: "24ms"),
      Metric(id: 2, label: "Throughput", value: "1.2k req/s"),
      Metric(id: 3, label: "Errors", value: "0.02%")
    ])

    let duplicateRegions = signal(@["North", "East", "North"])

    let tasks = signal(@[
      Task(id: 1, label: "Warm caches", done: false),
      Task(id: 2, label: "Trim bundles", done: true),
      Task(id: 3, label: "Sync configs", done: false)
    ])

    let effectEntries = signal(@[
      EffectEntry(id: 1, label: "Logger"),
      EffectEntry(id: 2, label: "Timer"),
      EffectEntry(id: 3, label: "Metrics")
    ])

    let showAccentCards = signal(true)
    let accentVar = signal("#38bdf8")

    proc add() =
      var xs = items.get()
      xs.add(Item(id: nextId.get(), text: "N" & $nextId.get()))
      items.set(xs)
      nextId.set(nextId.get() + 1)

    proc removeFirst() =
      var xs = items.get()
      if xs.len > 0:
        xs.delete(0)
        items.set(xs)

    proc swapFirstTwo() =
      var xs = items.get()
      if xs.len >= 2:
        swap(xs[0], xs[1])
        items.set(xs)

    proc removeById(id: int) =
      items.set(items.get().filterIt(it.id != id))

    proc moveToFront(id: int) =
      var xs = items.get()
      var idx = -1
      for i in 0 ..< xs.len:
        if xs[i].id == id:
          idx = i
          break
      if idx >= 0:
        let v = xs[idx]
        xs.delete(idx)
        xs.insert(v, 0)
        items.set(xs)

    proc burstRename() =
      for _ in 0 ..< 3:
        var xs = items.get()
        if xs.len == 0:
          break
        xs[0].text = xs[0].text & "!"
        items.set(xs)

    proc shiftKey(id: int) =
      var xs = items.get()
      for i in 0 ..< xs.len:
        if xs[i].id == id:
          xs[i].id = xs[i].id + 100
          break
      items.set(xs)

    proc rotateBooks(shelfId: int) =
      var cur = shelves.get()
      for i in 0 ..< cur.len:
        if cur[i].id == shelfId and cur[i].books.len > 1:
          let head = cur[i].books[0]
          cur[i].books.delete(0)
          cur[i].books.add(head)
          break
      shelves.set(cur)

    proc addBook(shelfId: int) =
      var cur = shelves.get()
      for i in 0 ..< cur.len:
        if cur[i].id == shelfId:
          cur[i].books.add(Book(id: nextBookId.get(), title: "B" & $nextBookId.get()))
          break
      shelves.set(cur)
      nextBookId.set(nextBookId.get() + 1)

    proc shuffleMetrics() =
      var cur = metrics.get()
      if cur.len > 1:
        cur.insert(cur.pop(), 0)
        metrics.set(cur)

    proc addDuplicateRegion() =
      var cur = duplicateRegions.get()
      if cur.len > 0:
        cur.add(cur[0])
        duplicateRegions.set(cur)

    proc resetDuplicateRegions() =
      duplicateRegions.set(@["North", "East", "North"])

    proc toggleTask(id: int) =
      var cur = tasks.get()
      for i in 0 ..< cur.len:
        if cur[i].id == id:
          cur[i].done = not cur[i].done
          break
      tasks.set(cur)

    proc cycleEffects() =
      var cur = effectEntries.get()
      if cur.len > 0:
        cur.insert(cur.pop(), 0)
        effectEntries.set(cur)

    proc toggleAccent() =
      showAccentCards.set(not showAccentCards.get())

    proc shiftAccentColor() =
      let palette = @["#38bdf8", "#f472b6", "#facc15", "#34d399"]
      let current = accentVar.get()
      var idx = palette.find(current)
      if idx < 0: idx = 0
      idx = (idx + 1) mod palette.len
      accentVar.set(palette[idx])

    AppShell:
      DemoPanel:
        SectionHeading: "Keyed Diffs"

        PanelSection:
          PanelTitle: "Core keyed list"
          PanelNote:
            "Use these buttons to exercise the basic keyed diff. Nodes should stay put unless you deliberately change their key."
          InstructionList:
            li: "Add/Remove/Swap rows: DOM for untouched keys stays put."
            li: "Rename repeatedly: text nodes patch without re-creating buttons."
            li: "'Log Captured' shows stale closures; 'Log Current' reads live state."
            li: "'Shift Key' deliberately changes the key so that one row is torn down and remounted."

          ControlRow:
            PrimaryButton(`type`="button", onClick = proc (e: Event) = add()):
              "Add"
            NeutralButton(`type`="button", onClick = proc (e: Event) = removeFirst()):
              "Remove First"
            NeutralButton(`type`="button", onClick = proc (e: Event) = swapFirstTwo()):
              "Swap First Two"
            NeutralButton(`type`="button", onClick = proc (e: Event) = burstRename()):
              "Burst Rename #1"

          KeyedList(id="keyed-diffs"):
            for it in items:
              KeyedItem(key=it.id):
                ItemHeader:
                  ItemBadge: "#" & $(it.id)
                  span: it.text

                ItemButtons:
                  ItemButton(`type`="button", onClick = proc (e: Event) = echo "clicked id=" & $(it.id)):
                    "Click"
                  ItemButton(`type`="button", onClick = proc (e: Event) =
                    var xs = items.get()
                    var newText = ""
                    for i in 0 ..< xs.len:
                      if xs[i].id == it.id:
                        xs[i].text = xs[i].text & "*"
                        newText = xs[i].text
                        break
                    when defined(debug):
                      echo "[keyed] rename handler id=", it.id, " newText=", newText
                    items.set(xs)
                  ):
                    "Rename"
                  let capturedText = it.text
                  ItemButton(`type`="button", onClick = proc (e: Event) = echo "captured text=" & capturedText):
                    "Log Captured"
                  ItemButton(`type`="button", onClick = proc (e: Event) =
                    var cur = "?"
                    for x in items.get():
                      if x.id == it.id: cur = x.text
                    echo "current text=" & cur
                  ):
                    "Log Current"
                  ItemButton(`type`="button", onClick = proc (e: Event) = moveToFront(it.id)):
                    "To Front"
                  ItemButton(`type`="button", onClick = proc (e: Event) = shiftKey(it.id)):
                    "Shift Key"
                  ItemDangerButton(`type`="button", onClick = proc (e: Event) = removeById(it.id)):
                    "Remove"

        PanelSection:
          PanelTitle: "Nested keyed shelves"
          PanelNote:
            "Each shelf and book is keyed. Rotating or inserting books reuses DOM at both levels."
          for shelf in shelves:
            KeyedItem(key=shelf.id):
              ItemHeader:
                ItemBadge: "Shelf " & $(shelf.id)
                span: shelf.name
              ItemButtons:
                ItemButton(`type`="button", onClick = proc (e: Event) = rotateBooks(shelf.id)):
                  "Rotate Books"
                ItemButton(`type`="button", onClick = proc (e: Event) = addBook(shelf.id)):
                  "Add Book"
              NestedList:
                for book in shelf.books:
                  NestedPill(key=book.id): book.title

        PanelSection:
          PanelTitle: "Mixed keyed / static siblings"
          PanelNote:
            "Dividers here are unkeyed spans interspersed between keyed metrics; shuffling still keeps metrics stable."
          KeyedList:
            for metric in metrics:
              KeyedItem(key=metric.id):
                ItemHeader:
                  ItemBadge: metric.label
                  span: metric.value
              MixedDivider: "•"
          ItemButtons:
            ItemButton(`type`="button", onClick = proc (e: Event) = shuffleMetrics()):
              "Rotate Metrics"

        PanelSection:
          PanelTitle: "Duplicate keys (intentional warning)"
          PanelNote:
            "Click 'Add Duplicate' to reuse the first key—check the console for the warning emitted by the keyed renderer."
          KeyedList:
            for region in duplicateRegions:
              KeyedItem(key=region):
                span: region
          ItemButtons:
            ItemButton(`type`="button", onClick = proc (e: Event) = addDuplicateRegion()):
              "Add Duplicate"
            ItemButton(`type`="button", onClick = proc (e: Event) = resetDuplicateRegions()):
              "Reset Sample"

        PanelSection:
          PanelTitle: "Checkbox + boolean prop patching"
          PanelNote:
            "Checked/unchecked states are patched in place; toggling boxes shouldn't affect siblings."
          KeyedList:
            for todo in tasks:
              KeyedItem(key=todo.id):
                CheckboxRow(onClick = proc (e: Event) = toggleTask(todo.id)):
                  CheckboxInput(
                    `type`="checkbox",
                    checked=todo.done,
                    onChange = proc (e: Event) = toggleTask(todo.id)
                  )
                  CheckboxLabel:
                    (if todo.done: "✅ " else: "") & todo.label

        PanelSection:
          PanelTitle: "Effect cleanup during keyed moves"
          PanelNote:
            "Each row registers an effect that logs mount/unmount in debug builds. Cycling entries should trigger balanced cleanups."
          KeyedList:
            for entry in effectEntries:
              KeyedItem(key=entry.id):
                let entryId = entry.id
                discard effect(proc (): Unsub =
                  when defined(debug):
                    echo "[effect] mount entry=", entryId
                  result = proc () =
                    when defined(debug):
                      echo "[effect] cleanup entry=", entryId
                )
                ItemHeader:
                  ItemBadge: "Effect"
                  span: entry.label
          ItemButtons:
            ItemButton(`type`="button", onClick = proc (e: Event) = cycleEffects()):
              "Cycle Entries"

        PanelSection:
          PanelTitle: "Styled mount/unmount + CSS vars"
          PanelNote:
            "Toggle the accent cards to ensure styled reference counts stay accurate; shift the accent color to exercise styleVars signals."
          ItemButtons:
            PrimaryButton(
              `type`="button",
              styleVars = styleVars("--accent" = accentVar),
              onClick = proc (e: Event) = shiftAccentColor()
            ):
              "Shift Accent Color"
            NeutralButton(`type`="button", onClick = proc (e: Event) = toggleAccent()):
              (if showAccentCards.get(): "Unmount Accent Cards" else: "Mount Accent Cards")
          if showAccentCards.get():
            KeyedList:
              for shelf in shelves:
                AccentCard(
                  key=shelf.id,
                  styleVars = styleVars("--accent" = accentVar)
                ):
                  AccentBadge: "ACNT"
                  span: shelf.name & " · " & $shelf.books.len & " books"

  let component: Node = App()
  discard jsAppendChild(document.body, component)

  {.emit: """
  (function () {
    var target = document.getElementById("keyed-diffs");
    if (!target) {
      console.warn("[keyed_minimal] list not mounted yet");
      return;
    }

    var counter = 1;
    function tagNode(li) {
      if (!li.dataset.instance) li.dataset.instance = String(counter++);
    }
    function tagExisting() {
      target.querySelectorAll(":scope > li").forEach(tagNode);
    }
    tagExisting();

    var obs = new MutationObserver(function (mutations) {
      for (var i = 0; i < mutations.length; i++) {
        var m = mutations[i];
        if (m.type === "childList") {
          Array.prototype.forEach.call(m.addedNodes, function (n) {
            if (n.nodeType === 1 && n.tagName === "LI") {
              tagNode(n);
              console.log("ADDED   li", n.dataset.instance, n);
            }
          });
          Array.prototype.forEach.call(m.removedNodes, function (n) {
            if (n.nodeType === 1 && n.tagName === "LI") {
              console.log("REMOVED li", n.dataset.instance || "(untagged)", n);
            }
          });
        }
        if (m.type === "characterData") {
          var li = m.target.parentElement && m.target.parentElement.closest("li");
          if (li) console.log("PATCH text in li", li.dataset.instance, "->", m.target.data);
        }
        if (m.type === "attributes") {
          var li2 = m.target.closest && m.target.closest("li");
          if (li2) console.log(
            "PATCH attr",
            m.attributeName,
            "on li",
            li2.dataset.instance,
            "old:", m.oldValue,
            "new:", m.target.getAttribute(m.attributeName)
          );
        }
      }
    });

    obs.observe(target, {
      childList: true,
      subtree: true,
      characterData: true,
      characterDataOldValue: true,
      attributes: true,
      attributeOldValue: true,
      attributeFilter: ["class", "value", "checked", "title"]
    });

    console.log("[keyed_minimal] Observer ready; all <li> nodes will auto-tag when added.");
  })();
  """.}

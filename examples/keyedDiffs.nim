when isMainModule and defined(js):
  import ../src/ntml
  import std/[sequtils]

  type
    Item = object
      id: int
      text: string

  styled AppShell = d:
    """
      min-height: 100vh;
      padding: 2.5rem 1rem 3.5rem;
      background: radial-gradient(circle at top, #dbeafe, #eff6ff 55%, #e0f2fe);
      font-family: "Inter", system-ui, -apple-system, BlinkMacSystemFont, sans-serif;
      color: #0f172a;
    """

  styled DemoPanel = d:
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

  styled SectionSubheading = h2:
    """
      margin: 0;
      font-size: 1.2rem;
      font-weight: 600;
      color: #1d4ed8;
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

  let guidance = @[
    "Click 'To Front' on any item to reorder without losing event handlers.",
    "Use 'Rename' repeatedly to mutate a keyed row in place.",
    "Add / Remove First to confirm unaffected items keep their DOM nodes.",
    "Compare 'Say Captured' vs 'Say Current' to see closure vs lookup behavior.",
    "Open DevTools → Console to watch the MutationObserver log per-node edits."
  ]

  proc App(): Node =
    let items = signal(@[
      Item(id: 1, text: "A"),
      Item(id: 2, text: "B"),
      Item(id: 3, text: "C"),
    ])
    let nextId = signal(4)

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

    AppShell:
      DemoPanel:
        SectionHeading: "Keyed Diffs"

        SectionSubheading: "How to test"
        InstructionList:
          for tip in guidance:
            li: tip

        ControlRow:
          PrimaryButton(`type`="button", onClick = proc (e: Event) = add()):
            "Add"
          NeutralButton(`type`="button", onClick = proc (e: Event) = removeFirst()):
            "Remove First"
          NeutralButton(`type`="button", onClick = proc (e: Event) = swapFirstTwo()):
            "Swap First Two"

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
                  "Say Captured"
                ItemButton(`type`="button", onClick = proc (e: Event) =
                  var cur = "?"
                  for x in items.get():
                    if x.id == it.id: cur = x.text
                  echo "current text=" & cur
                ):
                  "Say Current"
                ItemButton(`type`="button", onClick = proc (e: Event) = moveToFront(it.id)):
                  "To Front"
                ItemDangerButton(`type`="button", onClick = proc (e: Event) = removeById(it.id)):
                  "Remove"

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

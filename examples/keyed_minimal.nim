when isMainModule and defined(js):
  import ../src/ntml
  import std/[sequtils]

  type
    Item = object
      id: int
      text: string

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

    d:
      h1: "Keyed Minimal"

      d:
        h2: "How to test"
        ul:
          li: "Click 'To Front' on any item to reorder; 'Click' should still log the correct id."
          li: "Click 'Rename' on an item, then 'Say Captured' — this logs the old text (closure capture)."
          li: "After renaming, 'Say Current' reads fresh state by id and logs the updated text."
          li: "Add / Remove First to verify list identity is preserved for unaffected items."
          li: "Check the console to view the MutationObserver on '#keyed-diffs' to observe moves (remove+add pairs for the same li)."

      d:
        button(`type`="button", onClick = proc (e: Event) = add()): "Add"
        button(`type`="button", onClick = proc (e: Event) = removeFirst()): "Remove First"
        button(`type`="button", onClick = proc (e: Event) = swapFirstTwo()): "Swap First Two"

      ul(id="keyed-diffs"):
        for it in items:
          li(key=it.id):
            span: $(it.id) & ": " & it.text
            # Handler capturing only the stable id (safe under reorders)
            button(`type`="button", onClick = proc (e: Event) = echo "clicked id=" & $(it.id)):
              "Click"
            # Rename this item without changing its key; triggers a keyed update
            button(`type`="button", onClick = proc (e: Event) =
              var xs = items.get()
              for i in 0 ..< xs.len:
                if xs[i].id == it.id:
                  xs[i].text = xs[i].text & "*"
                  break
              items.set(xs)
            ):
              "Rename"
            # Demonstrate closure capturing mutable text (may become stale after rename)
            let capturedText = it.text
            button(`type`="button", onClick = proc (e: Event) = echo "captured text=" & capturedText):
              "Say Captured"
            # Safe pattern: read current text by id at click time
            button(`type`="button", onClick = proc (e: Event) =
              var cur = "?"
              for x in items.get():
                if x.id == it.id: cur = x.text
              echo "current text=" & cur
            ):
              "Say Current"
            button(`type`="button", onClick = proc (e: Event) = moveToFront(it.id)):
              "To Front"
            button(`type`="button", onClick = proc (e: Event) = removeById(it.id)):
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

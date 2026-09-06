when isMainModule and defined(js):
  import std/strutils
  import ../src/ntml

  type
    TreeItem = object
      id: string
      label: string
      children: seq[TreeItem]

  styled Page = d:
    """
      min-height: 100vh;
      padding: 3rem clamp(1.5rem, 4vw, 4rem);
      background: #f8fafc;
      color: #0f172a;
      font-family: "IBM Plex Sans", "Segoe UI", sans-serif;
    """

  styled Card = d:
    """
      max-width: 34rem;
      padding: 1.75rem 2rem;
      background: #ffffff;
      border: 1px solid #e2e8f0;
      border-radius: 14px;
      box-shadow: 0 18px 40px rgba(15, 23, 42, 0.08);
    """

  styled Title = h1:
    """
      margin: 0 0 0.35rem;
      font-size: 1.5rem;
    """

  styled Copy = p:
    """
      margin: 0 0 1.5rem;
      color: #475569;
      font-size: 0.95rem;
      line-height: 1.5;
    """

  styled Tree = ul:
    """
      margin: 0;
      padding: 0;
      list-style: none;
    """

  styled Group = ul:
    """
      margin: 0;
      padding-left: 1.25rem;
      list-style: none;
      border-left: 1px dashed #cbd5e1;
    """

  styled Row = d:
    """
      display: flex;
      align-items: center;
      gap: 0.5rem;
      padding: 0.3rem 0.4rem;
      border-radius: 8px;
    """

  styled Twisty = button:
    """
      width: 1.5rem;
      height: 1.5rem;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      border: 1px solid #cbd5e1;
      border-radius: 6px;
      background: #f1f5f9;
      cursor: pointer;
      font-size: 0.75rem;
      line-height: 1;
    """

  styled Leaf = span:
    """
      width: 1.5rem;
      display: inline-block;
    """

  styled Label = span:
    """
      font-size: 0.95rem;
    """

  let tree: seq[TreeItem] = @[
    TreeItem(id: "src", label: "src", children: @[
      TreeItem(id: "lib", label: "lib", children: @[
        TreeItem(id: "signals", label: "signals.nim", children: @[]),
        TreeItem(id: "mount", label: "mount.nim", children: @[])
      ]),
      TreeItem(id: "ntml", label: "ntml.nim", children: @[])
    ]),
    TreeItem(id: "examples", label: "examples", children: @[
      TreeItem(id: "treeview", label: "treeview.nim", children: @[])
    ]),
    TreeItem(id: "readme", label: "README.md", children: @[])
  ]

  # Expansion state is held centrally as a comma-joined id list, mirroring how
  # examples/combobox.nim tracks a single activeIndex. One signal keeps `aria-expanded`
  # a simple `derived` per node.
  let expandedIds = signal(",src,")
  let focusedId = signal("src")

  proc isExpanded(ids, id: string): bool = ("," & id & ",") in ids

  proc toggle(id: string) =
    let ids = expandedIds.get()
    if isExpanded(ids, id):
      expandedIds.set(ids.replace("," & id & ",", ","))
    else:
      expandedIds.set(ids & id & ",")

  # Visible (reachable) ids in render order, for keyboard navigation.
  proc visibleIds(items: seq[TreeItem], ids: string, acc: var seq[string]) =
    for item in items:
      acc.add(item.id)
      if item.children.len > 0 and isExpanded(ids, item.id):
        visibleIds(item.children, ids, acc)

  proc renderItem(item: TreeItem): Node =
    let hasChildren = item.children.len > 0

    # aria-expanded MUST be a derived STRING. Binding a Signal[bool] here would give the
    # attribute presence/absence semantics -- it would be REMOVED when collapsed instead
    # of reading "false", which is exactly the defect in examples/combobox.nim. ARIA
    # requires the literal strings.
    let expandedAttr = derived(expandedIds, proc (ids: string): string =
      if isExpanded(ids, item.id): "true" else: "false")

    let selectedAttr = derived(focusedId, proc (f: string): string =
      if f == item.id: "true" else: "false")

    let twistyGlyph = derived(expandedIds, proc (ids: string): string =
      if isExpanded(ids, item.id): "-" else: "+")

    if hasChildren:
      result =
        li(
          role = "treeitem",
          id = "node-" & item.id,
          `aria-expanded` = expandedAttr,
          `aria-selected` = selectedAttr
        ):
          Row:
            Twisty(
              `type` = "button",
              `aria-label` = "Toggle " & item.label,
              onClick = proc (e: Event) =
                focusedId.set(item.id)
                toggle(item.id)
            ):
              twistyGlyph
            Label: item.label

          if derived(expandedIds, proc (ids: string): bool = isExpanded(ids, item.id)):
            Group(role = "group"):
              for kid in item.children:
                renderItem(kid)
    else:
      result =
        li(
          role = "treeitem",
          id = "node-" & item.id,
          `aria-selected` = selectedAttr
        ):
          Row:
            Leaf: ""
            Label: item.label

  let component: Node =
    Page:
      Card:
        Title: "Treeview accessibility"
        Copy:
          """A nested tree using role="tree"/"treeitem"/"group". aria-expanded is bound
          through a derived string, so a collapsed node reads "false" instead of dropping
          the attribute. Arrow keys move between visible nodes; Right/Left expand and
          collapse."""

        Tree(
          role = "tree",
          id = "filetree",
          `aria-label` = "Project files",
          tabindex = "0",
          onKeyDown = proc (e: Event) =
            let key = jsEventKey(e)
            var order: seq[string] = @[]
            visibleIds(tree, expandedIds.get(), order)
            let current = focusedId.get()
            var idx = order.find(current)
            if idx < 0: idx = 0

            case key
            of "ArrowDown":
              jsPreventDefault(e)
              if idx + 1 < order.len: focusedId.set(order[idx + 1])
            of "ArrowUp":
              jsPreventDefault(e)
              if idx - 1 >= 0: focusedId.set(order[idx - 1])
            of "ArrowRight":
              jsPreventDefault(e)
              if not isExpanded(expandedIds.get(), current): toggle(current)
            of "ArrowLeft":
              jsPreventDefault(e)
              if isExpanded(expandedIds.get(), current): toggle(current)
            else: discard
        ):
          for item in tree:
            renderItem(item)

  discard jsAppendChild(document.body, component)

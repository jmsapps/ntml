when defined(js):
  when defined(debug):
    from sequtils import mapIt

  from dom import Node, Event
  import strutils

  import constants
  import shims
  import signals
  import styled
  import tables

  import types


  # utils
  proc isBooleanAttr(k: string): bool =
    let kl = k.toLowerAscii()

    for b in BOOLEAN_ATTRS:
      if b == kl: return true

    false


  proc propKey(attr: string): cstring =
    case attr.toLowerAscii()
    of "contenteditable": "contentEditable"
    of "for", "htmlfor": "htmlFor"
    of "maxlength": "maxLength"
    of "readonly": "readOnly"
    of "tabindex": "tabIndex"
    else: cstring(attr)


  proc toBoolStr(value: string): bool =
    let v = value.toLowerAscii()
    v != "" and v != "false" and v != "0" and v != "off" and v != "no"


  proc setBooleanAttr(el: Node, k: string, on: bool) =
    jsSetProp(el, propKey(k), on)

    if on:
      jsSetAttribute(el, cstring(k), "")

    else:
      jsRemoveAttribute(el, cstring(k))


  proc setStringAttr*(el: Node, key: string, value: string) =
    let keyLowered = key.toLowerAscii()

    case keyLowered
    of "class":
      let merged = unionWithStyled(el, cstring(value))
      if merged.len == 0:
        jsRemoveAttribute(el, cstring("class"))

      else:
        jsSetAttribute(el, cstring("class"), merged)

      return

    of "value":
      jsSetProp(el, propKey(keyLowered), cstring(value))

    of "checked":
      jsSetProp(el, propKey(keyLowered), toBoolStr(value))

    else:
      if isBooleanAttr(keyLowered):
        setBooleanAttr(el, keyLowered, toBoolStr(value))

      else:
        if value.len == 0:
          case keyLowered
          of "style":
            discard

          else:
            jsSetProp(el, propKey(keyLowered), cstring(""))

          jsRemoveAttribute(el, cstring(keyLowered))

        else:
          case keyLowered
          of "style":
            discard

          else:
            jsSetProp(el, propKey(keyLowered), cstring(value))

          jsSetAttribute(el, cstring(keyLowered), cstring(value))


  proc initKeyRenderResult*(
    root: Node,
    nodes: seq[Node] = @[],
    nodePaths: seq[seq[int]] = @[],
    cleanups: seq[proc ()] = @[],
    eventBindings: seq[KeyEventBinding] = @[]
  ): KeyRenderResult =
    KeyRenderResult(
      root: root,
      nodes: nodes,
      nodePaths: nodePaths,
      cleanups: cleanups,
      eventBindings: eventBindings
    )


  proc addNode*(result: var KeyRenderResult; node: Node) =
    result.nodes.add(node)


  proc addCleanup*(result: var KeyRenderResult; cleanup: proc ()) =
    result.cleanups.add(cleanup)


  proc childIndex(parent, child: Node): int =
    result = -1
    if parent.isNil or child.isNil:
      return
    var idx = 0
    var cur = jsGetNodeProp(parent, cstring("firstChild"))
    while not cur.isNil:
      if cur == child:
        result = idx
        return
      inc idx
      cur = jsGetNodeProp(cur, cstring("nextSibling"))


  proc computeNodePath(root, node: Node): seq[int] =
    var current = node
    while not current.isNil and current != root:
      let parent = jsGetNodeProp(current, cstring("parentNode"))
      if parent.isNil:
        break
      let idx = childIndex(parent, current)
      if idx < 0:
        break
      result.insert(idx, 0)
      current = parent


  proc addEventBinding*(result: var KeyRenderResult; node: Node; eventType: cstring; handler: proc (e: Event)) =
    let path = computeNodePath(result.root, node)
    result.eventBindings.add(KeyEventBinding(
      node: node,
      nodeIndex: -1,
      path: path,
      eventType: eventType,
      handler: handler
    ))


  proc addEventBindingCurrent*(node: Node; eventType: cstring; handler: proc (e: Event)) =
    if currentKeyedResult != nil:
      addEventBinding(currentKeyedResult[], node, eventType, handler)


  proc beginKeyedCapture*(res: var KeyRenderResult) =
    currentKeyedResult = addr res
    setCleanupHook(proc (u: Unsub) =
      if u != nil and currentKeyedResult != nil:
        addCleanup(currentKeyedResult[], proc () = u())
    )


  proc endKeyedCapture*() =
    clearCleanupHook()
    currentKeyedResult = nil


  proc nodeType(n: Node): int {.inline.} = jsGetIntProp(n, cstring("nodeType"))


  proc textContentOf(n: Node): cstring {.inline.} = jsGetStringProp(n, cstring("nodeValue"))


  proc setTextContent(n: Node, v: cstring) {.inline.} = jsSetProp(n, cstring("nodeValue"), v)


  proc patchBasicElementProps(elOld, elNew: Node) =
    let newClass = jsGetStringProp(elNew, cstring("className"))
    let oldClass = jsGetStringProp(elOld, cstring("className"))

    if newClass != oldClass:
      setStringAttr(elOld, "class", $newClass)

    let newValue = jsGetStringProp(elNew, cstring("value"))
    let oldValue = jsGetStringProp(elOld, cstring("value"))

    if newValue != oldValue:
      setStringAttr(elOld, "value", $newValue)

    let newChecked = jsGetBoolProp(elNew, cstring("checked"))
    let oldChecked = jsGetBoolProp(elOld, cstring("checked"))

    if newChecked != oldChecked:
      jsSetProp(elOld, cstring("checked"), newChecked)

    let newTitle = jsGetStringProp(elNew, cstring("title"))
    let oldTitle = jsGetStringProp(elOld, cstring("title"))

    if newTitle != oldTitle:
      setStringAttr(elOld, "title", $newTitle)


  proc pushSubtreeAcc(n: Node, acc: var seq[Node]) =
    var cur = n

    while not cur.isNil:
      acc.add(cur)
      let first = jsGetNodeProp(cur, cstring("firstChild"))

      if not first.isNil:
        pushSubtreeAcc(first, acc)

      cur = jsGetNodeProp(cur, cstring("nextSibling"))


  proc collectTreeWithPaths(node: Node, basePath: seq[int], nodes: var seq[Node], paths: var seq[seq[int]]) =
    nodes.add(node)
    paths.add(basePath)
    var child = jsGetNodeProp(node, cstring("firstChild"))
    var idx = 0
    while not child.isNil:
      var nextPath = basePath
      nextPath.add(idx)
      collectTreeWithPaths(child, nextPath, nodes, paths)
      child = jsGetNodeProp(child, cstring("nextSibling"))
      inc idx


  proc collectFlatNodes(root: Node): seq[Node] =
    result = @[]

    let t = nodeType(root)

    if t == 11: # DocumentFragment
      var c = jsGetNodeProp(root, cstring("firstChild"))

      while not c.isNil:
        pushSubtreeAcc(c, result)
        c = jsGetNodeProp(c, cstring("nextSibling"))

    else:
      pushSubtreeAcc(root, result)


  proc collectNodesWithPaths(root: Node): tuple[nodes: seq[Node], paths: seq[seq[int]]] =
    result.nodes = @[]
    result.paths = @[]
    let t = nodeType(root)
    if t == 11:
      var child = jsGetNodeProp(root, cstring("firstChild"))
      var idx = 0
      while not child.isNil:
        collectTreeWithPaths(child, @[idx], result.nodes, result.paths)
        child = jsGetNodeProp(child, cstring("nextSibling"))
        inc idx
    else:
      collectTreeWithPaths(root, @[0], result.nodes, result.paths)


  proc collectBetweenWithPaths(startMarker, endMarker: Node): tuple[nodes: seq[Node], paths: seq[seq[int]]] =
    result.nodes = @[]
    result.paths = @[]
    var cur = jsGetNodeProp(startMarker, cstring("nextSibling"))
    var idx = 0
    while not cur.isNil and cur != endMarker:
      collectTreeWithPaths(cur, @[idx], result.nodes, result.paths)
      cur = jsGetNodeProp(cur, cstring("nextSibling"))
      inc idx


  proc pathKey(path: seq[int]): string =
    if path.len == 0:
      return ""
    result = $path[0]
    var i = 1
    while i < path.len:
      result.add('#')
      result.addInt(path[i])
      inc i


  proc removeDomNode(node: Node) =
    if node == nil:
      return
    let parent = jsGetNodeProp(node, cstring("parentNode"))
    if parent.isNil:
      return
    cleanupSubtree(node)
    discard jsRemoveChild(parent, node)


  proc captureSubtree*(res: var KeyRenderResult; root: Node) =
    ## Collects all nodes under `root` and appends them to `res.nodes`.
    let data = collectNodesWithPaths(root)
    for i in 0 ..< data.nodes.len:
      res.nodes.add(data.nodes[i])
      res.nodePaths.add(data.paths[i])


  proc finalizeKeyedCapture*(res: var KeyRenderResult) =
    if res.eventBindings.len == 0:
      return
    for i in 0 ..< res.eventBindings.len:
      if res.eventBindings[i].nodeIndex >= 0:
        continue
      let nodeRef = res.eventBindings[i].node
      var idx = -1
      for j in 0 ..< res.nodes.len:
        if res.nodes[j] == nodeRef:
          idx = j
          break
      res.eventBindings[i].nodeIndex = idx


  proc collectFlatBetween(startMarker, endMarker: Node): seq[Node] =
    result = @[]
    var c = jsGetNodeProp(startMarker, cstring("nextSibling"))

    while not c.isNil and c != endMarker:
      pushSubtreeAcc(c, result)
      c = jsGetNodeProp(c, cstring("nextSibling"))


  proc nthChildBetween(startMarker, endMarker: Node, idx: int): Node =
    var count = 0
    var node = jsGetNodeProp(startMarker, cstring("nextSibling"))
    while not node.isNil and node != endMarker:
      if count == idx:
        return node
      inc count
      node = jsGetNodeProp(node, cstring("nextSibling"))
    return nil


  proc childAt(parent: Node, idx: int): Node =
    if parent.isNil:
      return nil
    var count = 0
    var node = jsGetNodeProp(parent, cstring("firstChild"))
    while not node.isNil:
      if count == idx:
        return node
      inc count
      node = jsGetNodeProp(node, cstring("nextSibling"))
    return nil


  proc resolveByPath(startMarker, endMarker: Node, path: seq[int]): Node


  proc insertNodeAtPath(parentNode, startMarker, endMarker: Node, path: seq[int], node: Node) =
    if path.len == 0:
      discard jsInsertBefore(parentNode, node, endMarker)
      return
    let parentPathLen = path.len - 1
    if parentPathLen == 0:
      var target = nthChildBetween(startMarker, endMarker, path[^1])
      if target.isNil:
        discard jsInsertBefore(parentNode, node, endMarker)
      else:
        discard jsInsertBefore(parentNode, node, target)
      return
    let parentPath = path[0 ..< parentPathLen]
    let parent = resolveByPath(startMarker, endMarker, parentPath)
    if parent.isNil:
      return
    var child = childAt(parent, path[^1])
    if child.isNil:
      discard jsAppendChild(parent, node)
    else:
      discard jsInsertBefore(parent, node, child)


  proc resolveByPath(startMarker, endMarker: Node, path: seq[int]): Node =
    if path.len == 0:
      return nil
    var current = nthChildBetween(startMarker, endMarker, path[0])
    if current.isNil:
      return nil
    var i = 1
    while i < path.len:
      current = childAt(current, path[i])
      if current.isNil:
        return nil
      inc i
    current


  proc bindingKey(binding: KeyEventBinding): string =
    let ev = $binding.eventType
    if binding.nodeIndex >= 0:
      return "idx:" & $binding.nodeIndex & "|" & ev
    if binding.path.len > 0:
      var parts: seq[string] = @[]
      for v in binding.path:
        parts.add($v)
      return "path:" & parts.join("/") & "|" & ev
    return "fallback|" & ev


  proc applyEventBindings*(res: var KeyRenderResult; startMarker, endMarker: Node; liveNodes: seq[Node]; prevBindings: seq[KeyEventBinding] = @[]) =
    var prevMap = initTable[string, KeyEventBinding]()
    for prev in prevBindings:
      let key = bindingKey(prev)
      prevMap[key] = prev

    for i in 0 ..< res.eventBindings.len:
      # Path capture currently yields [] for simple keyed children; keep this call
      # so we can switch to true path-based rebinding later. Flat-index fallback
      # below does the actual work today.
      var target = resolveByPath(startMarker, endMarker, res.eventBindings[i].path)
      when defined(debug):
        let pathStr = res.eventBindings[i].path.mapIt($it).join(",")
        echo "[keyed] resolving binding #", $i, " path=[", pathStr, "] target=", (if target.isNil: "nil" else: $jsGetStringProp(target, cstring("outerHTML")))
      if target.isNil:
        let idx = res.eventBindings[i].nodeIndex
        if idx >= 0 and idx < liveNodes.len:
          target = liveNodes[idx]
        when defined(debug):
          echo "[keyed] fallback to flat idx=", $idx, " target=", (if target.isNil: "nil" else: $jsGetStringProp(target, cstring("outerHTML")))
      if target.isNil:
        continue
      let ev = res.eventBindings[i].eventType
      let key = bindingKey(res.eventBindings[i])
      if prevMap.hasKey(key):
        let prevHandler = prevMap[key].handler
        if prevHandler != nil:
          jsRemoveEventListener(target, ev, prevHandler)
      let handler = res.eventBindings[i].handler
      jsRemoveEventListener(target, ev, handler)
      jsAddEventListener(target, ev, handler)
      let remover = proc () = jsRemoveEventListener(target, ev, handler)
      registerCleanup(target, remover)
      res.cleanups.add(remover)




  proc moveRange(parentNode: Node, beforeNode: Node, startMarker: Node, endMarker: Node) =
    let frag = jsCreateFragment()
    var node = startMarker

    while true:
      let next = jsGetNodeProp(node, cstring("nextSibling"))
      discard jsAppendChild(frag, node)

      if node == endMarker:
        break

      node = next

    discard jsInsertBefore(parentNode, frag, beforeNode)


  proc toNode*(n: Node): Node = n
  proc toNode*(builder: proc (): Node {.closure.}): Node = builder()
  proc toNode*(builder: proc (): Node {.nimcall.}): Node = builder()
  proc toNode*(s: char): Node = jsCreateTextNode(cstring($s))
  proc toNode*(s: string): Node = jsCreateTextNode(cstring(s))
  proc toNode*(s: cstring): Node = jsCreateTextNode(s)
  proc toNode*(x: int): Node = jsCreateTextNode(cstring($x))
  proc toNode*(x: float): Node = jsCreateTextNode(cstring($x))
  proc toNode*(x: bool): Node = jsCreateTextNode(cstring($x))
  proc toNode*[T](x: T): Node = jsCreateTextNode(cstring($x))


  proc guardSeq*[T](xs: seq[T]): seq[T] {.inline.} = xs
  proc guardSeq*[T](xs: Signal[seq[T]]): Signal[seq[T]] {.inline.} = xs


  proc removeBetween*(parent: Node, startN, endN: Node) =
    var n = startN.nextSibling
    while n != endN and n != nil:
      let nxt = n.nextSibling

      cleanupSubtree(n)

      discard jsRemoveChild(parent, n)
      n = nxt


  proc patchEntryWithFresh*(res: var KeyRenderResult, startMarker, endMarker: Node, prevBindings: seq[KeyEventBinding] = @[]) =
    if res.root.isNil:
      return

    let parentNode = jsGetNodeProp(startMarker, cstring("parentNode"))
    if parentNode.isNil:
      return

    let oldData = collectBetweenWithPaths(startMarker, endMarker)
    let newData = collectNodesWithPaths(res.root)

    var oldMap = initTable[string, Node]()
    for idx in 0 ..< oldData.nodes.len:
      oldMap[pathKey(oldData.paths[idx])] = oldData.nodes[idx]

    for idx in 0 ..< newData.nodes.len:
      let path = newData.paths[idx]
      let key = pathKey(path)
      let newNode = newData.nodes[idx]
      if oldMap.hasKey(key):
        let existing = oldMap[key]
        let ot = nodeType(existing)
        let nt = nodeType(newNode)
        if ot == nt:
          if ot == 3 and nt == 3:
            let nv = textContentOf(newNode)
            if nv != textContentOf(existing):
              setTextContent(existing, nv)
              when defined(debug):
                echo "[keyed] patch text path=", key, " -> ", $nv
          elif ot == 1 and nt == 1:
            patchBasicElementProps(existing, newNode)
            when defined(debug):
              echo "[keyed] patch props path=", key
          else:
            removeDomNode(existing)
            insertNodeAtPath(parentNode, startMarker, endMarker, path, newNode)
            when defined(debug):
              echo "[keyed] replace node path=", key
        else:
          removeDomNode(existing)
          insertNodeAtPath(parentNode, startMarker, endMarker, path, newNode)
          when defined(debug):
            echo "[keyed] replace node path=", key
        oldMap.del(key)
      else:
        insertNodeAtPath(parentNode, startMarker, endMarker, path, newNode)
        when defined(debug):
          echo "[keyed] insert node path=", key

    for leftoverKey, node in oldMap.pairs:
      removeDomNode(node)
      when defined(debug):
        echo "[keyed] remove node path=", leftoverKey

    let updated = collectBetweenWithPaths(startMarker, endMarker)
    applyEventBindings(res, startMarker, endMarker, updated.nodes, prevBindings)
    res.nodes = updated.nodes
    res.nodePaths = updated.paths
    cleanupSubtree(res.root)


  proc toIndexSeq*[T](xs: seq[T]): seq[(int, T)] =
    result = @[]
    for i, v in xs: result.add((i, v))


  proc toIndexSeq*[T](xs: Signal[seq[T]]): Signal[seq[(int, T)]] =
    derived(xs, proc(s: seq[T]): seq[(int, T)] =
      var outSeq: seq[(int, T)] = @[]
      for i, v in s: outSeq.add((i, v))
      outSeq
    )


  proc bindValue*(el: Node, v: string) = setStringAttr(el, "value", v)
  proc bindValue*(el: Node, v: cstring) = setStringAttr(el, "value", $v)
  proc bindValue*(el: Node, v: int) = setStringAttr(el, "value", $v)
  proc bindValue*(el: Node, v: float) = setStringAttr(el, "value", $v)


  proc bindValue*(el: Node, s: Signal[string]) =
    setStringAttr(el, "value", s.get())
    let u = s.sub(proc(x: string) = jsSetProp(el, cstring("value"), cstring(x)))
    registerCleanup(el, u)
    let onInput = proc (e: Event) = s.set($jsGetProp(el, cstring("value")))
    jsAddEventListener(el, cstring("input"), onInput)
    jsAddEventListener(el, cstring("change"), onInput)


  proc bindValue*(el: Node, s: Signal[cstring]) =
    setStringAttr(el, "value", $s.get())
    let u = s.sub(proc(x: cstring) = jsSetProp(el, cstring("value"), x))
    registerCleanup(el, u)
    let onInput = proc (e: Event) = s.set(jsGetProp(el, cstring("value")))
    jsAddEventListener(el, cstring("input"), onInput)
    jsAddEventListener(el, cstring("change"), onInput)


  proc bindChecked*(el: Node, v: bool) = setBooleanAttr(el, "checked", v)

  proc bindChecked*(el: Node, s: Signal[bool]) =
    setBooleanAttr(el, "checked", s.get())
    let u = s.sub(proc(x: bool) = jsSetProp(el, cstring("checked"), x))
    registerCleanup(el, u)
    jsAddEventListener(el, cstring("change"), proc (e: Event) =
      s.set(jsGetBoolProp(el, cstring("checked")))
    )


  # Child mounts
  proc mountChild*(parent: Node, child: Node) =
    discard jsAppendChild(parent, child)

  proc mountChild*(parent: Node, builder: proc (): Node {.closure.}) =
    discard jsAppendChild(parent, toNode(builder))

  proc mountChild*(parent: Node, builder: proc (): Node {.nimcall.}) =
    discard jsAppendChild(parent, toNode(builder))


  proc mountChild*(parent: Node, child: char) =
    discard jsAppendChild(parent, jsCreateTextNode(cstring($child)))


  proc mountChild*(parent: Node, child: string) =
    discard jsAppendChild(parent, jsCreateTextNode(cstring(child)))


  proc mountChild*(parent: Node, child: cstring) =
    discard jsAppendChild(parent, jsCreateTextNode(child))


  proc mountChild*(parent: Node, child: int) =
    discard jsAppendChild(parent, jsCreateTextNode(cstring($child)))


  proc mountChild*(parent: Node, child: float) =
    discard jsAppendChild(parent, jsCreateTextNode(cstring($child)))


  proc mountChild*(parent: Node, child: bool) =
    discard jsAppendChild(parent, jsCreateTextNode(cstring($child)))


  proc mountChild*[T](parent: Node, s: Signal[T]) =
    let startN = jsCreateTextNode(cstring(""))
    let endN = jsCreateTextNode(cstring(""))
    discard jsAppendChild(parent, startN)
    discard jsAppendChild(parent, endN)

    proc render(v: T) =
      let parentNode = jsGetNodeProp(endN, cstring("parentNode"))
      if parentNode.isNil:
        return
      removeBetween(parentNode, startN, endN)
      discard jsInsertBefore(parentNode, toNode(v), endN)

    render(s.get())

    let unsub = s.sub(proc(v: T) = render(v))

    registerCleanup(startN, unsub)


  template mountChildIf*(parent: Node, cond: bool, thenN, elseN: untyped) =
    if cond:
      mountChild(parent, thenN)
    else:
      mountChild(parent, elseN)


  template mountChildIf*(parent: Node, cond: Signal[bool], thenN, elseN: untyped) =
    mountChild(parent,
      derived(cond, proc (v: bool): auto = (if v: thenN else: elseN))
    )


  template mountChildCase*[T](parent: Node, disc: T, body: untyped) =
    block:
      let tmp {.inject.} = disc
      mountChild(parent, (block:
        let caseDisc {.inject.} = tmp
        body
      ))


  template mountChildCase*[T](parent: Node, disc: Signal[T], body: untyped) =
    mountChild(parent,
      derived(disc, proc(v: T): auto = (block:
        let caseDisc {.inject.} = when T is cstring: $v else: v
        body
      ))
    )


  proc mountChildFor*[T](parent: Node, items: seq[T], render: proc (it: T): Node) =
    let startN = jsCreateTextNode(cstring(""))
    let endN = jsCreateTextNode(cstring(""))
    discard jsAppendChild(parent, startN)
    discard jsAppendChild(parent, endN)


    proc rerender(xs: seq[T]) =
      let parentNode = jsGetNodeProp(endN, cstring("parentNode"))
      if parentNode.isNil:
        return
      when defined(debug):
        echo "[keyed] keyed-rerender(seq) len=", $xs.len
      removeBetween(parentNode, startN, endN)
      let frag = jsCreateFragment()
      for it in xs:
        discard jsAppendChild(frag, render(it))
      discard jsInsertBefore(parentNode, frag, endN)

    rerender(items)


  proc mountChildFor*[T](parent: Node, items: Signal[seq[T]], render: proc (it: T): Node) =
    let startN = jsCreateTextNode(cstring(""))
    let endN = jsCreateTextNode(cstring(""))
    discard jsAppendChild(parent, startN)
    discard jsAppendChild(parent, endN)

    proc rerender(xs: seq[T]) =
      let parentNode = jsGetNodeProp(endN, cstring("parentNode"))
      if parentNode.isNil:
        return
      when defined(debug):
        echo "[keyed] keyed-rerender(signal) len=", $xs.len
      removeBetween(parentNode, startN, endN)
      let frag = jsCreateFragment()
      for it in xs:
        discard jsAppendChild(frag, render(it))
      discard jsInsertBefore(parentNode, frag, endN)

    rerender(items.get())
    let unsub = items.sub(proc (xs: seq[T]) = rerender(xs))
    registerCleanup(startN, unsub)


  proc mountChildForKeyed*[T](
    parent: Node,
    items: seq[T],
    key: proc (it: T): string,
    entryProc: proc (it: T): KeyRenderResult,
    patch: proc (startMarker: Node, endMarker: Node, prevBindings: seq[KeyEventBinding], value: T): KeyRenderResult
  ) =
    let startN = jsCreateTextNode(cstring(""))
    let endN = jsCreateTextNode(cstring(""))
    discard jsAppendChild(parent, startN)
    discard jsAppendChild(parent, endN)

    var entries = initTable[string, KeyEntry[T]]()

    proc rerender(xs: seq[T]) =
      let parentNode = jsGetNodeProp(endN, cstring("parentNode"))
      if parentNode.isNil:
        return

      var prev = entries
      entries = initTable[string, KeyEntry[T]]()
      var cursor = startN
      var dupCounts = initTable[string, int]()

      for it in xs:
        let baseKey = key(it)
        let occ = dupCounts.getOrDefault(baseKey, 0)
        dupCounts[baseKey] = occ + 1
        let keyStr = if occ == 0: baseKey else: baseKey & "#dup" & $occ

        when defined(debug):
          if occ > 0:
            echo "ntml: duplicate key '" & baseKey & "' (occurrence " & $occ & ")"

        if prev.hasKey(keyStr):
          var entry = prev[keyStr]
          prev.del(keyStr)
          var beforeNode = jsGetNodeProp(cursor, cstring("nextSibling"))

          if beforeNode.isNil:
            beforeNode = endN

          if beforeNode != entry.startMarker:
            moveRange(parentNode, beforeNode, entry.startMarker, entry.endMarker)

          var needsUpdate = true

          when compiles(entry.value == it):
            needsUpdate = entry.value != it

          if needsUpdate:
            when defined(debug):
              echo "[keyed] running ", $entry.rendered.cleanups.len, " cleanups before patch (seq)"
            for cleaner in entry.rendered.cleanups:
              if cleaner != nil:
                cleaner()
            entry.rendered.cleanups.setLen(0)
            var freshRes: KeyRenderResult
            if patch != nil:
              freshRes = patch(entry.startMarker, entry.endMarker, entry.rendered.eventBindings, it)
            else:
              freshRes = entryProc(it)
              patchEntryWithFresh(freshRes, entry.startMarker, entry.endMarker, entry.rendered.eventBindings)
            entry.rendered = freshRes

          cursor = entry.endMarker
          entry.value = it
          entries[keyStr] = entry

        else:
          let startMarker = jsCreateTextNode(cstring(""))
          let endMarker = jsCreateTextNode(cstring(""))
          var beforeNode = jsGetNodeProp(cursor, cstring("nextSibling"))

          if beforeNode.isNil:
            beforeNode = endN

          let rendered = entryProc(it)
          discard jsInsertBefore(parentNode, startMarker, beforeNode)

          if not rendered.root.isNil:
            discard jsInsertBefore(parentNode, rendered.root, beforeNode)

          discard jsInsertBefore(parentNode, endMarker, beforeNode)

          cursor = endMarker
          entries[keyStr] = KeyEntry[T](
            startMarker: startMarker,
            endMarker: endMarker,
            value: it,
            rendered: rendered
          )

      for entry in prev.values:
        let entryParent = jsGetNodeProp(entry.startMarker, cstring("parentNode"))

        if entryParent.isNil:
          continue

        for cleaner in entry.rendered.cleanups:
          if cleaner != nil:
            cleaner()

        removeBetween(entryParent, entry.startMarker, entry.endMarker)
        cleanupSubtree(entry.startMarker)
        discard jsRemoveChild(entryParent, entry.startMarker)
        cleanupSubtree(entry.endMarker)
        discard jsRemoveChild(entryParent, entry.endMarker)

    rerender(items)
    registerCleanup(startN, proc () = entries = initTable[string, KeyEntry[T]]())


  proc mountChildForKeyed*[T](
    parent: Node,
    items: Signal[seq[T]],
    key: proc (it: T): string,
    entryProc: proc (it: T): KeyRenderResult,
    patch: proc (startMarker: Node, endMarker: Node, prevBindings: seq[KeyEventBinding], value: T): KeyRenderResult
  ) =
    let startN = jsCreateTextNode(cstring(""))
    let endN = jsCreateTextNode(cstring(""))
    discard jsAppendChild(parent, startN)
    discard jsAppendChild(parent, endN)

    var entries = initTable[string, KeyEntry[T]]()

    proc rerender(xs: seq[T]) =
      let parentNode = jsGetNodeProp(endN, cstring("parentNode"))
      if parentNode.isNil:
        return

      var prev = entries
      entries = initTable[string, KeyEntry[T]]()
      var cursor = startN
      var dupCounts = initTable[string, int]()

      for it in xs:
        let baseKey = key(it)
        let occ = dupCounts.getOrDefault(baseKey, 0)
        dupCounts[baseKey] = occ + 1
        let keyStr = if occ == 0: baseKey else: baseKey & "#dup" & $occ

        when defined(debug):
          if occ > 0:
            echo "ntml: duplicate key '" & baseKey & "' (occurrence " & $occ & ")"

        if prev.hasKey(keyStr):
          var entry = prev[keyStr]
          prev.del(keyStr)
          var beforeNode = jsGetNodeProp(cursor, cstring("nextSibling"))

          if beforeNode.isNil:
            beforeNode = endN

          if beforeNode != entry.startMarker:
            moveRange(parentNode, beforeNode, entry.startMarker, entry.endMarker)

          var needsUpdate = true
          when compiles(entry.value == it): needsUpdate = entry.value != it

          if needsUpdate:
            when defined(debug):
              echo "[keyed] running ", $entry.rendered.cleanups.len, " cleanups before patch (signal)"
            for cleaner in entry.rendered.cleanups:
              if cleaner != nil:
                cleaner()
            entry.rendered.cleanups.setLen(0)
            var freshRes: KeyRenderResult
            if patch != nil:
              freshRes = patch(entry.startMarker, entry.endMarker, entry.rendered.eventBindings, it)
            else:
              freshRes = entryProc(it)
              patchEntryWithFresh(freshRes, entry.startMarker, entry.endMarker, entry.rendered.eventBindings)
            entry.rendered = freshRes

          cursor = entry.endMarker
          entry.value = it
          entries[keyStr] = entry

        else:
          let startMarker = jsCreateTextNode(cstring(""))
          let endMarker = jsCreateTextNode(cstring(""))
          var beforeNode = jsGetNodeProp(cursor, cstring("nextSibling"))

          if beforeNode.isNil:
            beforeNode = endN

          let rendered = entryProc(it)

          discard jsInsertBefore(parentNode, startMarker, beforeNode)

          if not rendered.root.isNil:
            discard jsInsertBefore(parentNode, rendered.root, beforeNode)

          discard jsInsertBefore(parentNode, endMarker, beforeNode)

          cursor = endMarker
          entries[keyStr] = KeyEntry[T](
            startMarker: startMarker,
            endMarker: endMarker,
            value: it,
            rendered: rendered
          )

      for entry in prev.values:
        let entryParent = jsGetNodeProp(entry.startMarker, cstring("parentNode"))

        if entryParent.isNil:
          continue

        for cleaner in entry.rendered.cleanups:
          if cleaner != nil:
            cleaner()

        removeBetween(entryParent, entry.startMarker, entry.endMarker)
        cleanupSubtree(entry.startMarker)
        discard jsRemoveChild(entryParent, entry.startMarker)
        cleanupSubtree(entry.endMarker)
        discard jsRemoveChild(entryParent, entry.endMarker)

    rerender(items.get())
    let unsub = items.sub(proc (xs: seq[T]) = rerender(xs))
    registerCleanup(startN, unsub)
    registerCleanup(startN, proc () = entries = initTable[string, KeyEntry[T]]())


  # Attribute mounts
  proc mountAttr*(el: Node, k: string, v: string) = setStringAttr(el, k, v)
  proc mountAttr*(el: Node, k: string, v: cstring) = setStringAttr(el, k, $v)
  proc mountAttr*(el: Node, k: string, v: bool) = setBooleanAttr(el, k, v)
  proc mountAttr*(el: Node, k: string, v: int) = setStringAttr(el, k, $v)
  proc mountAttr*(el: Node, k: string, v: float) = setStringAttr(el, k, $v)
  proc mountAttr*[T](el: Node, k: string, v: T) = setStringAttr(el, k, $v) # fallback


  proc mountAttr*(el: Node, k: string, s: Signal[string]) =
    setStringAttr(el, k, s.get())
    let u = s.sub(proc(x: string) = setStringAttr(el, k, x))
    registerCleanup(el, u)


  proc mountAttr*(el: Node, k: string, s: Signal[cstring]) =
    setStringAttr(el, k, $s.get())
    let u = s.sub(proc(x: cstring) = setStringAttr(el, k, $x))
    registerCleanup(el, u)


  proc mountAttr*(el: Node, k: string, s: Signal[bool]) =
    setBooleanAttr(el, k, s.get())
    let u = s.sub(proc(x: bool) = setBooleanAttr(el, k, x))
    registerCleanup(el, u)


  proc mountAttr*(el: Node, k: string, s: Signal[int]) =
    setStringAttr(el, k, $s.get())
    let u = s.sub(proc(x: int) = setStringAttr(el, k, $x))
    registerCleanup(el, u)


  proc mountAttr*(el: Node, k: string, s: Signal[float]) =
    setStringAttr(el, k, $s.get())
    let u = s.sub(proc(x: float) = setStringAttr(el, k, $x))
    registerCleanup(el, u)


  proc mountAttr*[T](el: Node, k: string, s: Signal[T]) =
    setStringAttr(el, k, $s.get())
    let u = s.sub(proc(x: T) = setStringAttr(el, k, $x))
    registerCleanup(el, u)


  template mountAttrIf*(el: Node, k: string, cond: bool, thenV, elseV: untyped) =
    mountAttr(el, k, (if cond: thenV else: elseV))


  template mountAttrIf*(el: Node, k: string, cond: Signal[bool], thenV, elseV: untyped) =
    mountAttr(el, k, derived(cond, proc (v: bool): auto = (if v: thenV else: elseV)))


  template mountAttrCase*[T](el: Node, k: string, disc: T, body: untyped) =
    mountAttr(el, k, (block:
      let caseDisc {.inject.} = disc
      body
    ))


  template mountAttrCase*[T](el: Node, k: string, disc: Signal[T], body: untyped) =
    mountAttr(el, k, derived(disc, proc(v: T): auto = (block:
      let caseDisc {.inject.} = v
      body
    )))

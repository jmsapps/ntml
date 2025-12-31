when defined(js):
  import macros
  import tables
  from dom import window, Event
  from strutils import startsWith, endsWith, strip, split, join

  import
    mount,
    signals,
    shims,
    types

  var routeSignal: Signal[string]
  var paramsSignal: Signal[Table[string, string]]
  var listenersRegistered = false
  var routeListener: proc (e: Event)


  proc isExternalUrl(path: string): bool =
    path.startsWith("http://") or path.startsWith("https://") or path.startsWith("//")


  proc normalizePath(path: string): string =
    var res = path

    if res.len == 0:
      return "/"

    if isExternalUrl(res) or res[0] == '#':
      return res

    if res[0] != '/':
      res = "/" & res

    if res.len > 1 and res.endsWith("/"):
      res = res[0 ..< res.len-1]

    result = res


  proc currentPath*(): string =
    var res = jsLocationPathname("/")
    if res.len == 0:
      res = "/"

    let q = jsLocationSearch("")

    if q.len > 0:
       res.add(q)

    let h = jsLocationHash("")

    if h.len > 0:
      res.add(h)

    normalizePath(res)


  proc stripQueryHash*(path: string): string =
    var res = path
    let q = res.find('?')
    let h = res.find('#')
    let cut = if q >= 0 and h >= 0: min(q, h) elif q >= 0: q elif h >= 0: h else: -1
    if cut >= 0:
      res = res[0 ..< cut]
    res


  proc extractSearch*(path: string): string =
    let q = path.find('?')
    if q < 0:
      return ""
    let h = path.find('#')
    if h >= 0 and h > q:
      return path[q ..< h]
    path[q ..^ 1]


  proc extractHash*(path: string): string =
    let h = path.find('#')
    if h < 0:
      return ""
    path[h ..^ 1]


  proc normalizeRoutePath(path: string): string =
    let base = stripQueryHash(path)
    normalizePath(base)


  proc registerRouteListeners() =
    if listenersRegistered:
      return

    routeListener = proc(e: Event) =
      if routeSignal != nil:
        routeSignal.set(currentPath())

    jsAddEventListener(window, cstring("popstate"), routeListener)
    jsAddEventListener(window, cstring("hashchange"), routeListener)

    listenersRegistered = true


  proc ensureRouteSignal*(): Signal[string] =
    if routeSignal == nil:
      routeSignal = signal(currentPath())
      registerRouteListeners()

    routeSignal


  proc ensureParamsSignal*(): Signal[Table[string, string]] =
    if paramsSignal == nil:
      paramsSignal = signal(initTable[string, string]())
    paramsSignal


  proc routeParams*(): Signal[Table[string, string]] =
    ensureParamsSignal()


  proc setRouteParams*(params: Table[string, string]) =
    ensureParamsSignal().set(params)


  proc router*(): Router =
    let loc = ensureRouteSignal()
    Router(
      location: loc,
      path: derived(loc, proc (p: string): string = normalizeRoutePath(p)),
      search: derived(loc, proc (p: string): string = extractSearch(p)),
      hash: derived(loc, proc (p: string): string = extractHash(p))
    )


  proc matchRoute*(pattern, path: string; params: var Table[string, string]): bool =
    if pattern == "*":
      return true

    let normPattern = normalizeRoutePath(pattern)
    let normPath = normalizeRoutePath(path)
    let patParts = normPattern.strip(chars={'/'}).split("/")
    let pathParts = normPath.strip(chars={'/'}).split("/")

    var i = 0
    var j = 0
    while i < patParts.len:
      let part = patParts[i]
      if part == "*":
        return true
      if j >= pathParts.len:
        return false
      if part.len > 0 and part[0] == ':':
        let key = part[1..^1]
        if key.len > 0:
          params[key] = pathParts[j]
      elif part != pathParts[j]:
        return false
      inc i
      inc j

    j == pathParts.len


  proc navigate*(path: string, replace = false) =
    var normalized = normalizePath(path)
    let base = ensureRouteSignal().get()

    if path.startsWith("+/"):
      let rel = path[2..^1]               # remove "+/"
      let joined = (if base.endsWith("/"): base & rel else: base & "/" & rel)
      normalized = normalizePath(joined)

    if path.startsWith("-/"):
      let rel = path[2..^1]
      var parts = base.strip(chars={'/'}).split("/")
      if parts.len > 0: discard parts.pop()    # go up one level
      let joined = "/" & (if parts.len > 0: parts.join("/") & "/" & rel else: rel)
      normalized = normalizePath(joined)

    if isExternalUrl(normalized):
      jsLocationAssign(normalized)

      return

    if replace:
      jsHistoryReplaceState(normalized)

    else:
      jsHistoryPushState(normalized)

    ensureRouteSignal().set(normalized)


  macro Routes*(location: typed; body: untyped): untyped =
    proc joinPath(base, seg: string): string =
      if seg.len == 0: return (if base.len == 0: "/" else: base)
      if seg[0] == '/': return seg
      if base.len == 0 or base == "/": return "/" & seg
      (if base.endsWith("/"): base & seg else: base & "/" & seg)

    var branches: seq[NimNode] = @[]
    var elseBody: NimNode = nil

    proc walk(n: NimNode; base: string) =
      for stmt in n:
        if stmt.kind in {nnkCall, nnkCommand} and $stmt[0] == "Route":
          var pathStr = ""
          var compExpr: NimNode = nil
          var children: NimNode = nil

          for i in 1 ..< stmt.len:
            let a = stmt[i]

            case a.kind
            of nnkExprEqExpr:
              let name = $a[0]

              if name == "path":
                if a[1].kind != nnkStrLit:
                  error("Route path must be a string literal", a[1])

                pathStr = a[1].strVal

              elif name == "component":
                compExpr = a[1]

            of nnkStmtList:
              children = a

            else:
              discard

          if pathStr.len == 0:
            error("Route requires path=\"...\"", stmt)

          if compExpr.isNil and (children.isNil or children.len == 0):
            error("Route requires component=... or nested child Routes", stmt)

          if pathStr == "*":
            if compExpr.isNil:
              error("Wildcard Route(path=\"*\") requires component=...", stmt)

            elseBody = compExpr

            continue

          let full = joinPath(base, pathStr)

          if not compExpr.isNil:
            branches.add(newTree(nnkOfBranch, newStrLitNode(full), compExpr))

          if not children.isNil and children.len > 0:
            walk(children, full)

        else:
          error("Only Route(...) entries are allowed inside Routes", stmt)

    walk(body, "")

    let renderSym = genSym(nskProc, "renderRoute")
    let pathSym = genSym(nskParam, "path")
    let paramsSym = genSym(nskVar, "params")

    let initTableSym = bindSym"initTable"
    let initTableCall = newCall(newTree(nnkBracketExpr, initTableSym, ident"string", ident"string"))
    var routeBody = newStmtList(
      newVarStmt(paramsSym, initTableCall),
      newCall(ident"setRouteParams", paramsSym)
    )

    for b in branches:
      let pattern = b[0]
      let compExpr = b[1]
      let compCall =
        if compExpr.kind in {nnkIdent, nnkAccQuoted, nnkSym}:
          newCall(compExpr)
        else:
          compExpr
      routeBody.add(quote do:
        `paramsSym`.clear()
        if matchRoute(`pattern`, `pathSym`, `paramsSym`):
          setRouteParams(`paramsSym`)
          return `compCall`
      )

    if not elseBody.isNil:
      let elseExpr =
        if elseBody.kind in {nnkIdent, nnkAccQuoted, nnkSym}:
          newCall(elseBody)
        else:
          elseBody
      routeBody.add(quote do:
        `paramsSym`.clear()
        setRouteParams(`paramsSym`)
        return `elseExpr`
      )
    else:
      routeBody.add(quote do:
        `paramsSym`.clear()
        setRouteParams(`paramsSym`)
        return jsCreateFragment()
      )

    let renderProc = newProc(
      name = renderSym,
      params = @[ident"Node", newIdentDefs(pathSym, ident"string")],
      body = routeBody
    )

    let pathExpr = quote do:
      normalizeRoutePath(
        (when compiles(`location`.signalValue): `location`.get() else: `location`)
      )

    result = quote do:
      block:
        `renderProc`
        when compiles(`location`.signalValue):
          block:
            let frag = jsCreateFragment()
            mountChild(frag, derived(`location`, proc (p: string): Node = `renderSym`(normalizeRoutePath(p))))
            frag
        else:
          `renderSym`(`pathExpr`)

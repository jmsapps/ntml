when defined(js):
  import dom
  import macros
  import strutils

  import ../elements
  import ../routing
  import ../types

  proc linkHrefValue(href: string): string = href
  proc linkHrefValue(href: cstring): string = $href
  proc linkHrefValue[T](href: Signal[T]): string = $href.get()
  proc linkHrefValue[T](href: T): string = $href

  proc jsEventBoolProp(e: Event, k: cstring): bool {.importjs: "Boolean(#[#])".}
  proc jsEventIntProp(e: Event, k: cstring): int {.importjs: "Number(#[#])".}
  proc jsEventCurrentTarget(e: Event): Node {.importjs: "#.currentTarget".}
  proc jsPreventDefault(e: Event) {.importjs: "#.preventDefault()".}
  proc jsGetAttr(el: Node, k: cstring): cstring {.importjs: "(#.getAttribute(#) || '')".}

  proc isExternalHref(href: string): bool =
    let trimmed = href.strip()
    if trimmed.len == 0:
      return false

    let lower = trimmed.toLowerAscii()
    lower.startsWith("http://") or
      lower.startsWith("https://") or
      lower.startsWith("//") or
      lower.startsWith("mailto:") or
      lower.startsWith("tel:") or
      lower.startsWith("sms:")

  proc shouldHandleLinkClick*(e: Event; href: string): bool =
    if href.len == 0:
      return false

    if href[0] == '#':
      return false

    if isExternalHref(href):
      return false

    if jsEventBoolProp(e, cstring("defaultPrevented")):
      return false

    if jsEventIntProp(e, cstring("button")) != 0:
      return false

    if jsEventBoolProp(e, cstring("metaKey")) or
       jsEventBoolProp(e, cstring("ctrlKey")) or
       jsEventBoolProp(e, cstring("shiftKey")) or
       jsEventBoolProp(e, cstring("altKey")):
      return false

    let el = jsEventCurrentTarget(e)
    if not el.isNil:
      let target = $jsGetAttr(el, cstring("target"))
      if target.len > 0 and target != "_self":
        return false
      let download = $jsGetAttr(el, cstring("download"))
      if download.len > 0:
        return false

    true

  macro Link*(args: varargs[untyped]): untyped =
    proc nameFromNode(n: NimNode): string {.compileTime.} =
      var raw: string
      case n.kind
      of nnkIdent, nnkSym:
        raw = n.strVal
      else:
        raw = n.repr
      if raw.len >= 2 and raw[0] == '`' and raw[^1] == '`':
        raw = raw[1 ..^ 2]
      raw.replace(" ", "")

    proc isAllowedExtraAttr(name: string): bool {.compileTime.} =
      name.startsWith("data-") or name.startsWith("aria-")

    proc isKnownAttr(name: string): bool {.compileTime.} =
      name in [
        "href", "class", "id", "title", "style", "tabindex", "target", "rel",
        "download", "css", "onClick", "replace", "role"
      ]

    var hrefExpr: NimNode = nil
    var onClickExpr: NimNode = nil
    var replaceExpr: NimNode = nil
    var forwarded: seq[NimNode] = @[]
    var children: seq[NimNode] = @[]

    for a in args:
      case a.kind
      of nnkStmtList, nnkStmtListExpr:
        for it in a:
          children.add(it)

      of nnkExprEqExpr, nnkExprColonExpr:
        let name = nameFromNode(a[0])
        if name == "href":
          hrefExpr = a[1]
          forwarded.add(a)
        elif name == "onClick":
          onClickExpr = a[1]
        elif name == "replace":
          replaceExpr = a[1]
        else:
          if name.len > 0 and not isKnownAttr(name) and not isAllowedExtraAttr(name):
            error("Link extra attributes must start with data- or aria-: " & name, a)
          forwarded.add(a)

      of nnkInfix:
        if a.len == 3 and a[0].kind == nnkIdent and $a[0] == "=":
          let name = nameFromNode(a[1])
          if name == "href":
            hrefExpr = a[2]
            forwarded.add(newTree(nnkExprEqExpr, a[1], a[2]))
          elif name == "onClick":
            onClickExpr = a[2]
          elif name == "replace":
            replaceExpr = a[2]
          else:
            if name.len > 0 and not isKnownAttr(name) and not isAllowedExtraAttr(name):
              error("Link extra attributes must start with data- or aria-: " & name, a)
            forwarded.add(newTree(nnkExprEqExpr, a[1], a[2]))
        else:
          children.add(a)

      else:
        children.add(a)

    if hrefExpr.isNil:
      error("Link requires href=...", args)

    let hrefSym = genSym(nskLet, "href")
    let replaceValue = (if replaceExpr.isNil: newLit(false) else: replaceExpr)
    let handlerExpr =
      if onClickExpr.isNil:
        quote do:
          proc (e: Event) =
            let url = linkHrefValue(`hrefSym`)
            if shouldHandleLinkClick(e, url):
              jsPreventDefault(e)
              navigate(url, `replaceValue`)
      else:
        quote do:
          proc (e: Event) =
            `onClickExpr`(e)
            let url = linkHrefValue(`hrefSym`)
            if shouldHandleLinkClick(e, url):
              jsPreventDefault(e)
              navigate(url, `replaceValue`)

    var call = newCall(ident"a")
    for a in forwarded:
      call.add(a)
    call.add(newTree(nnkExprEqExpr, ident("onClick"), handlerExpr))

    if children.len > 0:
      var body = newTree(nnkStmtList)
      for c in children:
        body.add(c)
      call.add(body)

    result = quote do:
      block:
        let `hrefSym` = `hrefExpr`
        `call`

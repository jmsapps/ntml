when defined(js):
  from dom import Node, document
  import
    macros,
    strutils,
    tables

  import
    shims,
    signals,
    types

  var
    styleNode: Node
    styleEntries: Table[string, StyleEntry] = initTable[string, StyleEntry]()
    themeStyleNode: Node
    activeThemeSignal: Signal[StyledTheme] = nil
    registeredThemeVars: seq[string] = @[]


  proc jsInsertCssRule(el: Node; rule: cstring; index: int): int {.importjs: """
    (function(el, rule, index) {
      if (!el || !el.sheet) return -1;
      var sheet = el.sheet;
      var target = (typeof index === 'number' && index >= 0)
        ? Math.min(index, sheet.cssRules.length)
        : sheet.cssRules.length;
      try {
        return sheet.insertRule(rule, target);
      } catch (err) {
        console.error(err);
        return -1;
      }
    })(#,#,#)
  """.}


  proc jsSetRuleCss(el: Node; index: int; css: cstring) {.importjs: """
    (function(el, index, css) {
      if (!el || !el.sheet) return;
      var sheet = el.sheet;
      var rule = sheet.cssRules[index];
      if (rule && rule.style) {
        rule.style.cssText = css || '';
      }
    })(#,#,#)
  """.}


  proc jsDeleteCssRule(el: Node; index: int) {.importjs: """
    (function(el, index) {
      if (!el || !el.sheet) return;
      var sheet = el.sheet;
      if (typeof index === 'number' && index >= 0 && index < sheet.cssRules.length) {
        sheet.deleteRule(index);
      }
    })(#,#)
  """.}


  proc jsMarkStyled(el: Node; cls: cstring): bool {.importjs: """
    (function(el, cls) {
      var prev = el.getAttribute('data-styled');
      if (!prev) {
        el.setAttribute('data-styled', cls);
        return true;
      }
      var tokens = prev.split(/\s+/).filter(Boolean);
      if (tokens.indexOf(cls) !== -1) return false;
      tokens.push(cls);
      el.setAttribute('data-styled', tokens.join(' '));
      return true;
    })(#,#)
  """.}


  proc jsUnionStyled(el: Node; incoming: cstring): cstring {.importjs: """
    (function(el, inc) {
      var s = el.getAttribute('data-styled') || '';
      var combo = ((inc || '') + ' ' + s).trim();
      if (!combo) return '';
      var set = new Set(combo.split(/\s+/).filter(Boolean));
      return Array.from(set).join(' ');
    })(#,#)
  """.}


  proc jsReadStyled(el: Node): cstring {.importjs: """
    (function(el) {
      if (!el || typeof el.getAttribute !== 'function') return '';
      return el.getAttribute('data-styled') || '';
    })(#)
  """.}


  proc ensureStyleNode() =
    if styleNode == nil:
      styleNode = jsCreateElement(cstring("style"))
      jsSetAttribute(styleNode, cstring("data-styled"), cstring("ntml"))
      discard jsAppendChild(document.head, styleNode)


  proc ensureEntry(cls, css: string) =
    ensureStyleNode()
    if cls notin styleEntries:
      styleEntries[cls] = StyleEntry(css: css, ruleIndex: -1, count: 0)

    elif styleEntries[cls].css != css:
      var entry = styleEntries[cls]
      entry.css = css

      if entry.count > 0 and entry.ruleIndex >= 0:
        jsSetRuleCss(styleNode, entry.ruleIndex, cstring(css))

      styleEntries[cls] = entry


  proc retainStyle(cls: string) =
    if cls notin styleEntries:
      return

    var entry = styleEntries[cls]

    if entry.count == 0:
      ensureStyleNode()
      entry.ruleIndex = jsInsertCssRule(
        styleNode,
        cstring("." & cls & "{" & entry.css & "}"),
        -1
      )

    entry.count = entry.count + 1
    styleEntries[cls] = entry


  proc releaseStyle(cls: string) =
    if cls notin styleEntries:
      return

    var entry = styleEntries[cls]

    if entry.count <= 1:
      let removedIdx = entry.ruleIndex

      styleEntries.del(cls)

      if removedIdx >= 0:
        jsDeleteCssRule(styleNode, removedIdx)
        for _, other in styleEntries.mpairs():
          if other.ruleIndex > removedIdx:
            other.ruleIndex = other.ruleIndex - 1
    else:
      entry.count = entry.count - 1
      styleEntries[cls] = entry


  proc injectCssOnce*(cls: string; css: string) =
    ensureEntry(cls, css)


  proc markStyledClass*(el: Node; cls: string) =
    # stash the styled class on a data-* so mount layer can union it
    if jsMarkStyled(el, cstring(cls)):
      retainStyle(cls)


  proc unionWithStyled*(el: Node; incoming: cstring): cstring =
    # merge incoming class string with data-styled before setting 'class'
    jsUnionStyled(el, incoming)


  proc cssVarEntry*(name: string; value: string): CssVarEntry =
    CssVarEntry(name: name, literal: value, isSignal: false)


  proc cssVarEntry*(name: string; value: Signal[string]): CssVarEntry =
    CssVarEntry(name: name, signal: value, isSignal: true)


  macro styleVars*(args: varargs[untyped]): untyped =
    if args.len == 0:
      return quote do:
        @[]

    let ctor = bindSym"cssVarEntry"
    var items = newNimNode(nnkBracket)
    for arg in args:
      if arg.kind != nnkExprEqExpr:
        error("styleVars expects entries like name = value", arg)
      items.add(newCall(ctor, arg[0], arg[1]))

    result = quote do:
      @`items`


  proc applyStyleVars*(el: Node; vars: openArray[CssVarEntry]) =
    for entry in vars:
      let varName = entry.name
      if varName.len == 0:
        continue

      proc setLiteral(value: string) =
        if value.len == 0:
          jsRemoveStyleProperty(el, cstring(varName))
        else:
          jsSetStyleProperty(el, cstring(varName), cstring(value))

      if entry.isSignal:
        if entry.signal == nil:
          continue
        setLiteral(entry.signal.get())
        let unsub = entry.signal.sub(proc (v: string) = setLiteral(v))
        registerCleanup(el, unsub)
      else:
        setLiteral(entry.literal)


  proc normalizeCssVarName(raw: string): string =
    var trimmed = raw.strip()

    if trimmed.len == 0:
      return ""

    if trimmed.startsWith("---"):
      raise newException(ValueError, "CSS variables cannot start with more than two leading hyphens: " & trimmed)

    if trimmed.startsWith("--"):
      return trimmed

    if trimmed.startsWith("-"):
      return "-" & trimmed

    "--" & trimmed


  proc ensureThemeSignal(): Signal[StyledTheme] =
    if activeThemeSignal == nil:
      activeThemeSignal = signal[StyledTheme](nil)

    activeThemeSignal


  proc ensureThemeStyleNode(): Node =
    if themeStyleNode == nil:
      themeStyleNode = jsCreateElement(cstring("style"))
      jsSetAttribute(themeStyleNode, cstring("data-styled-theme"), cstring("ntml"))
      discard jsAppendChild(document.head, themeStyleNode)

    themeStyleNode


  proc renderThemeCss(theme: StyledTheme): string =
    if registeredThemeVars.len == 0:
      return ""

    result.add(":root{")

    for name in registeredThemeVars:
      var value = "unset"

      if theme != nil and name in theme.vars:
        value = theme.vars[name]
      result.add(name)
      result.add(":")
      result.add(value)
      result.add(";")

    result.add("}")


  proc rewriteThemeStyles(theme: StyledTheme) =
    if registeredThemeVars.len == 0:
      if themeStyleNode != nil:
        jsSetProp(themeStyleNode, cstring("textContent"), cstring(""))
      return

    let css = renderThemeCss(theme)
    let node = ensureThemeStyleNode()
    jsSetProp(node, cstring("textContent"), cstring(css))


  proc newStyledTheme*(name: string; vars: openArray[(string, string)]): StyledTheme =
    new(result)
    result.name = name
    result.vars = initTable[string, string]()

    for entry in vars:
      let normalized = normalizeCssVarName(entry[0])
      if normalized.len == 0:
        continue
      result.vars[normalized] = entry[1]


  proc styledThemeSignal*(): Signal[StyledTheme] =
    ensureThemeSignal()


  proc activeTheme*(): StyledTheme =
    if activeThemeSignal == nil:
      return nil

    activeThemeSignal.get()


  proc setStyledTheme*(theme: StyledTheme) =
    ensureThemeSignal().set(theme)
    rewriteThemeStyles(theme)


  proc clearStyledTheme*() =
    setStyledTheme(nil)


  proc registerThemeVars*(names: openArray[string]) =
    var changed = false

    for raw in names:
      let normalized = normalizeCssVarName(raw)
      if normalized.len == 0:
        continue

      if normalized notin registeredThemeVars:
        registeredThemeVars.add(normalized)
        changed = true

    if changed:
      rewriteThemeStyles(activeTheme())


  proc releaseStyledFromNode(el: Node) =
    if el == nil:
      return

    let attr = $jsReadStyled(el)
    if attr.len > 0:
      for cls in attr.splitWhitespace():
        if cls.len > 0:
          releaseStyle(cls)

  addNodeDisposer(releaseStyledFromNode)


  macro defstyled*(Name, Base, CSS: untyped): untyped =
    # Defines a thin template wrapper that always injects a css attribute
    # before forwarding the rest of the arguments to the base element.
    result = quote do:
      template `Name`*(args: varargs[untyped]): untyped =
        `Base`(css = `CSS`, args)


  macro styled*(args: varargs[untyped]): untyped =
    if (
      args.len == 3 and
      args[0].kind in {nnkIdent, nnkAccQuoted} and
      args[1].kind in {nnkIdent, nnkAccQuoted}
    ):
      result = quote do:
        defstyled(`args[0]`, `args[1]`, `args[2]`)

    elif args.len == 2 and args[0].kind == nnkExprEqExpr:
      let eq = args[0]

      if eq[0].kind notin {nnkIdent, nnkAccQuoted} or eq[1].kind notin {nnkIdent, nnkAccQuoted}:
        error("styled expects identifiers on both sides of `=`", eq)
      let nameNode = eq[0]
      let baseNode = eq[1]
      let body = args[1]

      result = quote do:
        defstyled(`nameNode`, `baseNode`, `body`)

    else:
      error("styled expects `styled Name = Base: css` or `styled(Name, Base): css`", args[0])


  macro theme*(head, body: untyped): untyped =
    if head.kind notin {nnkIdent, nnkAccQuoted}:
      error("theme name must be an identifier", head)

    proc headNameStr(node: NimNode): string {.compileTime.} =
      case node.kind
      of nnkAccQuoted:
        $node[0]
      else:
        $node

    let themeNameStr = headNameStr(head)
    let exportedName = postfix(head, "*")
    let registerSym = bindSym"registerThemeVars"
    let ctorSym = bindSym"newStyledTheme"

    var namesBracket = newNimNode(nnkBracket)
    var entriesBracket = newNimNode(nnkBracket)
    var entryCount = 0

    proc normalizeKey(node: NimNode): string {.compileTime.} =
      case node.kind
      of nnkIdent, nnkAccQuoted:
        $node
      of nnkStrLit .. nnkTripleStrLit:
        node.strVal
      else:
        error("theme keys must be identifiers or string literals", node)

    for stmt in body:
      if stmt.kind notin {nnkExprEqExpr, nnkExprColonExpr, nnkAsgn}:
        error("theme entries must look like key = value", stmt)

      let rawKey = normalizeKey(stmt[0])
      if rawKey.len == 0:
        error("theme entry names cannot be empty", stmt[0])

      namesBracket.add(newLit(rawKey))
      entriesBracket.add(newTree(nnkTupleConstr, newLit(rawKey), stmt[1]))
      inc(entryCount)

    if entryCount == 0:
      error("theme requires at least one entry", body)

    let namesSeq = newTree(nnkPrefix, ident"@", namesBracket)
    let entriesSeq = newTree(nnkPrefix, ident"@", entriesBracket)

    result = quote do:
      let `exportedName` = block:
        `registerSym`(`namesSeq`)
        `ctorSym`(`themeNameStr`, `entriesSeq`)

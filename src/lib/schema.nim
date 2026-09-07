import strutils

type
  AttrFamily* = enum
    afString
    afBool
    afNumber
    afEvent

const DSL_TAGS*: array[0..112, string] = [
  "a", "abbr", "address", "area", "article", "aside", "audio", "b", "base", "bdi", "bdo",
  "blockquote", "body", "br", "button", "canvas", "caption", "cite", "code", "col",
  "colgroup", "data", "datalist", "dd", "del", "details", "dfn", "dialog", "d", "dl", "dt",
  "em", "embed", "fieldset", "figcaption", "figure", "footer", "form", "fragment", "h1",
  "h2", "h3", "h4", "h5", "h6", "head", "header", "hr", "html", "i", "iframe", "img",
  "input", "ins", "kbd", "label", "legend", "li", "link", "main", "map", "mark", "menu",
  "meta", "meter", "nav", "noscript", "obj", "ol", "optgroup", "option", "output", "p",
  "param", "picture", "pre", "progress", "q", "rp", "rt", "ruby", "s", "samp", "script",
  "section", "select", "slot", "small", "source", "span", "strong", "style", "sub",
  "summary", "sup", "svg", "table", "tbody", "td", "tmpl", "textarea", "tfoot", "th",
  "thead", "time", "title", "tr", "track", "u", "ul", "v", "video", "wbr"
]

const TAG_ALIASES*: array[0..3, (string, string)] = {
  "d": "div",
  "obj": "object",
  "tmpl": "template",
  "v": "var"
}

const GLOBAL_ATTRS*: string =
  " accesskey autocapitalize autofocus class contenteditable dir draggable enterkeyhint " &
  "hidden id inert inputmode is itemid itemprop itemref itemscope itemtype lang nonce " &
  "part popover role slot spellcheck style tabindex title translate "

const PSEUDO_ATTRS*: string = " key css stylevars cssvars customattrs "

const ATTR_PREFIXES*: array[0..1, string] = ["data-", "aria-"]

const EVENT_NAMES*: string =
  " abort animationend animationiteration animationstart auxclick beforeinput blur cancel " &
  "canplay canplaythrough change click close compositionend compositionstart " &
  "compositionupdate contextmenu copy cuechange cut dblclick drag dragend dragenter " &
  "dragleave dragover dragstart drop durationchange emptied ended error focus focusin " &
  "focusout formdata fullscreenchange gotpointercapture input invalid keydown keypress " &
  "keyup load loadeddata loadedmetadata loadstart lostpointercapture mousedown mouseenter " &
  "mouseleave mousemove mouseout mouseover mouseup mousewheel paste pause play playing " &
  "pointercancel pointerdown pointerenter pointerleave pointermove pointerout pointerover " &
  "pointerup progress ratechange reset resize scroll scrollend securitypolicyviolation " &
  "seeked seeking select selectionchange selectstart show slotchange stalled submit " &
  "suspend timeupdate toggle touchcancel touchend touchmove touchstart transitionend " &
  "volumechange waiting wheel "

const VOID_TAGS*: string =
  " area base br col embed hr img input link meta param source track wbr "

const TAG_ATTRS*: array[0..46, (string, string)] = {
  "a": " download href hreflang ping referrerpolicy rel target type ",
  "area": " alt coords download href hreflang ping referrerpolicy rel shape target ",
  "audio": " autoplay controls crossorigin loop muted preload src ",
  "base": " href target ",
  "blockquote": " cite ",
  "body": " onafterprint onbeforeprint onbeforeunload onhashchange onload onpopstate onunload ",
  "button": " disabled form formaction formenctype formmethod formnovalidate formtarget " &
            "name popovertarget popovertargetaction type value ",
  "canvas": " height width ",
  "col": " span ",
  "colgroup": " span ",
  "data": " value ",
  "del": " cite datetime ",
  "details": " name open ",
  "dialog": " open ",
  "embed": " height src type width ",
  "fieldset": " disabled form name ",
  "form": " accept-charset action autocomplete enctype method name novalidate rel target ",
  "html": " manifest ",
  "iframe": " allow allowfullscreen height loading name referrerpolicy sandbox src srcdoc width ",
  "img": " alt crossorigin decoding fetchpriority height ismap loading referrerpolicy " &
         "sizes src srcset usemap width ",
  "input": " accept alt autocomplete capture checked dirname disabled form formaction " &
           "formenctype formmethod formnovalidate formtarget height list max maxlength " &
           "min minlength multiple name pattern placeholder popovertarget " &
           "popovertargetaction readonly required size src step type value width ",
  "ins": " cite datetime ",
  "label": " for form ",
  "li": " value ",
  "link": " as color crossorigin disabled fetchpriority href hreflang imagesizes " &
          "imagesrcset integrity media referrerpolicy rel sizes type ",
  "map": " name ",
  "meta": " charset content http-equiv media name ",
  "meter": " form high low max min optimum value ",
  "object": " data form height name type usemap width ",
  "ol": " reversed start type ",
  "optgroup": " disabled label ",
  "option": " disabled label selected value ",
  "output": " for form name ",
  "param": " name value ",
  "progress": " max value ",
  "q": " cite ",
  "script": " async crossorigin defer fetchpriority integrity nomodule referrerpolicy src type ",
  "select": " autocomplete disabled form multiple name required size ",
  "slot": " name ",
  "source": " height media sizes src srcset type width ",
  "style": " media ",
  "td": " colspan headers rowspan ",
  "textarea": " autocomplete cols dirname disabled form maxlength minlength name " &
              "placeholder readonly required rows wrap ",
  "th": " abbr colspan headers rowspan scope ",
  "time": " datetime ",
  "track": " default kind label src srclang ",
  "video": " autoplay controls crossorigin height loop muted playsinline poster preload src width "
}

const BOOL_FAMILY_ATTRS*: string =
  " allowfullscreen async autofocus autoplay checked controls default defer disabled " &
  "formnovalidate hidden inert ismap itemscope loop multiple muted nomodule novalidate " &
  "open playsinline readonly required reversed selected "

const NUMBER_FAMILY_ATTRS*: string =
  " cols colspan height high low max maxlength min minlength optimum rows rowspan size " &
  "span start step tabindex value width "

proc contains(haystack, needle: string): bool =
  haystack.find(" " & needle & " ") >= 0

proc resolveTag*(name: string): string =
  for pair in TAG_ALIASES:
    if pair[0] == name:
      return pair[1]
  name

proc kebabCase(name: string): string =
  for i, c in name:
    if c in {'A' .. 'Z'}:
      if i > 0:
        result.add('-')
      result.add(chr(ord(c) + 32))

    else:
      result.add(c)

proc hasCamelHumpAfter(name, prefix: string): bool =
  name.len > prefix.len and
    name.startsWith(prefix) and
    name[prefix.len] in {'A' .. 'Z'}

proc normalizeAttrName*(name: string): string =
  if name.len == 0:
    return ""

  let lowered: string = name.toLowerAscii()

  if lowered == "classname":
    return "class"

  if lowered == "htmlfor":
    return "for"

  if hasCamelHumpAfter(name, "aria"):
    return "aria-" & name[4 .. ^1].toLowerAscii()

  if hasCamelHumpAfter(name, "data"):
    return "data-" & kebabCase(name[4 .. ^1])

  lowered

proc hasAttrPrefix*(name: string): bool =
  for prefix in ATTR_PREFIXES:
    if name.startsWith(prefix):
      return true
  false

proc isEventAttr*(rawName: string): bool =
  let name: string = rawName.toLowerAscii()
  name.len > 2 and name.startsWith("on") and EVENT_NAMES.contains(name[2 .. ^1])

proc isGlobalAttr*(name: string): bool =
  GLOBAL_ATTRS.contains(name)

proc isPseudoAttr*(name: string): bool =
  PSEUDO_ATTRS.contains(name)

proc isVoidTag*(tag: string): bool =
  VOID_TAGS.contains(tag)

proc tagAttrs*(tag: string): string =
  for pair in TAG_ATTRS:
    if pair[0] == tag:
      return pair[1]
  ""

proc isKnownTag*(tag: string): bool =
  for name in DSL_TAGS:
    if resolveTag(name) == tag:
      return true
  false

proc isAllowedAttr*(tag, rawName: string): bool =
  let name: string = normalizeAttrName(rawName)
  if name.len == 0:
    return false
  if hasAttrPrefix(name) or isPseudoAttr(name) or isEventAttr(name):
    return true
  if isGlobalAttr(name):
    return true
  tagAttrs(tag).contains(name)

proc isKnownAttrAnywhere*(rawName: string): bool =
  let name: string = normalizeAttrName(rawName)
  if isAllowedAttr("div", name):
    return true
  for pair in TAG_ATTRS:
    if pair[1].contains(name):
      return true
  false

proc familyOf*(rawName: string): AttrFamily =
  let name: string = normalizeAttrName(rawName)
  if isEventAttr(name):
    afEvent
  elif BOOL_FAMILY_ATTRS.contains(name):
    afBool
  elif NUMBER_FAMILY_ATTRS.contains(name):
    afNumber
  else:
    afString

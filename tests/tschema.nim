import harness
import strutils
import ../src/lib/schema

const USED_PAIRS = {
  "a": "href target rel download class id title style tabindex role css data-tracking aria-label",
  "button": "aria-label class disabled id onClick onFocus onKeyDown styleVars type",
  "code": "class id",
  "details": "id open",
  "div": "class data-n data-tone hidden id key style styleVars",
  "form": "class id novalidate onSubmit onsubmit",
  "h1": "class data-even",
  "h2": "class",
  "h3": "style",
  "header": "class",
  "hr": "class",
  "input": "aria-activedescendant aria-autocomplete aria-controls aria-expanded " &
           "autocomplete autofocus checked class id name onBlur onChange onFocus " &
           "onInput onKeyDown placeholder readonly required role type value",
  "label": "class for",
  "li": "aria-expanded aria-selected class id key onMouseDown role style",
  "nav": "class",
  "p": "class id",
  "section": "class",
  "span": "class data-inner id",
  "ul": "aria-label class id onKeyDown role tabindex",
  "video": "controls height id loop muted width"
}

suite "schema tag coverage":
  test "the DSL exports 113 tags":
    check DSL_TAGS.len == 113

  test "every DSL tag resolves to a known tag":
    for name in DSL_TAGS:
      check isKnownTag(resolveTag(name))

  test "every keyword alias resolves to its HTML name":
    check resolveTag("d") == "div"
    check resolveTag("obj") == "object"
    check resolveTag("tmpl") == "template"
    check resolveTag("v") == "var"

  test "a non-alias tag resolves to itself":
    check resolveTag("span") == "span"
    check resolveTag("fragment") == "fragment"

  test "every tag carrying attributes is a generated tag":
    for pair in TAG_ATTRS:
      check isKnownTag(pair[0])

  test "void tags are generated tags":
    for tag in VOID_TAGS.splitWhitespace():
      check isKnownTag(tag)

suite "schema accepts every attribute in use":
  test "every extracted tag/attribute pair is allowed":
    for pair in USED_PAIRS:
      let tag = pair[0]
      for attr in pair[1].splitWhitespace():
        check isAllowedAttr(tag, attr)

  test "className is accepted and normalizes to class":
    check normalizeAttrName("className") == "class"
    check isAllowedAttr("div", "className")

  test "pseudo attributes are accepted on every tag":
    for name in DSL_TAGS:
      let tag = resolveTag(name)
      check isAllowedAttr(tag, "key")
      check isAllowedAttr(tag, "css")
      check isAllowedAttr(tag, "styleVars")
      check isAllowedAttr(tag, "cssVars")

  test "data and aria prefixes are accepted on every tag":
    for name in DSL_TAGS:
      let tag = resolveTag(name)
      check isAllowedAttr(tag, "data-anything")
      check isAllowedAttr(tag, "aria-anything")

  test "event names are matched case-insensitively":
    check isAllowedAttr("form", "onSubmit")
    check isAllowedAttr("form", "onsubmit")
    check isAllowedAttr("form", "ONSUBMIT")
    check isEventAttr("onclick")
    check isEventAttr("onKeyDown")

suite "schema rejects what it should":
  test "an unknown attribute name is not allowed":
    check not isAllowedAttr("div", "hreff")
    check not isAllowedAttr("div", "definitelynotanattribute")

  test "a tag-specific attribute is rejected on the wrong element":
    check not isAllowedAttr("div", "href")
    check not isAllowedAttr("span", "open")
    check not isAllowedAttr("p", "novalidate")
    check not isAllowedAttr("div", "controls")

  test "a tag-specific attribute is allowed on its own element":
    check isAllowedAttr("a", "href")
    check isAllowedAttr("details", "open")
    check isAllowedAttr("form", "novalidate")
    check isAllowedAttr("video", "controls")

  test "an unknown event name is not an event":
    check not isEventAttr("onnotarealevent")
    check not isEventAttr("on")
    check not isEventAttr("online")

suite "attribute value families":
  test "boolean attributes report afBool":
    check familyOf("disabled") == afBool
    check familyOf("checked") == afBool
    check familyOf("open") == afBool
    check familyOf("hidden") == afBool

  test "numeric attributes report afNumber":
    check familyOf("width") == afNumber
    check familyOf("colspan") == afNumber
    check familyOf("tabindex") == afNumber

  test "event attributes report afEvent":
    check familyOf("onClick") == afEvent
    check familyOf("onsubmit") == afEvent

  test "everything else reports afString":
    check familyOf("class") == afString
    check familyOf("href") == afString
    check familyOf("aria-label") == afString

suite "void tags":
  test "known void elements are marked":
    for tag in ["br", "img", "input", "hr", "meta", "link", "wbr"]:
      check isVoidTag(tag)

  test "non-void elements are not marked":
    for tag in ["div", "span", "button", "ul"]:
      check not isVoidTag(tag)

finish()

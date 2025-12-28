when isMainModule and defined(js):
  import ../src/ntml

  type
    Profile = object
      name: string
      score: int


  proc OverloadShowcase(): Node =
    let a = signal(3)
    let b = signal(7)
    let s = signal("hello")
    let t = signal("world")
    let boolA = signal(true)
    let boolB = signal(false)
    let nums = signal(@[1, 2, 3, 4])
    let arrSig: Signal[array[3, int]] = signal([10, 20, 30])
    let setSig: Signal[set[char]] = signal({'a', 'b', 'c'})
    let sliceSig: Signal[HSlice[int, int]] = signal(1..5)
    let charSig = signal('e')
    let itemSig = signal(2)
    let profile = signal(Profile(name: "Ada", score: 42))
    let aValue = derived(a, proc(_: int): int = a())

    template row(label: string, value: untyped): untyped =
      d(class="row"):
        span(class="label"): label
        code(class="value"): value

    d(class="page"):
      header(class="hero"):
        h1(class="hero-title"): "Signal Overloads"
        p(class="hero-copy"):
          "Every operator overload provided by ntml signals in a single, live showcase."

      button(
        class="primary-btn",
        onClick = proc (e: Event) =
          a.set(if a() == 3: 5 else: 3)
          b.set(if b() == 7: 2 else: 7)
          s.set(if s() == "hello": "nim" else: "hello")
          t.set(if t() == "world": "flux" else: "world")
          boolA.set(not boolA())
          boolB.set(not boolB())
          nums.set(if nums()[0] == 1: @[5, 6, 7] else: @[1, 2, 3, 4])
          arrSig.set(if arrSig()[0] == 10: [5, 15, 25] else: [10, 20, 30])
          setSig.set(if 'a' in setSig(): {'x', 'y', 'z'} else: {'a', 'b', 'c'})
          sliceSig.set(if sliceSig().a == 1: 3..8 else: 1..5)
          charSig.set(if charSig() == 'e': 'a' else: 'e')
          itemSig.set(if itemSig() == 2: 3 else: 2)
          profile.set(Profile(
            name: if profile().name == "Ada": "Jules" else: "Ada",
            score: if profile().score == 42: 7 else: 42
          ))
      ):
        "Cycle values"

      d(class="grid"):
        section(class="panel"):
          h2: "Values Legend"
          row("a (Signal[int])", a)
          row("b (Signal[int])", b)
          row("s (Signal[string])", s)
          row("t (Signal[string])", t)
          row("boolA", boolA)
          row("boolB", boolB)
          row("nums", nums)
          row("arrSig", arrSig)
          row("setSig", setSig)
          row("sliceSig", sliceSig)
          row("charSig", charSig)
          row("profile.name", profile.name)
          row("profile.score", profile.score)
          row("a() overload", aValue)

        section(class="panel"):
          h2: "Comparisons"
          row("a == 3", a == 3)
          row("3 == a", 3 == a)
          row("a == b", a == b)
          row("a != 3", a != 3)
          row("3 != a", 3 != a)
          row("a != b", a != b)
          row("a < 4", a < 4)
          row("2 < a", 2 < a)
          row("a < b", a < b)
          row("a <= 3", a <= 3)
          row("3 <= a", 3 <= a)
          row("a <= b", a <= b)
          row("a > 2", a > 2)
          row("4 > a", 4 > a)
          row("a > b", a > b)
          row("a >= 3", a >= 3)
          row("3 >= a", 3 >= a)
          row("a >= b", a >= b)

        section(class="panel"):
          h2: "Boolean logic"
          row("boolA and true", boolA and true)
          row("true and boolA", true and boolA)
          row("boolA and boolB", boolA and boolB)
          row("boolA or false", boolA or false)
          row("false or boolA", false or boolA)
          row("boolA or boolB", boolA or boolB)
          row("not boolA", not boolA)

        section(class="panel"):
          h2: "Text & concat"
          row("\"hi \" & s", "hi " & s)
          row("s & \"!\"", s & "!")
          row("s & t", s & t)

        section(class="panel"):
          h2: "Indexing & len"
          row("nums[1]", nums[1])
          row("s[1]", s[1])
          row("len(nums)", len(nums))

        section(class="panel"):
          h2: "Contains: strings"
          row("s in t", s in t)
          row("s in \"hello nim\"", s in "hello nim")
          row("\"he\" in s", "he" in s)
          row("charSig in s", charSig in s)
          row("'e' in s", 'e' in s)
          row("charSig in \"hello\"", charSig in "hello")

        section(class="panel"):
          h2: "Contains: sets"
          row("'b' in setSig", 'b' in setSig)
          row("charSig in setSig", charSig in setSig)
          row("charSig in {'a','b','c'}", charSig in {'a', 'b', 'c'})

        section(class="panel"):
          h2: "Contains: seq/array"
          row("2 in nums", 2 in nums)
          row("itemSig in nums", itemSig in nums)
          row("itemSig in @[1,2,3,4]", itemSig in @[1, 2, 3, 4])
          row("20 in arrSig", 20 in arrSig)
          row("itemSig in arrSig", itemSig in arrSig)
          row("itemSig in [10,20,30]", itemSig in [10, 20, 30])

        section(class="panel"):
          h2: "Contains: ranges"
          row("3 in sliceSig", 3 in sliceSig)
          row("itemSig in sliceSig", itemSig in sliceSig)
          row("itemSig in 1..5", itemSig in 1..5)

      style:
        """
          :root {
            background: #0b1120;
            color: #e2e8f0;
            font-family: "Space Grotesk", "Avenir Next", system-ui, sans-serif;
          }

          body {
            margin: 0;
            min-height: 100vh;
            padding: 3rem 1.5rem 4rem;
            display: flex;
            justify-content: center;
            background:
              radial-gradient(circle at 20% 10%, rgba(14, 116, 144, 0.35), transparent 55%),
              radial-gradient(circle at 80% 20%, rgba(124, 58, 237, 0.25), transparent 55%),
              radial-gradient(circle at 30% 80%, rgba(236, 72, 153, 0.2), transparent 60%),
              #0b1120;
          }

          .page {
            width: min(1200px, 100%);
            display: flex;
            flex-direction: column;
            gap: 2rem;
          }

          .hero {
            display: flex;
            flex-direction: column;
            gap: 0.5rem;
          }

          .hero-title {
            margin: 0;
            font-size: clamp(2.4rem, 4vw, 3.4rem);
            letter-spacing: -0.03em;
          }

          .hero-copy {
            margin: 0;
            color: rgba(226, 232, 240, 0.75);
            max-width: 680px;
            line-height: 1.7;
          }

          .primary-btn {
            align-self: flex-start;
            border: none;
            border-radius: 999px;
            padding: 0.65rem 1.6rem;
            font-weight: 600;
            color: #0f172a;
            background: linear-gradient(120deg, #38bdf8, #facc15);
            box-shadow: 0 12px 25px rgba(56, 189, 248, 0.35);
            cursor: pointer;
          }

          .grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
            gap: 1.5rem;
          }

          .panel {
            background: rgba(15, 23, 42, 0.7);
            border: 1px solid rgba(148, 163, 184, 0.2);
            border-radius: 18px;
            padding: 1.4rem 1.4rem 1.2rem;
            box-shadow: 0 18px 30px rgba(15, 23, 42, 0.45);
            display: flex;
            flex-direction: column;
            gap: 0.75rem;
          }

          .panel h2 {
            margin: 0;
            font-size: 1.1rem;
            letter-spacing: 0.02em;
            text-transform: uppercase;
            color: rgba(226, 232, 240, 0.8);
          }

          .row {
            display: flex;
            justify-content: space-between;
            gap: 0.75rem;
            align-items: baseline;
            border-bottom: 1px solid rgba(148, 163, 184, 0.1);
            padding-bottom: 0.45rem;
          }

          .row:last-child {
            border-bottom: none;
            padding-bottom: 0;
          }

          .label {
            font-size: 0.9rem;
            color: rgba(226, 232, 240, 0.75);
          }

          .value {
            font-family: "IBM Plex Mono", "SFMono-Regular", ui-monospace, monospace;
            font-size: 0.92rem;
            padding: 0.2rem 0.45rem;
            border-radius: 8px;
            background: rgba(15, 118, 110, 0.3);
            color: #f8fafc;
            white-space: nowrap;
          }

          @media (max-width: 720px) {
            .primary-btn {
              width: 100%;
              text-align: center;
            }

            .row {
              flex-direction: column;
              align-items: flex-start;
            }

            .value {
              white-space: normal;
            }
          }
        """


  let component = OverloadShowcase()
  discard jsAppendChild(document.body, component)

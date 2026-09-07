![NTML Logo](./src/assets/ntml_logo.png)

# NTML

## The next-gen-reactive template markup language.

NTML is a reactive client-side single page application (SPA) renderer written in Nim. It provides a lightweight signal and effect system, and a JSX-like DSL for composing DOM nodes with reactive updates.

---

## Features

- **Signals**: reactive primitives for state management.
- **Derived Signals**: automatically compute values from other signals.
- **Effects**: side effects that run in response to signal changes.
- **DOM Helpers**: simple wrappers for element creation and updates.
- **Control Flow**: templates for `if`, `case`, and loops inside the DSL.
- **Component Props**: composable component definitions with inheritance support.
- **Routing**: simple and intuitive routing with `navigate()`.
- **Styled Components**: reactive `styled` macro keeps components clean and organized.
- **Form Bindings**: built-in `bindValue`/`bindChecked` wire signals to form inputs for two-way updates.
- **Lifecycle Cleanup**: automatic teardown releases subscriptions, event listeners, and styled classes when nodes unmount.
- **Signal Operators**: rich overloads let you compose comparisons and boolean logic directly on `Signal`s.
- **Reactive CSS Vars**: the `styleVars` helper keeps CSS custom properties in step with live signal data.
- **Keyed List Rendering**: efficiently reconciles list updates by reusing existing DOM nodes, preserving element identity and minimizing re-renders.

---

## Code Sample

```nim
var count: Signal[int] = signal(0)
let doubled: Signal[string] = derived(count, proc (x: int): string = $(x*2))

let component: Node =
  d(id="container"):
    "Count: "; count; br();
    "Doubled: "; doubled; br(); br();

    button(
      type="button",
      onClick = proc (e: Event) =
        count.set(count() + 1)
    ):
      "Increment"
```

## Getting started

Runnable examples are available in the `examples` directory. First start a server at the project root:

```bash
npx serve --single .
```

Add an index.html file at the project root:

```html
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Run Nim-Generated JS</title>
  </head>
  <body>
    <script src="/index.js"></script>
  </body>
</html>
```

Hello world:

```bash
nim js --out:index.js examples/helloWorld.nim
```

### Runnable Examples

- **Hello World** (`examples/helloWorld.nim`): smallest possible component render, useful for sanity-checking your toolchain.
- **Todos** (`examples/todos.nim`): reactive list management with `mountChildFor`, derived filters, two-way `<input>` bindings, and dynamic styling.
- **Forms** (`examples/forms.nim`): showcases nested signals, validation hints, and `bindValue`/`bindChecked` helpers.
- **Routing** (`examples/router.nim`): leverages `navigate()` and route signals to orchestrate multipage flows.
- **Relative Navigation** (`examples/relativeNav.nim`): `navigate("+/seg")` descends a segment, `navigate("-/seg")` replaces the last one, and both resolve against the path alone.
- **Boolean Attributes** (`examples/booleanAttrs.nim`): shows that a falsey value removes a boolean attribute instead of writing `"false"`, for both string and `Signal[bool]` values.
- **Keyed Attribute Patching** (`examples/keyedAttrs.nim`): stable keys with changing values, showing that attributes and signal subscriptions survive reconciliation.
- **Styling** (`examples/styled.nim`): demonstrates the `styled` macro, scoped CSS hashing, and reactive `styleVars`.
- **Keyed Diffs** (`examples/keyedDiffs.nim`): showcases keyed list rendering, highlighting when entries patch versus remount.
- **Effects** (`examples/effect.nim`): the `effect` explores the effect API, including cleanup, auto-runners, and delayed updates.
- **Overloads** (`examples/overloads.nim`): comprehensive showcase of signal operator overloads in one live dashboard.
- **Treeview a11y** (`examples/treeview.nim`): nested `role="tree"`/`treeitem`/`group` structure with recursive rendering, `aria-expanded` bound through a derived string, and arrow-key expand/collapse.
- **Focus & Keyboard** (`examples/focusKeyboard.nim`): roving focus across a control row with arrow keys, programmatic focus after mount, and a signal-driven focus indicator.
- **Typed Elements** (`examples/typedElements.nim`): compile-time checking of attribute names, element/attribute combinations, and value types, with `customAttrs` as the escape hatch for deliberate nonstandard attributes and ARIA booleans serializing as `"true"`/`"false"`.
- **camelCase attributes**: hyphenated names are not Nim identifiers, so `` `aria-label` `` needs backticks. Write `ariaLabel`, `dataRevealDelay` or `htmlFor` instead and they resolve to `aria-label`, `data-reveal-delay` and `for`.

### Relative navigation

`navigate()` accepts two relative prefixes alongside absolute paths:

```nim
navigate("/users/1/edit")   # absolute
navigate("+/edit")          # descend: /users/1        -> /users/1/edit
navigate("-/settings")      # replace last: /users/1   -> /users/settings
```

Both resolve against the **path only**. Any query string or hash on the current URL is
dropped rather than carried into the new route, so a stale `?tab=` cannot leak forward.
To send a query deliberately, put it on the argument — `navigate("+/edit?mode=raw")`.

Pass `replace = true` as the second argument to use `history.replaceState` instead of
pushing a new entry.

### Shared state across components

A signal declared at module scope is NTML's shared store. There is no separate store type,
provider, or dispatch layer — import the module and every component reads and writes the
same value.

```nim
# store.nim
import ntml

let theme* = signal("light")
let count* = signal(0)
```

```nim
# counter.nim
import ntml
import store

proc Counter*(): Node =
  button(class = theme, onClick = proc (e: Event) = count.set(count.get() + 1)):
    "clicked "; count
```

```nim
# readout.nim
import ntml
import store

proc Readout*(): Node =
  p: "count is "; count
```

`Counter` and `Readout` share no parent signal and never pass a value between them. A click
in one updates the other, because both are bound to the same signal.

Because a store is just a signal, everything that works on a signal works here: `set` is
the update path, `derived` composes it, and the DSL binds it in markup unchanged. Cleanup
is automatic for any signal bound through the DSL — the subscription is registered against
the node and released when that node is removed, so mounting and unmounting a subscriber
does not accumulate subscriptions on a long-lived store.

Persistence is not built in. Wire it explicitly where you want it:

```nim
proc jsGetItem(k: cstring): cstring {.importjs: "(window.localStorage.getItem(#) || '')".}
proc jsSetItem(k, v: cstring) {.importjs: "window.localStorage.setItem(#,#)".}

if jsGetItem("theme").len > 0:
  theme.set($jsGetItem("theme"))

discard theme.sub(proc (v: string) = jsSetItem("theme", cstring(v)))
```

One caveat when testing: a module-level store is created once per program, so a value
written by one test is still there in the next. Set it to a known value in each test's
setup rather than relying on its initial value.

## Testing

The suite runs headless and covers three tiers: the reactive core and router as pure logic,
a smoke sweep proving every example still renders, and behavioural tests that drive each
example in `examples/` through a real DOM and assert what it demonstrates.

```bash
nimble test        # or: ./tests/run.sh
```

Behavioural tests run in a **real headless browser** driven by Playwright: genuine clicks,
typing, keyboard input and URL assertions, against the actual `nim js` bundle each example
compiles to. The first run installs Playwright into `tests/node_modules` and downloads a
browser (test dependencies only — the published package has no dependencies).

The default engine is Chromium; `NTML_BROWSER=chromium|firefox|webkit` selects another.
All three are verified green.

Compilation is a hard gate: if any example or test module fails to compile, the run stops
before executing anything rather than testing stale build output. Build artifacts are
written outside the repository (override with `NTML_TEST_OUT`).

Examples are loaded unmodified, so the tests exercise exactly the files you run in a
browser. Adding a new example to `examples/` automatically brings it into the smoke sweep —
the list is discovered from the filesystem, not hard-coded.

## Project Status

This project is still experimental. As such, it is not currently in a state that is deemed
ready for a production environment. A roadmap can be found in `ROADMAP.md`.

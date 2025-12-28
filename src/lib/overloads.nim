when defined(js):
  {.experimental: "dotOperators".}
  {.experimental: "callOperator".}

  import strutils

  import signals
  import types


  proc combine2*[A, B, R](a: Signal[A], b: Signal[B], fn: proc(x: A, y: B): R): Signal[R] =
    let res = signal(fn(a.get(), b.get()))
    discard a.sub(proc(x: A) = res.set(fn(x, b.get())))
    discard b.sub(proc(y: B) = res.set(fn(a.get(), y)))
    res


  proc `==`*[T](a: Signal[T], b: T): Signal[bool] =
    derived(a, proc(x: T): bool = x == b)


  proc `==`*[T](a: T, b: Signal[T]): Signal[bool] =
    derived(b, proc(x: T): bool = a == x)


  proc `==`*[T](a, b: Signal[T]): Signal[bool] =
    combine2(a, b, proc(x, y: T): bool = x == y)


  proc `!=`*[T](a: Signal[T], b: T): Signal[bool] =
    derived(a, proc(x: T): bool = x != b)


  proc `!=`*[T](a: T, b: Signal[T]): Signal[bool] =
    derived(b, proc(x: T): bool = a != x)


  proc `!=`*[T](a, b: Signal[T]): Signal[bool] =
    combine2(a, b, proc(x, y: T): bool = x != y)


  proc `<`*[T](a: Signal[T], b: T): Signal[bool] =
    derived(a, proc(x: T): bool = x < b)


  proc `<`*[T](a: T, b: Signal[T]): Signal[bool] =
    derived(b, proc(x: T): bool = a < x)


  proc `<`*[T](a, b: Signal[T]): Signal[bool] =
    combine2(a, b, proc(x, y: T): bool = x < y)


  proc `<=`*[T](a: Signal[T], b: T): Signal[bool] =
    derived(a, proc(x: T): bool = x <= b)


  proc `<=`*[T](a: T, b: Signal[T]): Signal[bool] =
    derived(b, proc(x: T): bool = a <= x)


  proc `<=`*[T](a, b: Signal[T]): Signal[bool] =
    combine2(a, b, proc(x, y: T): bool = x <= y)


  proc `>`*[T](a: Signal[T], b: T): Signal[bool] =
    derived(a, proc(x: T): bool = x > b)


  proc `>`*[T](a: T, b: Signal[T]): Signal[bool] =
    derived(b, proc(x: T): bool = a > x)


  proc `>`*[T](a, b: Signal[T]): Signal[bool] =
    combine2(a, b, proc(x, y: T): bool = x > y)


  proc `>=`*[T](a: Signal[T], b: T): Signal[bool] =
    derived(a, proc(x: T): bool = x >= b)


  proc `>=`*[T](a: T, b: Signal[T]): Signal[bool] =
    derived(b, proc(x: T): bool = a >= x)


  proc `>=`*[T](a, b: Signal[T]): Signal[bool] =
    combine2(a, b, proc(x, y: T): bool = x >= y)


  proc `and`*(a: bool, b: Signal[bool]): Signal[bool] =
    derived(b, proc(y: bool): bool = a and y)


  proc `and`*(a: Signal[bool], b: bool): Signal[bool] =
    derived(a, proc(x: bool): bool = x and b)


  proc `and`*(a, b: Signal[bool]): Signal[bool] =
    combine2(a, b, proc(x, y: bool): bool = x and y)


  proc `or`*(a, b: Signal[bool]): Signal[bool] =
    combine2(a, b, proc(x, y: bool): bool = x or y)


  proc `or`*(a: bool, b: Signal[bool]): Signal[bool] =
    derived(b, proc(y: bool): bool = a or y)


  proc `or`*(a: Signal[bool], b: bool): Signal[bool] =
    derived(a, proc(x: bool): bool = x or b)


  proc `contains`*[string](a, b: Signal[string]): Signal[bool] =
    combine2(a, b, proc(x, y: string): bool = contains(x, y))


  proc `contains`*[string](a: string, b: Signal[string]): Signal[bool] =
    derived(b, proc(y: string): bool = contains(a, y))


  proc `contains`*[string](a: Signal[string], b: string): Signal[bool] =
    derived(a, proc(x: string): bool = contains(x, b))


  proc `contains`*(a: string, b: Signal[char]): Signal[bool] =
    derived(b, proc(y: char): bool = contains(a, y))


  proc `contains`*(a: Signal[string], b: char): Signal[bool] =
    derived(a, proc(x: string): bool = contains(x, b))


  proc `contains`*(a: Signal[string], b: Signal[char]): Signal[bool] =
    combine2(a, b, proc(x: string, y: char): bool = contains(x, y))


  proc `contains`*[T](a: Signal[set[T]], b: T): Signal[bool] =
    derived(a, proc(x: set[T]): bool = contains(x, b))


  proc `contains`*[T](a: set[T], b: Signal[T]): Signal[bool] =
    derived(b, proc(y: T): bool = contains(a, y))


  proc `contains`*[T](a: Signal[set[T]], b: Signal[T]): Signal[bool] =
    combine2(a, b, proc(x: set[T], y: T): bool = contains(x, y))


  proc `contains`*[T](a: Signal[seq[T]], b: T): Signal[bool] =
    derived(a, proc(x: seq[T]): bool = contains(x, b))


  proc `contains`*[T](a: seq[T], b: Signal[T]): Signal[bool] =
    derived(b, proc(y: T): bool = contains(a, y))


  proc `contains`*[T](a: Signal[seq[T]], b: Signal[T]): Signal[bool] =
    combine2(a, b, proc(x: seq[T], y: T): bool = contains(x, y))


  proc `contains`*[N: static[int], T](a: Signal[array[N, T]], b: T): Signal[bool] =
    derived(a, proc(x: array[N, T]): bool = contains(x, b))


  proc `contains`*[N: static[int], T](a: array[N, T], b: Signal[T]): Signal[bool] =
    derived(b, proc(y: T): bool = contains(a, y))


  proc `contains`*[N: static[int], T](a: Signal[array[N, T]], b: Signal[T]): Signal[bool] =
    combine2(a, b, proc(x: array[N, T], y: T): bool = contains(x, y))


  proc `contains`*[U, V, W](a: Signal[HSlice[U, V]], b: W): Signal[bool] =
    derived(a, proc(x: HSlice[U, V]): bool = contains(x, b))


  proc `contains`*[U, V, W](a: HSlice[U, V], b: Signal[W]): Signal[bool] =
    derived(b, proc(y: W): bool = contains(a, y))


  proc `contains`*[U, V, W](a: Signal[HSlice[U, V]], b: Signal[W]): Signal[bool] =
    combine2(a, b, proc(x: HSlice[U, V], y: W): bool = contains(x, y))


  proc `not`*(a: Signal[bool]): Signal[bool] =
    derived(a, proc(x: bool): bool = not x)


  proc `&`*[T](a: string, b: Signal[T]): Signal[string] =
    derived(b, proc(x: T): string = a & $x)


  proc `&`*[T](a: Signal[T], b: string): Signal[string] =
    derived(a, proc(x: T): string = $x & b)


  proc `&`*[A, B](a: Signal[A], b: Signal[B]): Signal[string] =
    combine2(a, b, proc(x: A, y: B): string = $x & $y)


  proc `[]`*[T](s: Signal[seq[T]], i: int): Signal[T] =
    derived(s, proc(xs: seq[T]): T = xs[i])


  proc `[]`*(s: Signal[string], i: int): Signal[char] =
    derived(s, proc(xs: string): char = xs[i])


  proc `()`*[T](s: Signal[T]): T =
    get(s)


  template `.`*[T](s: Signal[T], field: untyped): untyped =
    let parentSignal = s
    let childSignal = derived(parentSignal, proc (x: T): auto = x.`field`)
    childSignal.signalWriteThrough = proc (value: typeof(childSignal.get())) =
      var current = parentSignal.get()
      current.`field` = value
      parentSignal.set(current)
    childSignal


  proc `len`*[T](s: Signal[seq[T]]): Signal[int] =
    derived(s, proc(xs: seq[T]): int = len(xs))

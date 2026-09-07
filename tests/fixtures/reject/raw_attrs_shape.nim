when isMainModule and defined(js):
  import ../../../src/ntml

  proc App(): Node =
    d(customAttrs = rawAttrs("just-a-string")): "x"

  render(App())

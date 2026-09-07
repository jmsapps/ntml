when isMainModule and defined(js):
  import ../../../src/ntml

  proc App(): Node =
    d(customAttrs = "not-a-table"): "x"

  render(App())

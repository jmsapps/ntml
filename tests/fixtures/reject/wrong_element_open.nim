when isMainModule and defined(js):
  import ../../../src/ntml

  proc App(): Node =
    span(open = "true"): "x"

  render(App())

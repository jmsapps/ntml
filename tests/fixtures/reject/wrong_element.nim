when isMainModule and defined(js):
  import ../../../src/ntml

  proc App(): Node =
    d(href = "/nope"): "x"

  render(App())

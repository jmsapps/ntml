when isMainModule and defined(js):
  import ../../../src/ntml

  proc App(): Node =
    d(htmlFor = "x"): "x"

  render(App())

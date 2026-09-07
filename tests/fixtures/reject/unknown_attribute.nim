when isMainModule and defined(js):
  import ../../../src/ntml

  proc App(): Node =
    d(hreff = "/typo"): "x"

  render(App())

when isMainModule and defined(js):
  import ../../../src/ntml

  proc App(): Node =
    d(id = @[1, 2]): "x"

  render(App())

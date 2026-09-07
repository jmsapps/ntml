when isMainModule and defined(js):
  import ../../../src/ntml

  proc App(): Node =
    d:
      Link(href = "/x", bogus = "1"): "go"

  render(App())

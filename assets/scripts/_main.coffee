$ ->
  makeEditor '#editor', '#live-output', (s) -> skim.evalString(s)

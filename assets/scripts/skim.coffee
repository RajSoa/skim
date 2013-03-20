window.skim = ( ->
  parse = ( ->
    (code) -> ["TODO", ["write", "a", "parser"]]
  )()

  eval_ = ( ->
    (tree) -> tree
  )()

  inspect = ( ->
    (tree) -> JSON.stringify(tree)
  )()

  # public methods
  parse: parse
  eval: eval_
  inspect: inspect
  evalString: (s) -> inspect(eval_(parse(s)))
)()

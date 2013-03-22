window.skim = ( ->
  parse = ( ->
    { string, regex } = Parsimmon

    whitespace = regex(/^[\s\n]+/)
    comments   = regex(/^;.*?(\n|$)/)
    ignore     = (whitespace.or comments).many()

    lexeme = (p) -> p.skip(ignore)

    lparen = lexeme string('(')
    rparen = lexeme string(')')
    true_  = lexeme string('#t').result(true)
    false_ = lexeme string('#f').result(false)
    bool   = true_.or false_
    number = lexeme regex(/^-?\d+/).map(parseInt)
    word   = lexeme regex(/^[^\s()]+/)
    atom   = bool.or number.or word

    # (a s d f)
    form   = lparen.then -> expr.many().skip(rparen)
    quote  = string("'").then -> expr.map (e) -> ['quote', e]
    expr   = form.or quote.or atom

    program = ignore.then(expr.many())

    (code) -> program.parse(code)
  )()

  contMap = (list, mapper, next) ->
    accum = []
    _loop = (i) ->
      return next(accum) if i >= list.length

      mapper list[i], (value) ->
        accum.push(value)
        _loop(i+1)

    _loop(0)

  eval_ = ( ->
    class Thunk
      constructor: (@fn, @args, @_this) ->
      invoke: -> @fn.apply(@_this, @args)

      trampoline: ->
        result = @
        while result instanceof Thunk
          result = result.invoke()

        result

    thunkify = (fn) ->
      (args...) -> new Thunk(fn, args, @)

    class Env
      constructor: (@parent, @bindings) ->

      # -*- getting and setting variables -*- #

      # is (name) defined here (and not in a closure)
      has: (name) ->
        @bindings.hasOwnProperty(name)

      # gets a variable (name) from this scope or a closure
      # raise an error if undefined
      get: (name) ->
        if @has(name)
          @bindings[name]
        else if @parent
          @parent.get(name)
        else
          throw new Error("no such variable #{name}")

      # sets a variable (name) in this scope or a closure
      # raise an error if undefined
      set: (name, val) ->
        if @has(name)
          @bindings[name] = val
        else if @parent
          @parent.set(name, val)
        else
          throw new Error("no such variable #{name}")

      # adds a new binding to this scope
      define: (name, val) ->
        @bindings[name] = val

      # -*- binding new environments -*- #
      # let(['foo', 1], ['bar', 2])
      let: (pairs) -> new Env @, _.object(pairs)

      # bind(['foo', 'bar'], [1, 2])
      bind: (names, vals) -> new Env @, _.object(names, vals)

      # -*- evaluation -*- #
      eval: thunkify (expr, next) ->
        console.log 'eval', inspect(expr)
        return next(expr) if typeof expr is 'number'
        return next(expr) if typeof expr is 'boolean'
        return next(@get(expr)) if typeof expr is 'string'

        unless _.isArray(expr)
          throw new Error('unknown expression type')

        # () => ()
        return next(expr) if expr.length is 0

        if typeof expr[0] is 'string' and specialForms.hasOwnProperty(expr[0])
          specialForms[expr[0]].call(@, expr.slice(1), next)
        else
          @apply(expr, next)

      apply: (expr, next) ->
        contMap expr, ((s, n) => @eval(s, n)), (evaled) =>
          evaled[0].call(@, evaled.slice(1), thunkify next)

      evalSeq: (seq, next) ->
        console.log 'evalSeq', inspect(seq)
        contMap seq, ((e, n) => @eval(e, n)), (evaled) =>
          console.log('evaled', inspect(evaled), evaled)
          next(_.last(evaled))

      specialForms =
        if: ([cond, ifTrue, ifFalse], next) ->
          @eval cond, (condVal) =>
            if condVal isnt false and not _.isEqual(condVal, [])
              @eval(ifTrue, next)
            else
              @eval(ifFalse, next)

        define: ([name, expr], next) ->
          @eval expr, (evaled) =>
            @define(name, evaled)
            next(evaled)

        # (begin expr expr expr)
        begin: (exprs, next) ->
          @evalSeq(exprs, next)

        fn: ([argNames, body...], next) ->
          next (args, fnnext) =>
            @bind(argNames, args).evalSeq(body, fnnext)

        let: ([pairs, exprs...], next) ->
          mapper = ([k, expr], n) =>
            @eval expr, (v) -> n([k, v])

          contMap pairs, mapper, (evaledPairs) =>
            @let(evaledPairs).evalSeq(exprs, next)

        quote: ([x], next) -> next(x)

    global = new Env null,
      add: ([x, y], next) -> next(x + y)
      sub: ([x, y], next) -> next(x - y)
      mul: ([x, y], next) -> next(x * y)
      div: ([x, y], next) -> next(x / y)
      mod: ([x, y], next) -> next(x % y)
      eq:  ([x, y], next) -> next(_.isEqual(x, y))
      cons: ([x, y], next) -> next([x].concat(y))
      head: ([x], next) -> next(x[0])
      tail: ([xs], next) -> next(xs.slice(1))
      log: (args, next) ->
        console.log(inspect(args)); next([])

    (tree) -> global.eval(['begin', tree...], (x) -> x).trampoline()
  )()

  inspect = ( ->
    (tree) ->
      return tree.toString() if typeof tree is 'number'
      return tree if typeof tree is 'string'
      return '<fn>' if typeof tree is 'function'
      return '#t' if tree is true
      return '#f' if tree is false

      "(#{tree.map(inspect).join(' ')})"
  )()

  # public methods
  parse: parse
  eval: eval_
  inspect: inspect
  evalString: (s) -> inspect(eval_(parse(s)))
)()

window.makeEditor = (input, output, eval_) ->
  return if window.madeEditor
  window.madeEditor = true

  input = $(input)
  output = $(output)
  editor = CodeMirror input[0],
    mode: 'scheme'
    autofocus: true
    theme: 'cobalt'
    extraKeys:
      'Ctrl-Enter': ->
        value = eval_(editor.getValue())
        output.text(value)
      'Ctrl-;': ->
        output.text('Loading...')
        $.getScript('/application.js').done (data) ->
          output.text('')

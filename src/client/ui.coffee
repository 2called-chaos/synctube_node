window.SyncTubeClient_UI =
  init: ->
    @opts.maxWidth ?= 12
    @opts[x] ?= $("##{x}") for x in @VIEW_COMPONENTS
    @[x] = $(@opts[x]) for x in @VIEW_COMPONENTS

  start: ->
    @adjustMaxWidth()
    @captureInput()

  adjustMaxWidth: (i) ->
    hparams = @getHashParams()
    maxWidth = i || hparams.maxWidth || hparams.width || hparams.mw || @opts.maxWidth
    $("#page > .col").attr("class", "col col-#{maxWidth}")

  captureInput: ->
    @input.keydown (event) =>
      return true unless event.keyCode == 13
      return unless msg = @input.val()
      @history?.append(msg)
      @addSendCommand(msg) if msg.charAt(0) == "/"

      if m = msg.match(/^\/(?:mw|maxwidth|width)(?:\s([0-9]+))?$/i)
        i = parseInt(m[1])
        if m[1] && i >= 1 && i <= 12
          @adjustMaxWidth(@opts.maxWidth = i)
          @input.val("")
        else
          @content.append """<p>Usage: /maxwidth [1-12]</p>"""
        return
      else if m = msg.match(/^\/(?:s|sync|resync)$/i)
        @player?.force_resync = true
        @input.val("")
        return
      else if m = msg.match(/^\/clear$/i)
        @content.html("")
        @input.val("")
        return

      @connection.send(msg)
      @disableInput()

  enableInput: (focus = true, clear = true) ->
    @input.val("") if clear && @input.is(":disabled")
    @input.removeAttr("disabled")
    @input.focus() if focus
    @input

  disableInput: ->
    @input.attr("disabled", "disabled")
    @input

  addError: (error) ->
    dt = new Date()
    @content.append """
      <p>
        <strong style="color: #ee5f5b">error</strong>
        @ #{"0#{dt.getHours()}".slice(-2)}:#{"0#{dt.getMinutes()}".slice(-2)}
        <span style="color: #ee5f5b">#{error}</span>
      </p>
    """
    @content.scrollTop(@content.prop("scrollHeight"))

  addMessage: (data) ->
    dt = new Date(data.time)
    tagname = if data.author == "system" then "strong" else "span"
    @content.append """
      <p>
        <#{tagname} style="color:#{data.author_color}">#{data.author}</#{tagname}>
        @ #{"0#{dt.getHours()}".slice(-2)}:#{"0#{dt.getMinutes()}".slice(-2)}
        <span style="color: #{data.text_color}">#{data.text}</span>
      </p>
    """
    @content.scrollTop(@content.prop("scrollHeight"))

  addSendCommand: (msg) ->
    dt = new Date()
    @content.append """
      <p style="color: #7a8288">
        <span><i class="fa fa-terminal"></i></span>
        @ #{"0#{dt.getHours()}".slice(-2)}:#{"0#{dt.getMinutes()}".slice(-2)}
        <span>#{msg}</span>
      </p>
    """
    @content.scrollTop(@content.prop("scrollHeight"))


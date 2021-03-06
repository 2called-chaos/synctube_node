window.SyncTubeClient_UI =
  init: ->
    @refocus = false
    @opts.maxWidth ?= 12
    @opts[x] ?= $("##{x}") for x in @VIEW_COMPONENTS
    @[x] = $(@opts[x]) for x in @VIEW_COMPONENTS

  start: ->
    @adjustMaxWidth()
    @captureInput()
    @handleWindowResize()

  adjustMaxWidth: (i) ->
    hparams = @getHashParams()
    maxWidth = i || hparams.maxWidth || hparams.width || hparams.mw || @opts.maxWidth
    $("#page > .col").attr("class", "col col-#{maxWidth}")

  handleWindowResize: ->
    $(window).resize (ev) =>

      # playlist rattach
      if $("#first_row").width() >= 800
        unless $("#playlist").parent().attr("id") == "playlist_rattach_ctn"
          @debug "RATTACH playlist"
          $("#playlist").detach().appendTo("#playlist_rattach_ctn")
      else
        unless $("#playlist").parent().attr("id") == "playlist_ctn"
          @debug "INLINE playlist"
          $("#playlist").detach().appendTo("#playlist_ctn")

      return unless $("#page").is(":visible")

      # playlist fix
      plrc = $("#playlist_rattach_ctn")
      plre = plrc.find("#playlist")
      plrc.toggle(!!(plre.length && plre.find("> div").length && !plre.hasClass("collapsed")))

      # brute force width
      height_first  = $("#first_row").height()
      height_second = $("#second_row").height()
      height_third = $("#third_row").height()
      width_second = $("#second_row").width()
      #height_both = height_first + height_second + 30
      height_both = height_first + height_second + height_third + 30
      if height_both > window.innerHeight && width_second > 500
        $("#page").css(maxWidth: $("#page").width() - 2)
        window.scrollTo(0, 0)
        @delay 1, => $(window).resize()
      else if (window.innerHeight - height_both) > 1 && $(document).innerWidth() > $("#page").width()
        $("#page").css(maxWidth: $("#page").width() + 2)
        window.scrollTo(0, 0)
        @delay 1, => $(window).resize()

      # post scroll
      @playlist.scrollTop(@playlist.find("div.active").prop("offsetTop") - 15)
    $(window).resize()
    #setTimeout((-> $(window).resize()), 100)

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

      @connection.send(msg)
      @disableInput()

    @input.parent().click (event) => @input_nofocus.focus() if @input.is(":disabled")
    @input_nofocus.blur (event) => @refocus = false
    @input_nofocus.focus (event) => @refocus = true

    $(document).on "click", "[data-command]",  (event) =>
      el = $(event.currentTarget)
      cmd = el.data("command")
      cmd = el.data("altCommand") if event.altKey && el.data("altCommand")
      el.closest(".dropdown-menu").prev().dropdown("toggle") if el.hasClass("dropdown-item")
      @connection.send("/" + cmd)
      return false

    $(document).on "click", "[data-suggest-command]",  (event) =>
      el = $(event.currentTarget)
      cmd = el.data("suggestCommand")
      cmd = el.data("altCommand") if event.altKey && el.data("altCommand")
      el.closest(".dropdown-menu").prev().dropdown("toggle") if el.hasClass("dropdown-item")
      @input.val("/" + cmd).focus()
      return false

  enableInput: (focus = true, clear = true) ->
    @input.val("") if clear && @input.is(":disabled")
    @input.removeAttr("disabled")
    @input.focus() if @refocus && focus
    @input

  disableInput: ->
    @input.attr("disabled", "disabled")
    @input_nofocus.focus()
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

  buildPlaylistElement: (data) ->
    $ """
      <div data-pl-id="#{data.id}" data-pl-index="#{data.index}">
        <span class="first">
          <img src="" data-attr="thumbnail" data-command="pl play #{data.index}" title="play">
        </span>
        <span class="second">
          <a data-attr="name" target="_blank"></a>
          <a data-attr="author" target="_blank"></a>
          <span class="active_indicator text-danger"><i class="fa fa-circle"></i> now playing</span>
          <span class="btn-group">
            <span class="btn btn-success btn-xs" data-command="pl play #{data.index}"><i class="fa fa-play"></i></span>
            <span class="btn btn-danger btn-xs" data-command="pl remove #{data.index}"><i class="fa fa-times"></i></span>
          </span>
        </span>
      </div>
    """

  buildSubscriberElement: ->
    $ """
      <div data-client-index="">
        <div class="first">
          <span data-attr="admin-ctn"><i></i></span>
          <span data-attr="name"></span>
        </div>
        <div class="second">
          <span data-attr="icon-ctn"><i><span data-attr="progress"></span> <span data-attr="timestamp"></span></i></span>
          <span data-attr="drift-ctn" style="float:right"><i><span data-attr="drift"></span></i></span>
          <div data-attr="progress-bar"><div data-attr="progress-bar-buffered"></div><div data-attr="progress-bar-position"></div></div>
        </div>
      </div>
    """

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



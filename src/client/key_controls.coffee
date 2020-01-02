window.SyncTubeClient_KeyControls = class SyncTubeClient_KeyControls
  constructor: (@client, @opts = {}) ->
    @locked = false
    @client.CMD_ui_keylock = @CMD_ui_keylock.bind(this)
    @createDOM()
    @createCSS()
    @hook()

  CMD_ui_keylock: (data) ->
    if @locked
      @locked = false
      @cage.blur()
    else
      @cage.focus()

  hook: ->
    @cage.on "keydown keypress", (ev) =>
      @button.addClass("btn-danger") unless @button.hasClass("btn-success")
      return if ev.key == "r" && ev.metaKey || ev.controlKey
      ev.preventDefault
      false
    @cage.on "keyup", (ev) =>
      # literally escape cage
      if ev.keyCode == 27
        @locked = false
        @cage.blur()
        return

      return if @button.hasClass("btn-success")
      @button.removeClass("btn-danger")
      
      console.log "keycage PRESS: ", ev
      wouldsend = "nothing"
      unless ev.controlKey || ev.metaKey
        wouldsend = "/loop" if ev.key == "r"
        wouldsend = "/toggle" if ev.key == " " || ev.key == "k"
        wouldsend = "/seek -10" if ev.key == "ArrowLeft" || ev.key == "j"
        wouldsend = "/seek +10" if ev.key == "ArrowRight" || ev.key == "l"
        for i in [0...10]
          wouldsend = "CL-pseek #{i * 10}%" if ev.key == "#{i}"
        wouldsend = "/playlist next" if ev.key == "n"
        wouldsend = "/playlist prev" if ev.key == "p"
        wouldsend = "/speed +25%" if ev.key == "+"
        wouldsend = "/speed -25%" if ev.key == "-"
        wouldsend = "/speed 100%" if ev.key == "#"
        wouldsend = "CL-focusInput" if ev.key == "Enter"
        wouldsend = "CL-focusInputCmd" if ev.key == "/"
        wouldsend = "CL-showKeyHelp" if ev.key == "?"
        wouldsend = "CL-toggleFullscreen" if ev.key == "f"
        wouldsend = "CL-toggleSubtitles" if ev.key == "t"
        wouldsend = "CL-volume +10%" if ev.key == "ArrowUp"
        wouldsend = "CL-volume -10%" if ev.key == "ArrowDown"
        wouldsend = "CL-toggleMute" if ev.key == "m"
      @client.addError("you pressed `#{ev.key}' would send #{wouldsend}")
      if wouldsend != "nothing"
        @button.removeClass("btn-warning")
        @button.addClass("btn-success")
        @client.delay 250, =>
          @button.removeClass("btn-success")
          @button.addClass("btn-warning") unless @button.hasClass("btn-secondary")
      ev.preventDefault()
      return false
    @cage.on "blur", (ev) =>
      console.log "keycage BLUR: ", ev
      @disableButton()
      @cage.focus() if @locked
    @cage.on "focus", (ev) =>
      console.log "keycage FOCUS: ", ev
      @locked = true
      @enableButton()

  createCSS: ->
    @client.css "KeyControls", """
    #key_controls_cage {
      position: absolute;
      width: 0px;
      height: 0px;
      padding: 0px;
      border: none;
      opacity: 0;
    }
    .ui_keylock_btn {
      transition: background 100ms linear;
    }
    """

  createDOM: ->
    @button = $ """
      <button
        title="keyboard shortcut lock"
        type="button"
        data-invoke-cc="ui_keylock"
        class="btn btn-secondary btn-sm d-none d-md-inline-block ui_keylock_btn"
      ><i class="fa fa-fw fa-unlock"></i></button>
    """
    @cage = $("""<input id="key_controls_cage" type="text" tabindex="-1">""").appendTo($(".st-input-ctn"))
    $("#command_bar").prepend(@button)

  enableButton: ->
    @button.removeClass("btn-secondary").addClass("btn-warning")
    @button.find("i").removeClass("fa-unlock").addClass("fa-lock")

  disableButton: ->
    @button.removeClass("btn-warning btn-success btn-danger").addClass("btn-secondary")
    @button.find("i").removeClass("fa-lock").addClass("fa-unlock")
  

window.SyncTubeClient_KeyControls.start = ->
  @KeyControls = new SyncTubeClient_KeyControls(this, @opts.key_controls)

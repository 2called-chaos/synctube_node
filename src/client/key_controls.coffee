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
      return if ev.key == "r" && ev.metaKey || ev.controlKey
      ev.preventDefault
      false
    @cage.on "keyup", (ev) =>
      if ev.keyCode == 27
        @locked = false
        @cage.blur()
        return
      console.log "keycage PRESS: ", ev
      wouldsend = "nothing"
      wouldsend = "/toggle" if ev.key == " " || ev.key == "k"
      wouldsend = "/seek -10" if ev.key == "ArrowLeft" || ev.key == "j"
      wouldsend = "/seek +10" if ev.key == "ArrowRight" || ev.key == "l"
      @client.addError("you pressed `#{ev.key}' would send #{wouldsend}")
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
    stag = document.createElement('style')
    stag.innerHTML = """
    #key_controls_cage {
      position: absolute;
      width: 0px;
      height: 0px;
      padding: 0px;
      border: none;
      opacity: 0;
    }
    """
    document.head.appendChild(stag)

  createDOM: ->
    @button = $ """
      <button
        title="keyboard shortcut lock"
        type="button"
        data-invoke-cc="ui_keylock"
        class="btn btn-secondary btn-sm d-none d-md-inline-block"
      ><i class="fa fa-fw fa-unlock"></i></button>
    """
    @cage = $("""<input id="key_controls_cage" type="text" tabindex="-1">""").appendTo($(".st-input-ctn"))
    $("#command_bar").prepend(@button)

  enableButton: ->
    @button.removeClass("btn-secondary").addClass("btn-warning")
    @button.find("i").removeClass("fa-unlock").addClass("fa-lock")

  disableButton: ->
    @button.removeClass("btn-warning").addClass("btn-secondary")
    @button.find("i").removeClass("fa-lock").addClass("fa-unlock")
  

window.SyncTubeClient_KeyControls.start = ->
  @KeyControls = new SyncTubeClient_KeyControls(this, @opts.key_controls)

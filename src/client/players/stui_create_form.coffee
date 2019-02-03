window.SyncTubeClient_Player_StuiCreateForm = class SyncTubeClient_Player_StuiCreateForm
  ctype: "StuiCreateForm"

  constructor: (@client) ->
    @vp = $("<div>", id: "view_stui_create_form", width: "100%", height: "100%").fadeIn(3000).appendTo(@client.view)
    @buildForm()
    @clientUpdate()
    @vp.on "focus", "input,button", (ev) =>
      return if $(ev.target).attr("name") == "name"
      @vp.find("input,button").attr("data-last-focused", false)
      $(ev.target).attr("data-last-focused", true)
    @vp.on "submit", "form", (ev) =>
      fdata = $(ev.target).serializeArray()
      control = @vp.find("input[data-last-focused=true],button[data-last-focused=true]").attr("name") == "channel_password"
      data = {}
      data[fd.name] = fd.value for fd in fdata
      @vp.find(".invalid-feedback").remove()
      @vp.find("input.is-invalid").removeClass("is-invalid")

      # no name
      if !@client.name && !data.name
        $(
          """<div class="invalid-feedback">choose a name</div>"""
        ).insertAfter @vp.find("input[name=name]").addClass("is-invalid")
        return false

      # space in pw
      if (data.channel_password+"").match(/\s+/)
        $(
          """<div class="invalid-feedback">may not contain white spaces</div>"""
        ).appendTo @vp.find("input[name=channel_password]").addClass("is-invalid").parent()
        return false

      cmd = "/#{if control then "control" else "join"} #{data.channel}"
      cmd += " #{data.channel_password}" if control && data.channel_password
      if !@client.name
        @client.connection.send(data.name)
      else if data.name && @client.name != data.name
        @client.connection.send("/rename #{data.name}")
      @client.connection.send(cmd) if data.channel

      return false

  destroy: -> @vp.remove()

  buildForm: ->
    @vp.append """
    <div class="flexcentered" style="color: rgba(255, 255, 255, 0.88);">
      <div style="max-width: 800px">
        <div style="margin-bottom: 50px"><h1>Welcome to Sync<span style="color: #ff0201">Tube</span></h1></div>
        <form class="form-horizontal" id="optform" style="max-width: 400px; margin: 0px auto">
          <div class="form-group"><input type="text" class="form-control outline-danger" placeholder="username" name="name" autofocus="autofocus"></div>
          <div class="form-group text-center">and join</div>
          <div class="form-group input-group">
            <input type="text" class="form-control" placeholder="channel" name="channel">
            <div class="input-group-append">
              <button class="btn btn-outline-inverse btn-success" name="channel" type="submit" value="join">join</button>
            </div>
          </div>
          <div class="form-group text-center">or be a host</div>
          <div class="form-group input-group text-center">
            <input type="password" class="form-control" placeholder="channel password (optional)" name="channel_password">
            <div class="input-group-append">
              <button class="btn btn-outline-inverse btn-primary" type="submit" name="channel_password" value="control">create/control</button>
            </div>
          </div>
        </form>
      </div>
    </div>
    """

  clientUpdate: ->
    @vp.find("input[name=name]").val(@client.name) if @client.name

  # null api functions
  updateDesired: (data) ->
  getUrl: -> "STUI:CreateForm"
  getState: -> -1
  getLoadedFraction: -> 1
  play: ->
  pause: ->
  seekTo: (time, paused = false) ->
  getCurrentTime: ->
  getDuration: ->

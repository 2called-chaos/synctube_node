window.SyncTubeClient_Player_StuiKicked = class SyncTubeClient_Player_StuiKicked
  ctype: "StuiKicked"

  constructor: (@client) ->
    console.log @client.view
    @vp = $("<div>", id: "view_stui_kicked", width: "100%", height: "100%").fadeIn(3000).appendTo(@client.view)
    @buildView()
    @vp.on "click", "a", =>
      @client.CMD_desired(ctype: "StuiCreateForm")
      return false

  destroy: -> @vp.remove()

  buildView: ->
    @vp.append """
    <div class="flexcentered" style="color: rgba(255, 255, 255, 0.88);">
      <div style="max-width: 800px">
        <div class="alert alert-danger">
          <h1 class="alert-heading"><i class="fa fa-warning"></i> You got kicked!</h1>
          <big><strong data-reason>you got kicked by a channel or server admin</strong></big>
        </div>
        <a href="#" class="btn btn-primary" style="display: none">got it</a>
      </div>
    </div>
    """

  updateDesired: (data) ->
    @vp.find("[data-reason]").html(data.info.reason) if data.info.reason
    @vp.find("a").show() unless data.info.type == "session_kicked"

  # null api functions
  getUrl: -> "STUI:CreateForm"
  getState: -> -1
  getLoadedFraction: -> 1
  play: ->
  pause: ->
  seekTo: (time, paused = false) ->
  getCurrentTime: ->
  getDuration: ->

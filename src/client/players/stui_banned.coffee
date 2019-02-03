window.SyncTubeClient_Player_StuiBanned = class SyncTubeClient_Player_StuiBanned
  ctype: "StuiBanned"

  constructor: (@client) ->
    @vp = $("<div>", id: "view_stui_banned", width: "100%", height: "100%").fadeIn(3000).appendTo(@client.view)
    @buildView()

  destroy: -> @vp.remove()

  buildView: ->
    @vp.append """
    <div class="flexcentered" style="color: rgba(255, 255, 255, 0.88);">
      <div style="max-width: 800px">
        <div class="alert alert-danger">
          <h1 class="alert-heading"><i class="fa fa-warning"></i> You have been banned!</h1>
          <big><strong data-reason></strong></big>
          <big><strong>banned <span data-until></span></strong></big>
        </div>
      </div>
    </div>
    """

  updateDesired: (data) ->
    @vp.find("[data-reason]").html("""
      <i class="fa fa-comment fa-flip-horizontal"></i> #{reason}<hr>
    """) if reason = data.info.reason

    if data.info.banned_until
      banned_until = new Date(data.info.banned_until)
      @vp.find("[data-until]").html("until<br>#{banned_until.toString()}")
    else
      @vp.find("[data-until]").html("permanently")

  # null api functions
  getUrl: -> "STUI:CreateForm"
  getState: -> -1
  getLoadedFraction: -> 1
  play: ->
  pause: ->
  seekTo: (time, paused = false) ->
  getCurrentTime: ->
  getDuration: ->

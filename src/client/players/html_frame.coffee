window.SyncTubeClient_Player_HtmlFrame = class SyncTubeClient_Player_HtmlFrame
  ctype: "HtmlFrame"

  constructor: (@client) ->
    @state = -1
    @loaded = 0
    @frame = $("<iframe>", id: "view_frame", width: "100%", height: "100%").appendTo(@client.view)
    @frame.on "load", =>
      @state = @loaded = 1
      @client.broadcastState()

  destroy: -> @frame.remove()

  updateDesired: (data) ->
    if data.url != @frame.attr("src")
      @loaded = 0
      @state = 3
      @frame.attr("src", data.url)
      @client.broadcastState()

  getUrl: -> @frame.attr("src")
  getState: -> @state
  getLoadedFraction: -> @loaded

  # null api functions
  play: ->
  pause: ->
  seekTo: (time, paused = false) ->
  getCurrentTime: ->
  getDuration: ->

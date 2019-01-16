window.SyncTubeClient_Player_HtmlImage = class SyncTubeClient_Player_HtmlImage
  ctype: "HtmlImage"

  constructor: (@client) ->
    @state = -1
    @loaded = 0
    @image = $("<img>", id: "view_image", height: "100%").appendTo(@client.view)
    @image.on "load", =>
      @state = @loaded = 1
      @client.broadcastState()

  destroy: -> @image.remove()

  updateDesired: (data) ->
    if data.url != @image.attr("src")
      @loaded = 0
      @state = 3
      @image.attr("src", data.url)
      @client.broadcastState()

  getUrl: -> @image.attr("src")
  getState: -> @state
  getLoadedFraction: -> @loaded

  # null api functions
  play: ->
  pause: ->
  seekTo: (time, paused = false) ->
  getCurrentTime: ->
  getDuration: ->

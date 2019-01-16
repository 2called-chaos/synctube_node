# when -0 then "unstarted"
# when 0 then "ended"
# when 1 then "playing"
# when 2 then "paused"
# when 3 then "buffering"
# when 5 then "cued"
# else "ready"
window.SyncTubeClient_Player_HtmlVideo = class SyncTubeClient_Player_HtmlVideo
  ctype: "HtmlVideo"

  constructor: (@client) ->
    @video = $("<video>", id: "view_video", width: "100%", height: "100%", controls: true).appendTo(@client.view)
    @video.on "click", =>
      return unless @client.control || !@everPlayed
      if @getState() == 1 then @pause() else @play()
    #@video.on "canplay", => console.log "canplay", (new Date).toISOString()
    @video.on "canplaythrough", => @sendReady()
    @video.on "error", => @error = @video.get(0).error
    @video.on "playing", => @sendResume()
    @video.on "pause", => @sendPause() unless @getCurrentTime() == @getDuration()
    @video.on "timeupdate", => @lastKnownTime = @getCurrentTime() unless @seeking
    @video.on "ended", => @sendEnded()
    @video.on "seeking", => @seeking = true
    @video.on "seeked", (a) =>
      @seeking = false
      if @systemSeek
        @systemSeek = false
      else
        @sendSeek()

  destroy: ->
    @video.remove()
    @client.stopBroadcast()

  updateDesired: (data) ->
    if data.state == "play" then @video.attr("autoplay", "autoplay") else @video.removeAttr("autoplay")

    if data.url != @video.attr("src")
      @client.debug "switching video from", @getUrl(), "to", data.url
      @video.attr("src", data.url)
      @error = false
      @everPlayed = false
      @client.startBroadcast()
      @client.broadcastState()

    if data.loop then @video.attr("loop", "loop") else @video.removeAttr("loop")

    if !@error && @getState() == 1 && data.state != "play"
      @client.debug "pausing playback"
      @pause()
      @seekTo(data.seek, true) unless @video.get(0).seeking
      return

    if !@error && @getState() != 1 && data.state == "play"
      @client.debug "starting playback"
      @play()

    if Math.abs(@client.drift * 1000) > @client.opts.synced.maxDrift || @force_resync || data.force
      @force_resync = false
      @client.debug "seek to correct drift", @client.drift, data.seek
      @seekTo(data.seek, true) unless @getCurrentTime() == 0 && data.seek == 0

  getState: ->
    # uninitalized
    return -1 if @video.get(0).readyState == 0

    # buffering
    return 3 if @video.get(0).readyState == 2 || @video.get(0).readyState == 3

    # ended playback
    return 0 if @getCurrentTime() == @getDuration() && @video.get(0).paused

    # paused or playing
    if @video.get(0).paused
      return 2
    else if @video.get(0).readyState == 4
      return 1
    else
      return -1

  getUrl: -> @video.get(0).currentSrc
  play: -> @video.get(0).play() if @video.length
  pause: -> @video.get(0).pause() if @video.length
  getCurrentTime: -> if @seeking then @lastKnownTime else @video.get(0).currentTime
  getDuration: -> if @video.get(0).seekable.length then @video.get(0).seekable.end(0) else 0

  seekTo: (time, paused = false) ->
    @systemSeek = true
    @video.get(0).currentTime = time

  getLoadedFraction: ->
    return 0 if !@video.get(0).seekable.length || @video.get(0).seekable.end(0) == 0
    maxbuf = 0
    cur = @getCurrentTime()
    for n in [0...@video.get(0).buffered.length]
      end = @video.get(0).buffered.end(n)
      if cur >= @video.get(0).buffered.start(n) && cur <= end
        maxbuf = end
        break
      else if end > maxbuf
        maxbuf = end

    parseFloat(maxbuf) / parseFloat(@video.get(0).seekable.end(0))

  sendSeek: (time = @getCurrentTime()) ->
    @client.sendControl("/seek #{time}") unless @client.dontBroadcast

  sendReady: ->
    @client.sendControl("/ready")

  sendResume: ->
    @everPlayed = true
    @client.sendControl("/resume") unless @client.dontBroadcast

  sendPause: ->
    @client.sendControl("/pause") unless @client.dontBroadcast

  sendToggle: ->
    @client.sendControl("/toggle") unless @client.dontBroadcast

  sendEnded: ->
    @client.broadcastState()

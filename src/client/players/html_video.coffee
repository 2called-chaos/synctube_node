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
    @video.on "pause", => @sendPause() if @getCurrentTime() != @getDuration()
    @video.on "timeupdate", => @lastKnownTime = @getCurrentTime() unless @seeking
    @video.on "ended", => @sendEnded() if @getCurrentTime() == @getDuration()
    @video.on "seeking", => @seeking = true
    @video.on "seeked", (a) =>
      @seeking = false
      if @systemSeek
        @systemSeek = false
      else
        @sendSeek()

  destroy: -> @video.remove()

  updateDesired: (data) ->
    console.log data.state
    if data.state == "play" then @video.attr("autoplay", "autoplay") else @video.removeAttr("autoplay")

    if data.url != @video.attr("src")
      @client.debug "switching video from", @getUrl(), "to", data.url
      @video.attr("src", data.url)
      @error = false
      @playing = false
      @everPlayed = false
      @client.startBroadcast()
      @client.broadcastState()

    if data.loop
      @video.attr("loop", "loop")
      @play() if @getCurrentTime() == @getDuration() && @getDuration() > 0
    else
      @video.removeAttr("loop")

    if !@error && @getState() == 1 && data.state == "pause"
      @client.debug "pausing playback", data.state, data.seek, @getState()
      @systemPause = true
      @pause()
      @seekTo(data.seek, true)
      return

    if !@error && @getState() != 1 && data.state == "play"
      lastPacketDiff = if @client.lastPacketSent then (new Date()) - @client.lastPacketSent else null
      if lastPacketDiff? && lastPacketDiff < 75 && @getState() == 0
        @client.debug "ignore starting playback, stopped and we just sent packet", lastPacketDiff
      else
        @client.debug "starting playback, state:", @getState()
        @systemResume = true
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
    else if @playing
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
    maxbuf = 0
    cur = @getCurrentTime()
    dur = @getDuration()
    return 0 unless dur
    for n in [0...@video.get(0).buffered.length]
      start = @video.get(0).buffered.start(n)
      end = @video.get(0).buffered.end(n)
      if cur >= start && cur <= end
        maxbuf = end
        break
      else if end > maxbuf
        maxbuf = end

    parseFloat(maxbuf) / parseFloat(dur)

  sendSeek: (time = @getCurrentTime()) ->
    @client.sendControl("/seek #{time}") unless @client.dontBroadcast

  sendReady: ->
    @client.sendControl("/ready")

  sendResume: ->
    @everPlayed = true
    @playing = true
    if @systemResume
      @systemResume = false
    else
      @client.sendControl("/resume") unless @client.dontBroadcast
    @client.broadcastState()

  sendPause: ->
    @playing = false
    if @systemPause
      @systemPause = false
    else
      @client.sendControl("/pause") unless @client.dontBroadcast
    @client.broadcastState()

  sendEnded: ->
    @playing = false
    @client.broadcastState() if @everPlayed

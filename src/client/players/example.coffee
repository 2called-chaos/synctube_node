# This is a example template for a new player and their required interface methods.
# This example is based on HtmlPlayer, check out the other players as well.
window.SyncTubeClient_Player_Example = class SyncTubeClient_Player_Example
  # required, must correlate to the class name
  ctype: "Example"

  # set up your player as far as you can without data
  # You will always need @client so don't remove the constructor entirely!
  constructor: (@client) ->
    throw "This is just an example, don't use as player in production"

    # example <video> tag
    @video = $("<video>", id: "view_video", width: "100%", height: "100%", controls: true).appendTo(@client.view)
    @video.on "playing", => @sendResume()
    @video.on "pause", => @sendPause() if @getCurrentTime() != @getDuration()

  # Must cleanup so that the view is in pristine condition.
  # broadcastInterval and client.dontBroadcast will be cleared automatically.
  destroy: -> @video.remove()

  # Must update on what to do, called after init, control actions or periodic updates
  updateDesired: (data) ->
    # detect changed source
    if data.url != @video.attr("src")
      # switch URL
      @client.debug "switching video from", @getUrl(), "to", data.url
      @video.attr("src", data.url)

      # broadcast every <config.packetInterval> milliseconds
      @client.startBroadcast()

      # broadcast once immediately
      @client.broadcastState()

    # set loop
    if data.loop
      @video.attr("loop", "loop")

      # auto replay if video already ended
      @play() if @getCurrentTime() == @getDuration() && @getDuration() > 0
    else
      @video.removeAttr("loop")

    # detect playback status change from play to pause
    if !@error && @getState() == 1 && data.state == "pause"
      @client.debug "pausing playback", data.state, data.seek, @getState()
      @pause()
      @seekTo(data.seek, true)
      return

    # detect playback status change from pause to play
    if !@error && @getState() != 1 && data.state == "play"
      @client.debug "starting playback"
      @play()

    # correct seek drift, you are expected to implement @force_resync and data.force as well
    if Math.abs(@client.drift * 1000) > @client.opts.synced.maxDrift || @force_resync || data.force
      @force_resync = false
      @client.debug "seek to correct drift", @client.drift, data.seek
      @seekTo(data.seek, true) unless @getCurrentTime() == 0 && data.seek == 0

  # Should start playback
  play: -> @video.get(0).play() if @video.length

  # Should pause playback
  pause: -> @video.get(0).pause() if @video.length

  # Should seek to given position, if necessary ensure paused state
  seekTo: (time, paused = false) -> @video.get(0).currentTime = time

  # Must return a numeric value, the comments show you which number results in which displayed status
  getState: ->
    # when -1 then "unstarted"
    # when 0 then "ended"
    # when 1 then "playing"
    # when 2 then "paused"
    # when 3 then "buffering"
    # when 5 then "cued"
    # else "ready"

  # Must return the current URL in the same fashion as the server sends it (e.g. only ID for youtube)
  getUrl: -> @video.get(0).currentSrc

  # Should return current client position as float or int
  getCurrentTime: -> if @seeking then @lastKnownTime else @video.get(0).currentTime

  # Should return total media duration as float or int
  getDuration: -> if @video.get(0).seekable.length then @video.get(0).seekable.end(0) else 0

  # Should return a float 0..1 representing the percentage buffered
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

window.SyncTubeClient_Player_Youtube = class SyncTubeClient_Player_Youtube
  ctype: "Youtube"

  constructor: (@client) ->

  destroy: ->
    @rememberVolume()
    @api?.destroy()
    @api = null
    @pauseEnsured("player destroy")

  sendSeek: (time = @getCurrentTime()) ->
    @client.sendControl("/seek #{time}") unless @client.dontBroadcast

  sendReady: ->
    @client.sendControl("/ready")

  updateDesired: (data) ->
    @desired = data
    @rememberVolume()
    unless @api
      @loadVideo(data.url, data.state != "play", data.seek)
      @ensurePause(data)
      return

    current_ytid = @getUrl()?.match(/([A-Za-z0-9_\-]{11})/)?[0]
    if (current_ytid != data.url || data.forceLoad) && !@disableSourceSync
      return unless current_ytid?
      @client.debug "switching video from", current_ytid, "to", data.url
      @loadVideo(data.url)
      @ensurePause(data) if data.state == "pause"
      return

    if @getState() == 1 && data.state == "pause"
      @client.debug "pausing playback, state:", @getState()
      @pause()
      @seekTo(data.seek, true)
      @ensurePause(data)
      return

    if @getState() != 1 && data.state == "play"
      lastPacketDiff = if @client.lastPacketSent then (new Date()) - @client.lastPacketSent else null
      if lastPacketDiff? && lastPacketDiff < 75 && @getState() == 0
        @client.debug "ignore starting playback, stopped and we just sent packet", lastPacketDiff
      else
        @client.debug "starting playback, state:", @getState()
        @pauseEnsured "starting playback"
        @play()
      return

    if @client.getHashParams().controlSeek
      if (@getState() == 1 || @getState() == 2) && !@client.host && @client.control
        if Math.abs(data.seek - @getCurrentTime()) * 1000 >= @client.opts.synced.maxDrift * 2
          @client.debug "control client wants to seek?", data.seek, data.seek - @getCurrentTime()
          @sendSeek()
          return

    if Math.abs(@client.drift * 1000) > @client.opts.synced.maxDrift || @force_resync || data.force
      @force_resync = false
      @client.debug "seek to correct drift", @client.drift, data.seek, @getState()
      @seekTo(data.seek, true) unless @getCurrentTime() == 0 && data.seek == 0

      # ensure paused player at correct position when it was cued
      # seekTo on a cued video will start playback delayed
      @ensurePause(data)

    if !@client.host && @getState() > 1 && data.seek != @getCurrentTime()
      @client.debug "fine seeking in non playing state", data.seek, data.seek - @getCurrentTime()
      @pauseEnsured("fineseek")
      @seekTo(data.seek, true)


  seekTo: (time, paused = false) ->
    @client.debug "seeking", time, "paused", paused, "was", @getCurrentTime(), "delta", time - @getCurrentTime()
    @api?.seekTo?(time, true)
    if paused
      @player?.pause()
    else
      @player?.play()

  getState: -> if @api?.getPlayerState? then @api.getPlayerState() else -1
  play: -> @api?.playVideo?()
  pause: -> @api?.pauseVideo?()
  getCurrentTime: -> if @api?.getCurrentTime? then @api.getCurrentTime() else 0
  getDuration: -> if @api?.getDuration? then @api.getDuration() else 0
  getLoadedFraction: -> if @api?.getVideoLoadedFraction? then @api.getVideoLoadedFraction() else 0
  getUrl: -> @api?.getVideoUrl?()?.match(/([A-Za-z0-9_\-]{11})/)?[0]

  # ----------------------

  loadYTAPI: (callback) ->
    if document.YouTubeIframeAPIHasLoaded
      callback?()
      return

    window.onYouTubeIframeAPIReady = =>
      document.YouTubeIframeAPIHasLoaded = true
      callback?()

    tag = document.createElement('script')
    tag.src = "https://www.youtube.com/iframe_api"
    firstScriptTag = document.getElementsByTagName('script')[0]
    firstScriptTag.parentNode.insertBefore(tag, firstScriptTag)

  loadVideo: (ytid, cue = false, seek = 0) ->
    if m = ytid.match(/([A-Za-z0-9_\-]{11})/)
      ytid = m[1]
    else
      throw "unknown ID"

    @loadYTAPI =>
      if @api
        if cue
          @api.cueVideoById?(ytid, seek)
        else
          @api.loadVideoById?(ytid, seek)
        return @api
      else
        @api = new YT.Player 'view',
          videoId: ytid
          height: '100%'
          width: '100%'
          #playerVars: controls: 0
          events:
            onReady: (ev) =>
              # restore saved volume
              vol = @client.history?.LSload("player_volume")
              if vol?
                @client.debug "Restored player volume #{vol}"
                @api.setVolume(vol)

              if cue
                @api.cueVideoById(ytid, seek)
              else
                @seekTo(seek)
                @play()
              @client.broadcastState(ev.data)
              @lastPlayerState = if @getState()? then @getState() else 2
              @client.startBroadcast()
            onStateChange: (ev) =>
              newState = @getState()
              if !@client.dontBroadcast && @lastPlayerState? && ([-1, 2].indexOf(@lastPlayerState) > -1 && [1, 3].indexOf(newState) > -1)
                console.log "send resume", @lastPlayerState, newState
                @client.sendControl("/resume")
              else if !@client.dontBroadcast && @lastPlayerState? && ([1, 3].indexOf(@lastPlayerState) > -1 && [2].indexOf(newState) > -1)
                console.log "send pause", @getCurrentTime()
                @client.sendControl("/pause")
              console.log "state", "was", @lastPlayerState, "is", newState

              @lastPlayerState = newState
              @client.broadcastState(ev.data)


  ensurePause: (data) ->
    @client.dontBroadcast = true

    fails = 0
    clearInterval(@ensurePauseInterval)
    @ensurePauseInterval = setInterval((=>
      unless @getState()?
        @pauseEnsured("giving up after #{fails} attempts") if (fails += 1) > 100
        return
      return @pauseEnsured("not paused") unless data.state == "pause"
      #return @pauseEnsured("state not 5 or -1 (#{@getState()})") unless [5, -1].indexOf(@getState()) > -1
      return @pauseEnsured("timecode 0") if @getCurrentTime() == 0 && data.seek == 0 && [1, 3].indexOf(@getState()) == -1

      if [-1, 2].indexOf(@getState()) > -1 && Math.abs(@getCurrentTime() - data.seek) <= 0.5
        @pauseEnsured("drift done after #{fails} attempts")
        @client.broadcastState()
      else
        @seekTo(data.seek, true)
        @play() && @pause()
        @pauseEnsured("giving up after #{fails} attempts") if (fails += 1) > 100
    ), 100)

  pauseEnsured: (reason) ->
    @client.debug "YT pause ensured (#{reason})"
    clearInterval(@ensurePauseInterval)
    @client.dontBroadcast = false
    @sendReady()

  rememberVolume: ->
    return unless @client.history?
    vol = @api?.getVolume?()
    stored = @client.history.LSload("player_volume")
    if vol? && (!stored? || stored != vol)
      @client.debug "Remembered player volume #{vol}"
      @client.history.LSsave("player_volume", vol)

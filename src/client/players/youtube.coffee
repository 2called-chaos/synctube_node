window.SyncTubeClient_Player_Youtube = class SyncTubeClient_Player_Youtube
  ctype: "Youtube"

  constructor: (@client) ->

  destroy: ->
    @api?.destroy()
    @api = null
    @pauseEnsured()

  updateDesired: (data) ->
    unless @api
      @loadVideo(data.url, data.state != "play", data.seek)
      @ensurePause(data)
      return

    current_ytid = @getUrl()?.match(/([A-Za-z0-9_\-]{11})/)?[0]
    if current_ytid != data.url
      @client.debug "switching video from", current_ytid, "to", data.url
      @loadVideo(data.url)
      return

    if @getState() == 1 && data.state != "play"
      @client.debug "pausing playback, state:", @getState()
      @pause()
      @seekTo(data.seek, true)
      return

    if @getState() != 1 && data.state == "play"
      @client.debug "starting playback, state:", @getState()
      @play()
      return

    if Math.abs(@client.drift * 1000) > @client.opts.synced.maxDrift || @force_resync || data.force
      @force_resync = false
      @client.debug "seek to correct drift", @client.drift, data.seek, @getState()
      @seekTo(data.seek, true) unless @getCurrentTime() == 0 && data.seek == 0

      # ensure paused player at correct position when it was cued
      # seekTo on a cued video will start playback delayed
      @ensurePause(data)

  seekTo: (time, paused = false) ->
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
          @api.cueVideoById(ytid, seek)
        else
          @api.loadVideoById(ytid, seek)
        return @api
      else
        @api = new YT.Player 'view',
          videoId: ytid
          height: '100%'
          width: '100%'
          #playerVars: controls: 0
          events:
            onReady: (ev) =>
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
                console.log "send pause"
                @client.sendControl("/pause")
              console.log "state", "was", @lastPlayerState, "is", newState

              @lastPlayerState = newState
              @client.broadcastState(ev.data)


  ensurePause: (data) ->
    @client.dontBroadcast = true

    fails = 0
    @ensurePauseInterval = setInterval((=>
      return fails += 1 unless @getState()?
      return @pauseEnsured() unless data.state == "pause"
      return @pauseEnsured() unless [5, -1].indexOf(@getState()) > -1
      return @pauseEnsured() if @getCurrentTime() == 0 && data.seek == 0

      if [-1, 2].indexOf(@getState()) > -1 && Math.abs(@getCurrentTime() - data.seek) <= 0.5
        @pauseEnsured()
        @client.broadcastState()
      else
        @seekTo(data.seek, true)
        @play() && @pause()
        @pauseEnsured() if (fails += 1) > 40
    ), 100)

  pauseEnsured: ->
    clearInterval(@ensurePauseInterval)
    @client.dontBroadcast = false

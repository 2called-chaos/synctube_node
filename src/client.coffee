window.SyncTubeClient = class SyncTubeClient
  VIEW_COMPONENTS: ["content", "view", "input", "status", "queue", "playlist", "clients"]

  debug: (msg...) ->
    return unless @opts.debug
    msg.unshift "[ST #{(new Date).toISOString()}]"
    console.debug.apply(@, msg)

  warn: (msg...) ->
    msg.unshift "[ST #{(new Date).toISOString()}]"
    console.warn.apply(@, msg)

  error: (msg...) ->
    msg.unshift "[ST #{(new Date).toISOString()}]"
    console.error.apply(@, msg)

  constructor: (@opts = {}) ->
    # options
    @opts.debug ?= false
    @opts.maxWidth ?= 12
    @opts[x] ?= $("##{x}") for x in @VIEW_COMPONENTS

    # synced settings (controlled by server)
    @opts.synced ?= {}
    @opts.synced.maxDrift ?= 60 # superseded by server instructions
    @opts.synced.packetInterval ?= 10000 # superseded by server instructions

    # DOM
    @[x] = $(@opts[x]) for x in @VIEW_COMPONENTS

    # connection options
    @opts.wsIp ?= $("meta[name=synctube-server-ip]").attr("content")
    @opts.wsPort ?= $("meta[name=synctube-server-port]").attr("content")

    # Client data
    @name = null
    @index = null
    @drift = 0

  getHashParams: ->
    result = {}
    if window.location.hash
      parts = window.location.hash.substr(1).split("&")
      for kv in parts
        kvp = kv.split("=")
        key = kvp.shift()
        result[key] = kvp.join("=")
    result

  start: ->
    @adjustMaxWidth()
    @openWSconnection()
    @detectBrokenConnection()
    @captureInput()
    @listen()

  adjustMaxWidth: (i) ->
    hparams = @getHashParams()
    maxWidth = i || hparams.maxWidth || hparams.width || hparams.mw || @opts.maxWidth
    $("#page > .col").attr("class", "col col-#{maxWidth}")

  openWSconnection: ->
    # mozilla fallback
    window.WebSocket = window.WebSocket || window.MozWebSocket

    # if browser doesn't support WebSocket, just show some notification and exit
    unless window.WebSocket
      @content.html $("<p>", text: "Sorry, but your browser doesn't support WebSocket.")
      @status.hide()
      @input.hide()
      return

    # open connection
    address = "ws://#{@opts.wsIp}:#{@opts.wsPort}/cable"
    @debug "Opening connection to #{address}"
    @connection = new WebSocket(address)

    @connection.onopen = => @debug "WS connection opened"
    @connection.onerror = (error) =>
      @error "WS connection encountered an error", error
      @content.html $("<p>", text: "Sorry, but there's some problem with your connection or the server is down.")

  detectBrokenConnection: ->
    setInterval((=>
      if @connection.readyState != 1
        @status.text("Error")
        @disableInput().val("Unable to communicate with the WebSocket server. Please reload!")
        setTimeout((-> window.location.reload()), 1000)
    ), 3000)

  captureInput: ->
    @input.keydown (event) =>
      return true unless event.keyCode == 13
      return unless msg = @input.val()

      if m = msg.match(/^\/(?:mw|maxwidth|width)(?:\s([0-9]+))?$/i)
        i = parseInt(m[1])
        if m[1] && i >= 1 && i <= 12
          @adjustMaxWidth(@opts.maxWidth = i)
          @input.val("")
        else
          @content.append """<p>Usage: /maxwidth [1-12]</p>"""
        return
      else if m = msg.match(/^\/(?:s|sync|resync)$/i)
        @force_resync = true
        @input.val("")
        return

      @connection.send(msg)
      @disableInput().val("")

  listen: ->
    @connection.onmessage = (message) =>
      try
        json = JSON.parse(message.data)
      catch error
        @error "Invalid JSON", message.data, error
        return

      switch json.type
        when "code"
          #@debug "received CODE", json.data
          if @["CMD_#{json.data.type}"]?
            @["CMD_#{json.data.type}"](json.data)
          else
            @warn "no client implementation for CMD_#{json.data.type}"
        when "message"
          #@debug "received MESSAGE", json.data
          @addMessage(json.data)
        else
          @warn "Hmm..., I've never seen JSON like this:", json

  enableInput: (focus = true) ->
    @input.removeAttr("disabled")
    @input.focus() if focus
    @input

  disableInput: ->
    @input.attr("disabled", "disabled")
    @input

  addMessage: (data) ->
    dt = new Date(data.time)
    tagname = if data.author == "system" then "strong" else "span"
    @content.append """
      <p>
        <#{tagname} style="color:#{data.author_color}">#{data.author}</#{tagname}>
        @ #{"0#{dt.getHours()}".slice(-2)}:#{"0#{dt.getMinutes()}".slice(-2)}
        <span style="color: #{data.text_color}">#{data.text}</span>
      </p>
    """
    @content.scrollTop(@content.prop("scrollHeight"))

  # =============
  # = YT Player =
  # =============
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

  loadVideo: (ytid, cue = false) ->
    if m = ytid.match(/([A-Za-z0-9_\-]{11})/)
      ytid = m[1]
    else
      throw "unknown ID"

    @loadYTAPI =>
      if @player
        if cue
          @player.cueVideoById(ytid)
        else
          @player.loadVideoById(ytid)
        return @player
      else
        window.player = @player = new YT.Player 'view',
          videoId: ytid
          height: '100%'
          width: '100%'
          events:
            onReady: (ev) =>
              @player.playVideo() unless cue
              @broadcastState(ev)
              @lastPlayerState = if @player?.getPlayerState()? then @player?.getPlayerState() else 2
              @broadcastStateInterval = setInterval((=> @broadcastState(data: @lastPlayerState)), @opts.synced.packetInterval)
            onStateChange: (ev) =>
              newState = @player.getPlayerState()
              if @lastPlayerState? && ([-1, 2].indexOf(@lastPlayerState) > -1 && [1, 3].indexOf(newState) > -1)
                console.log "send resume"
                @connection.send("/resume")
              else if @lastPlayerState? && ([1, 3].indexOf(@lastPlayerState) > -1 && [2].indexOf(newState) > -1)
                console.log "send pause"
                @connection.send("/pause")
              console.log "state", "was", @lastPlayerState, "is", newState

              @lastPlayerState = newState
              @broadcastState(ev)

  broadcastState: (ev = @player?.getPlayerState()) ->
    state = switch ev?.data
      when -1 then "unstarted"
      when 0 then "ended"
      when 1 then "playing"
      when 2 then "paused"
      when 3 then "buffering"
      when 5 then "cued"
      else "ready"

    packet =
      state: state
      istate: ev?.data
      seek: @player?.getCurrentTime()
      playtime: @player?.getDuration()
      loaded_fraction: player.getVideoLoadedFraction()
      url: player.getVideoUrl()?.match(/([A-Za-z0-9_\-]{11})/)?[0]

    @connection.send("!packet:" + JSON.stringify(packet))

  # =================
  # = Control codes =
  # =================
  CMD_server_settings: (data) ->
    for k, v of data
      continue if k == "type"
      @debug "Accepting server controlled setting", k, "was", @opts.synced[k], "new", v
      @opts.synced[k] = v

  CMD_load_video: (data) ->
    @loadVideo data.ytid, data.cue

  CMD_ack: -> @enableInput()

  CMD_unsubscribe: ->
    @clients.html("")
    @player?.destroy()
    @player = null
    clearInterval(@broadcastStateInterval)

  CMD_desired: (data) ->
    unless @player
      @loadVideo(data.url, true)
      return

    current_ytid = player.getVideoUrl()?.match(/([A-Za-z0-9_\-]{11})/)?[0]
    if current_ytid != data.url
      @debug "Switching video from", current_ytid, "to", data.url
      @loadVideo(data.url)
      return

    if Math.abs(@drift * 1000) > @opts.synced.maxDrift || @force_resync || data.force
      @force_resync = false
      @debug "Seek to correct drift", @drift
      @player.seekTo(data.seek, true)
      return

    if @player.getPlayerState() == 1 && data.state != "play"
      @debug "pausing playback, state:", @player.getPlayerState()
      @player.pauseVideo()
      @player.seekTo(data.seek, true)
      return

    if @player.getPlayerState() != 1 && data.state == "play"
      @debug "starting playback, state:", @player.getPlayerState()
      @player.playVideo()
      return

  CMD_video_action: (data) ->
    switch data.action
      when "resume" then @player.playVideo()
      when "pause" then @player.pauseVideo()
      when "sync" then @force_resync = true
      when "destroy"
        @player?.destroy()
        @player = null
      when "seek"
        @player.seekTo(data.to, true)
        if data.paused
          @player.pauseVideo()
        else
          @player.playVideo()

  CMD_navigate: (data) ->
    if data.reload
      window.location.reload()
    else if data.location
      window.location.href = data.location

  CMD_session_index: (data) ->
    @index = data.index

  CMD_require_username: (data) ->
    @enableInput()
    @status.text("Choose name:")

    # check hash params
    return if data.autofill == false
    hparams = @getHashParams()
    @connection.send(p) if p = hparams.user || hparams.username || hparams.name

  CMD_username: (data) ->
    @name = data.username
    @status.text("#{@name}:")

    # check hash params
    hparams = @getHashParams()
    @connection.send("/join #{ch}") if ch = hparams.channel || hparams.join
    if hparams.control
      cmd = "/control #{hparams.control}"
      cmd += " #{hparams.password}" if hparams.password?
      @connection.send(cmd)

  CMD_update_single_subscriber: (resp) ->
    data = resp?.data || {}
    return unless data.index?
    el = @clients.find("[data-client-index=#{data.index}]")
    unless el.length
      el = $ """
        <div data-client-index="#{data.index}">
          <div class="first">
            <span data-attr="admin-ctn"><i></i></span>
            <span data-attr="name"></span>
          </div>
          <div class="second">
            <span data-attr="icon-ctn"><i><span data-attr="progress"></span> <span data-attr="timestamp"></span></i></span>
            <span data-attr="drift-ctn" style="float:right"><i><span data-attr="drift"></span></i></span>
            <div data-attr="progress-bar"><div data-attr="progress-bar-buffered"></div><div data-attr="progress-bar-position"></div></div>
          </div>
        </div>
      """
      @clients.append(el)
    el.find("[data-attr=#{k}]").html(v) for k, v of data
    el.find("[data-attr=#{k}]").html(v) for k, v of data.state
    el.find("[data-attr=progress-bar-buffered]").css(width: "#{(data.state.loaded_fraction || 0) * 100}%")
    el.find("[data-attr=progress-bar-position]").css(left: "#{if data.state.seek <= 0 then 0 else (data.state.seek / data.state.playtime * 100)}%")
    el.find("[data-attr=icon-ctn] i").attr("class", "fa fa-#{data.icon} #{data.icon_class}") if data.icon
    el.find("[data-attr=admin-ctn] i").attr("class", "fa fa-shield text-info").attr("title", "ADMIN") if data.control
    el.find("[data-attr=admin-ctn] i").attr("class", "fa fa-shield text-danger").attr("title", "HOST") if data.isHost
    el.find("[data-attr=drift-ctn] i").attr("class", "fa fa-#{if data.drift then if data.drift > 0 then "backward" else "forward" else "circle-o-notch"} text-warning")
    el.find("[data-attr=drift]").html(el.find("[data-attr=drift]").html().replace("-", ""))
    @drift = parseFloat(data.drift) if @index? && data.index == @index

  CMD_subscriber_list: (data) ->
    @clients.html("")
    @CMD_update_single_subscriber(data: sub) for sub in data.subscribers

$ ->
  client = new SyncTubeClient
    debug: true
  client.start()

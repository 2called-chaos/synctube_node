window.SyncTubeClient_Network =
  init: ->
    @opts.wsIp ?= $("meta[name=synctube-server-ip]").attr("content")
    @opts.wsPort ?= $("meta[name=synctube-server-port]").attr("content")
    @opts.wsProtocol ?= $("meta[name=synctube-server-protocol]").attr("content")
    @dontBroadcast = false

  start: ->
    @openWSconnection()
    @detectBrokenConnection()

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
    address = "#{@opts.wsProtocol}://#{@opts.wsIp}:#{@opts.wsPort}/cable"
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

  startBroadcast: ->
    return if @broadcastStateInterval?
    @broadcastStateInterval = setInterval((=> @broadcastState()), @opts.synced.packetInterval)

  stopBroadcast: ->
    clearInterval(@broadcastStateInterval)
    @broadcastStateInterval = null

  sendControl: (cmd) ->
    return unless @control
    @debug "send control", cmd
    @connection.send(cmd)

  broadcastState: (ev = @player?.getState()) ->
    return if @dontBroadcast
    state = switch ev
      when -666 then "uninitialized"
      when -1 then "unstarted"
      when 0 then "ended"
      when 1 then "playing"
      when 2 then "paused"
      when 3 then "buffering"
      when 5 then "cued"
      else "ready"

    packet =
      state: state
      istate: ev
      seek: @player?.getCurrentTime()
      playtime: @player?.getDuration()
      loaded_fraction: @player?.getLoadedFraction()
      url: @player?.getUrl()

    @connection.send("!packet:" + JSON.stringify(packet))

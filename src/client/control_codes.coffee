window.SyncTubeClient_ControlCodes =
  CMD_server_settings: (data) ->
    for k, v of data
      continue if k == "type"
      @debug "Accepting server controlled setting", k, "was", @opts.synced[k], "new", v
      @opts.synced[k] = v

  CMD_ack: -> @enableInput()

  CMD_taken_control: -> @control = true
  CMD_lost_control: -> @control = false

  CMD_unsubscribe: ->
    @clients.html("")
    @CMD_video_action(action: "destroy")

  CMD_desired: (data) ->
    if data.ctype != @player?.ctype
      @CMD_video_action(action: "destroy")
      klass = "SyncTubeClient_Player_#{data.ctype}"
      try
        @player = new window[klass](this)
      catch e
        @addError("Failed to load player #{data.ctype}! #{e.toString().replace("window[klass]", klass)}")
        throw e
        return

    @player.updateDesired(data)

  CMD_video_action: (data) ->
    switch data.action
      when "resume" then @player?.play()
      when "pause" then @player?.pause()
      when "sync" then @player?.force_resync = true
      when "seek" then @player?.seekTo(data.to, data.paused)
      when "destroy"
        @dontBroadcast = false
        @stopBroadcast()
        if @player
          @player.destroy()
          @player = null
          @broadcastState(-666)

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
    @status.text("#{@name}:") ##

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
    if !el.length || data.state.istate == -666
      _el = $(@buildSubscriberElement())
      _el.attr("data-client-index", data.index)
      if el.length then el.replaceWith(_el) else @clients.append(_el)
      el = _el
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

    # get ordered list
    subs = data.subscribers.sort (a, b) ->
      return -1 if a.isHost
      return 1 unless a.control
      return 0

    @CMD_update_single_subscriber(data: sub) for sub in data.subscribers



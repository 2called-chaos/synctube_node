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
    @destroyPlayer()
    @destroyIframe()
    @destroyImage()
    @destroyVideo()

  CMD_desired: (data) ->
    if data.ctype != @player?.ctype
      @player?.destroy()
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
      when "seek" then @player?.seekTo(data.to, true, data.paused)
      when "destroy"
        @player?.destroy()
        @player = null

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

    # get ordered list
    subs = data.subscribers.sort (a, b) ->
      return -1 if a.isHost
      return 1 unless a.control
      return 0

    @CMD_update_single_subscriber(data: sub) for sub in data.subscribers



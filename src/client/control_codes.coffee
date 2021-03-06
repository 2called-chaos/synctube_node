window.SyncTubeClient_ControlCodes =
  CMD_server_settings: (data) ->
    for k, v of data when k isnt "type"
      @debug "Accepting server controlled setting", k, "was", @opts.synced[k], "new", v
      @opts.synced[k] = v

  CMD_ack: -> @enableInput()

  CMD_session_kicked: (info) ->
    @CMD_disconnected()
    @CMD_desired(ctype: "StuiKicked", info: info)

  CMD_banned: (info) ->
    @CMD_disconnected()
    @CMD_desired(ctype: "StuiBanned", info: info)

  CMD_kicked: (info) ->
    @CMD_desired(ctype: "StuiKicked", info: info)

  CMD_disconnected: (a...) ->
    @CMD_unsubscribe()
    @CMD_lost_control()
    @reconnect = false

  CMD_taken_control: ->
    @control = true
    @commandBar?.show()

  CMD_lost_control: ->
    @control = false
    @commandBar?.hide()

  CMD_taken_host: ->
    @host = true

  CMD_lost_host: ->
    @host = false

  CMD_unsubscribe: ->
    @CMD_ui_clear(component: "clients")
    @CMD_ui_clear(component: "playlist")
    @CMD_video_action(action: "destroy")
    @playlist.hide()

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
    @commandBar?.updateDesired(data)

  CMD_ui_clear: (data) ->
    switch data.component
      when "chat" then @content.html("")
      when "clients" then @clients.html("")
      when "playlist" then @playlist.html("")
      when "player" then @CMD_video_action(action: "destroy")

  CMD_ui_clipboard_poll: (data) ->
    navigator.clipboard.readText() if data.action == "permission"

  CMD_ui_chat: (data) ->
    switch data.action
      when "show"
        @content.show 200, => @content.scrollTop(@content.prop("scrollHeight"))
        @clients.show 200, => $(window).resize()
      when "hide"
        @content.hide 200
        @clients.hide 200, => $(window).resize()
      else
        @content.toggle 200, => @content.scrollTop(@content.prop("scrollHeight"))
        @clients.toggle 200, => $(window).resize()

  CMD_ui_playlist: (data) ->
    switch data.action
      when "show"
        @playlist.removeClass("collapsed"); @delay 200, -> $(window).resize()
      when "hide"
        @playlist.addClass("collapsed"); @delay 200, -> $(window).resize()
      else
        @playlist.toggleClass("collapsed"); @delay 200, -> $(window).resize()

  CMD_video_action: (data) ->
    switch data.action
      when "resume"
        @player?.pauseEnsured?("server cancel") if data.cancelPauseEnsured
        @player?.play()
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
    @input.attr("maxLength", data.maxLength) if data.maxLength?
    @status.text("Choose name:")
    @CMD_desired(ctype: "StuiCreateForm")

    # check hash params
    hparams = @getHashParams()
    @connection.send(p) if p = hparams.user || hparams.username || hparams.name

  CMD_username: (data) ->
    @name = data.username
    @input.removeAttr("maxLength")
    @status.text("#{@name}:")
    @player?.clientUpdate?()

    # check hash params
    hparams = @getHashParams()
    @connection.send("/join #{ch}") if ch = hparams.channel || hparams.join
    if hparams.control
      cmd = "/control #{hparams.control}"
      cmd += " #{hparams.password}" if hparams.password?
      @connection.send(cmd)

  CMD_playlist_single_entry: (data) ->
    el = @playlist.find("[data-pl-id=\"#{data.id}\"]")
    if !el.length || el.data("plIndex") != data.index
      _el = $(@buildPlaylistElement(data))
      _el.attr("data-pl-id", data.id)
      if el.length then el.replaceWith(_el) else @playlist.append(_el)
      el = _el

    changeHTML = (el, v) ->
      return unless el.length
      el.html(v) unless el.html() == v
      el
    changeAttr = (el, a, v) ->
      return unless el.length
      el.attr(a, v) unless el.attr(a) == v
      el

    changeAttr(el.find("[data-attr=thumbnail]"), "src", data.thumbnail) if data.thumbnail
    if data.author
      changeAttr(el.find("[data-attr=author]"), "title", data.author[0])
      changeAttr(el.find("[data-attr=author]"), "href", data.author[1])
      changeHTML(el.find("[data-attr=author]"), data.author[0])
    if typeof data.name == "string"
      changeHTML(el.find("[data-attr=name]"), data.name)
      changeAttr(el.find("[data-attr=name]"), "title", data.name)
      el.find("[data-attr=name]").removeAttr("href")
    else
      changeAttr(el.find("[data-attr=name]"), "href", data.name[1])
      changeAttr(el.find("[data-attr=name]"), "title", data.name[0])
      changeHTML(el.find("[data-attr=name]"), data.name[0])
    changeHTML(el.find("[data-attr=timestamp]"), data.timestamp)
    @playlist.toggle(!!@playlist.find("div[data-pl-id]").length)
    @playlist.scrollTop(@playlist.find("div.active").prop("offsetTop") - 15)
    $(window).resize()

  CMD_playlist_update: (data) ->
    if data.entries
      @CMD_ui_clear(component: "playlist")
      @CMD_playlist_single_entry(ple) for ple in data.entries
    if data.index?
      @playlist.find("div[data-pl-id]").removeClass("active")
      @playlist.find("div[data-pl-index=#{data.index}]").addClass("active")
    @playlist.toggle(!!@playlist.find("div[data-pl-id]").length)
    @playlist.scrollTop(@playlist.find("div.active").prop("offsetTop") - 15)
    $(window).resize()

  CMD_update_single_subscriber: (resp) ->
    data = resp?.data || {}
    return unless data.index?
    el = @clients.find("[data-client-index=#{data.index}]")
    if !el.length || data.state.istate == -666
      _el = $(@buildSubscriberElement())
      _el.attr("data-client-index", data.index)
      if el.length then el.replaceWith(_el) else @clients.append(_el)
      el = _el

    changeHTML = (el, v) ->
      return unless el.length
      el.html(v) unless el.html() == v
      el
    changeAttr = (el, a, v) ->
      return unless el.length
      el.attr(a, v) unless el.attr(a) == v
      el

    changeHTML(el.find("[data-attr=#{k}]"), ""+v) for k, v of data
    changeHTML(el.find("[data-attr=#{k}]"), ""+v) for k, v of data.state
    el.find("[data-attr=progress-bar-buffered]").css(width: "#{(data.state.loaded_fraction || 0) * 100}%")
    el.find("[data-attr=progress-bar-position]").css(left: "#{if data.state.seek <= 0 then 0 else (data.state.seek / data.state.playtime * 100)}%")
    changeAttr(el.find("[data-attr=icon-ctn] i"), "class", "fa fa-#{data.icon} #{data.icon_class}") if data.icon
    if data.control
      changeAttr(el.find("[data-attr=admin-ctn] i"), "class", "fa fa-shield text-info")
      changeAttr(el.find("[data-attr=admin-ctn] i"), "title", "admin")
    if data.isHost
      changeAttr(el.find("[data-attr=admin-ctn] i"), "class", "fa fa-shield text-danger")
      changeAttr(el.find("[data-attr=admin-ctn] i"), "title", "HOST")
    changeAttr(el.find("[data-attr=drift-ctn] i"), "class", "fa fa-#{if data.drift then if data.drift > 0 then "backward" else "forward" else "circle-o-notch"} text-warning")
    changeHTML(el.find("[data-attr=drift]"), el.find("[data-attr=drift]").html().replace("-", ""))
    @drift = parseFloat(data.drift) if @index? && data.index == @index

  CMD_subscriber_list: (data) ->
    @clients.html("")

    # get ordered list
    subs = data.subscribers.sort (a, b) -> if a.isHost && !b.isHost then -1 else 1
    subs = subs.sort (a, b) -> if a.control && !b.control then -1 else 1

    @CMD_update_single_subscriber(data: sub) for sub in data.subscribers



PersistedStorage = require("./persisted_storage.js").Class
PlaylistManager = require("./playlist_manager.js").Class
COLORS = require("./colors.js")
UTIL = require("./util.js")

exports.Class = class SyncTubeServerChannel
  debug: (a...) -> @server.debug("[#{@name}]", a...)
  info: (a...) -> @server.info("[#{@name}]", a...)
  warn: (a...) -> @server.warn("[#{@name}]", a...)
  error: (a...) -> @server.error("[#{@name}]", a...)

  constructor: (@server, @name, @password) ->
    @control = []
    @host = 0
    @subscribers = []
    @ready = false
    @ready_timeout = null
    @persisted = new PersistedStorage @server, "channel/#{UTIL.sha1(@name)}",
      assign_to: this
      default:
        name: @name
        password: @password
        queue: []
        playlists: {}
        playlistActiveSet: "default"
        desired: false
        options:
          defaultCtype: @server.opts.defaultCtype
          defaultUrl: @server.opts.defaultUrl
          defaultAutoplay: @server.opts.defaultAutoplay
          maxDrift: @server.opts.maxDrift
          packetInterval: @server.opts.packetInterval
          readyGracePeriod: 2000
          chatMode: "public" # public, admin-only, disabled
          playlistMode: "full" # full, disabled

    @persisted.beforeSave (ps, store) =>
      # reset playlist index because it makes everything easier
      v.index = -1 for k, v of store.playlists

      # delete playlist maps
      delete v["map"] for k, v of store.playlists

      # delete volatile playlists
      for k, v of store.playlists
        unless v.persisted
          wasActive = k == store.playlistActiveSet
          @debug "removing volatile playlist #{k}#{if wasActive then " (was active, switching to default)" else ""}"
          delete store.playlists[k]
          @playlistActiveSet = @persisted.set("playlistActiveSet", "default") if wasActive

    @setDefaultDesired() unless @desired
    @playlistManager = new PlaylistManager(this, @playlists)
    @playlistManager.rebuildMaps()
    @playlistManager.onListChange (set) => @playlistActiveSet = @persisted.set("playlistActiveSet", set)
    @playlistManager.load(@playlistActiveSet)
    @init()

  init: -> # plugin hook

  defaultDesired: ->
    {
      ctype: @options.defaultCtype
      url: @options.defaultUrl
      seek: 0
      loop: false
      seek_update: new Date
      state: if @options.defaultAutoplay then "play" else "pause"
    }

  setDefaultDesired: (broadcast = true) ->
    @persisted.desired = @desired = @defaultDesired()
    @broadcastCode(false, "desired", @desired)

  broadcast: (client, message, color, client_color, sendToAuthor = true) ->
    for c in @subscribers
      continue if c == client && !sendToAuthor
      c.sendMessage(message, color, client.name, client_color || client?.color)

  broadcastChat: (client, message, color, client_color, sendToAuthor = true) ->
    if @options.chatMode == "disabled" || (@options.chatMode == "admin-only" && @control.indexOf(client) == -1)
      return client.sendSystemMessage("chat is #{@options.chatMode}!", COLORS.muted)
    @broadcast(client, message, color, client_color, sendToAuthor)

  broadcastCode: (client, type, data, sendToAuthor = true) ->
    for c in @subscribers
      continue if c == client && !sendToAuthor
      c.sendCode(type, data)

  sendSettings: (client) ->
    clients = if client then [client] else @subscribers
    for sub in clients
      sub.sendCode "server_settings", packetInterval: @options.packetInterval, maxDrift: @options.maxDrift

  updateSubscriberList: (client) ->
    @broadcastCode(client, "subscriber_list", channel: @name, subscribers: @getSubscriberList(client))

  getSubscriberList: (client) ->
    list = []
    list.push(@getSubscriberData(client, c, i)) for c, i in @subscribers
    list

  getSubscriberData: (client, sub, index) ->
    data =
      index: sub.index
      name: sub.name || sub.old_name
      control: @control.indexOf(sub) > -1
      isHost: @control[@host] == sub
      isyou: client == sub
      drift: 0
      state: sub.state || {}

    # calculcate drift
    leader = @control[0]
    if sub.state?.seek && leader?.state?.seek?
      seekdiff = leader?.state?.seek - sub.state.seek
      seekdiff -= (leader.lastPacket - sub.lastPacket) / 1000 if leader.lastPacket && sub.lastPacket && leader?.state?.state == "playing"
      data.drift = seekdiff.toFixed(3)
      data.drift = 0 if data.drift == "0.000"

    data.progress = data.state.state || "uninitialized"
    switch data.state?.state
      when "unstarted" then data.icon = "cog"; data.icon_class = "text-muted"
      when "ended"     then data.icon = "stop"; data.icon_class = "text-danger"
      when "playing"   then data.icon = "play"; data.icon_class = "text-success"
      when "paused"    then data.icon = "pause"; data.icon_class = "text-warning"
      when "buffering" then data.icon = "spinner"; data.icon_class = "text-warning"
      when "cued"      then data.icon = "eject"; data.icon_class = "text-muted"
      when "ready"     then data.icon = "check-square-o"; data.icon_class = "text-muted"
      else                  data.icon = "cog"; data.icon_class = "text-danger"

    data

  live: (ctype, url) ->
    @persisted.desired = @desired = { ctype: ctype, url: url, state: "pause", seek: 0, loop: false, seek_update: new Date}
    @ready = []
    @broadcastCode(false, "desired", Object.assign({}, @desired, { forceLoad: true }))

    # start after grace period
    @ready_timeout = UTIL.delay @options.readyGracePeriod, =>
      @ready = false
      @desired.state = "play"
      @broadcastCode(false, "video_action", action: "resume", reason: "gracePeriod")

  play: (ctype, url, playNext = false, intermission = false) ->
    if intermission
      @playlistManager.intermission(ctype, url)
    else if playNext
      @playlistManager.playNext(ctype, url)
    else
      @playlistManager.append(ctype, url)

  pauseVideo: (client, sendMessage = true) ->
    return unless @control.indexOf(client) > -1
    @broadcastCode(client, "video_action", action: "pause", {}, false)
    @broadcastCode(client, "video_action", action: "seek", to: client.state.seek, paused: true, false) if client.state?.seek?

  playVideo: (client, sendMessage = true) ->
    return unless @control.indexOf(client) > -1
    @broadcastCode(client, "video_action", action: "resume", reason: "playVideo", false)

  grantControl: (client, sendMessage = true) ->
    return if @control.indexOf(client) > -1
    @control.push(client)
    client.control = this
    client.sendSystemMessage("You are in control of #{@name}!", COLORS.green) if sendMessage
    client.sendCode("taken_control", channel: @name)
    client.sendCode("taken_host", channel: @name) if @host == @control.indexOf(client)
    @updateSubscriberList(client)
    @debug "granted control to client ##{client.index}(#{client.ip})"

  revokeControl: (client, sendMessage = true, reason = null) ->
    return if @control.indexOf(client) == -1
    client.sendCode("lost_host", channel: @name) if @host == @control.indexOf(client)
    client.sendCode("lost_control", channel: @name)
    client.sendSystemMessage("You lost control of #{@name}#{if reason then " (#{reason})" else ""}!", COLORS.red) if sendMessage
    @control.splice(@control.indexOf(client), 1)
    client.control = null
    @updateSubscriberList(client)
    @debug "revoked control from client ##{client.index}(#{client.ip})"

  subscribe: (client, sendMessage = true) ->
    return if @subscribers.indexOf(client) > -1
    client.subscribed?.unsubscribe?(client)
    @subscribers.push(client)
    client.subscribed = this
    client.state = {}
    client.sendSystemMessage("You joined #{@name}!", COLORS.green) if sendMessage
    client.sendCode("subscribe", channel: @name)
    @sendSettings(client)
    @playlistManager?.cUpdateList(client)
    client.sendCode("desired", Object.assign({}, @desired, { force: true }))
    @broadcast(client, "<i>joined the party!</i>", COLORS.green, COLORS.muted, false)
    @updateSubscriberList(client)
    @debug "subscribed client ##{client.index}(#{client.ip})"

  unsubscribe: (client, sendMessage = true, reason = null) ->
    return if @subscribers.indexOf(client) == -1
    client.control.revokeControl(client, sendMessage, reason) if client.control == this
    @subscribers.splice(@subscribers.indexOf(client), 1)
    client.subscribed = null
    client.state = {}
    client.sendSystemMessage("You left #{@name}#{if reason then " (#{reason})" else ""}!", COLORS.red) if sendMessage
    client.sendCode("unsubscribe", channel: @name)
    @broadcast(client, "<i>left the party :(</i>", COLORS.red, COLORS.muted, false)
    @updateSubscriberList(client)
    @debug "unsubscribed client ##{client.index}(#{client.ip})"

  destroy: (client, reason) ->
    @info "channel deleted by #{client.name}[#{client.ip}] (#{@subscribers.length} subscribers)#{if reason then ": #{reason}" else ""}"
    @unsubscribe(c, true, "channel deleted#{if reason then " (#{reason})" else ""}") for c in @subscribers.slice(0).reverse()

    delete @server.channels[@name]

  clientColor: (client) ->
    if @control[@host] == client
      COLORS.red
    else if @control.indexOf(client) > -1
      COLORS.info
    else
      null

  findClient: (client, who) ->
    require("./client.js").Class.find(client, who, @subscribers, "channel")


COLORS = require("./colors.js")
UTIL = require("./util.js")
Client = require("./client.js").Class

exports.Class = class SyncTubeServerChannel
  debug: (a...) -> @server.debug("[#{@name}]", a...)
  info: (a...) -> @server.info("[#{@name}]", a...)
  warn: (a...) -> @server.warn("[#{@name}]", a...)
  error: (a...) -> @server.error("[#{@name}]", a...)

  constructor: (@server, @name, @password) ->
    @control = []
    @host = 0
    @subscribers = []
    @queue = []
    @ready = []
    @ready_timeout = null
    @playlist = []
    @playlist_index = 0
    @desired = { ctype: @server.opts.defaultCtype, url: @server.opts.defaultUrl, seek: 0, loop: false, seek_update: new Date, state: if @server.opts.defaultAutoplay then "play" else "pause" }

  broadcast: (client, message, color, client_color, sendToAuthor = true) ->
    for c in @subscribers
      continue if c == client && !sendToAuthor
      c.sendMessage(message, color, client.name, client_color || client?.color)

  broadcastCode: (client, type, data, sendToAuthor = true) ->
    for c in @subscribers
      continue if c == client && !sendToAuthor
      c.sendCode(type, data)

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
      seekdiff = leader?.state?.seek - client.state.seek
      seekdiff -= (leader.lastPacket - client.lastPacket) / 1000 if leader.lastPacket && client.lastPacket
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

  liveVideo: (url, state = "pause") ->
    @desired = { ctype: "Youtube", url: url, state: state, seek: 0, loop: false, seek_update: new Date}
    @ready = []
    @broadcastCode(false, "desired", @desired)

    # start after grace period
    @ready_timeout = UTIL.delay 2000, =>
      @desired.state = "play"
      @broadcastCode(false, "video_action", action: "play")

  liveUrl: (url, ctype = "HtmlFrame") ->
    url = "https://#{url}" unless UTIL.startsWith(url, "http://", "https://")
    @desired = { ctype: ctype, url: url, loop: false, state: "play" }
    @ready = []
    @broadcastCode(false, "desired", @desired)

  pauseVideo: (client, sendMessage = true) ->
    return unless @control.indexOf(client) > -1
    @broadcastCode(client, "video_action", action: "pause", {}, false)
    @broadcastCode(client, "video_action", action: "seek", to: client.state.seek, paused: true, false) if client.state?.seek?

  playVideo: (client, sendMessage = true) ->
    return unless @control.indexOf(client) > -1
    @broadcastCode(client, "video_action", action: "resume", false)

  grantControl: (client, sendMessage = true) ->
    return if @control.indexOf(client) > -1
    @control.push(client)
    client.control = this
    client.sendSystemMessage("You are in control of #{@name}!", COLORS.green) if sendMessage
    client.sendCode("taken_control", channel: @name)
    @updateSubscriberList(client)
    @debug "granted control to client ##{client.index}(#{client.ip})"

  revokeControl: (client, sendMessage = true, reason = null) ->
    return if @control.indexOf(client) == -1
    @control.splice(@control.indexOf(client), 1)
    client.control = null
    client.sendSystemMessage("You lost control of #{@name}#{if reason then " (#{reason})" else ""}!", COLORS.red) if sendMessage
    client.sendCode("lost_control", channel: @name)
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
    client.sendCode("desired", Object.assign({}, @desired, { force: true }))
    @broadcast(client, "<i>joined the party!</i>", COLORS.green, COLORS.muted, false)
    @updateSubscriberList(client)
    @debug "subscribed client ##{client.index}(#{client.ip})"

  unsubscribe: (client, sendMessage = true, reason = null) ->
    return if @subscribers.indexOf(client) == -1
    client.control.revokeControl(client) if client.control == this
    @subscribers.splice(@subscribers.indexOf(client), 1)
    client.subscribed = null
    client.state = {}
    client.sendSystemMessage("You left #{@name}#{if reason then " (#{reason})" else ""}!", COLORS.red) if sendMessage
    client.sendCode("unsubscribe", channel: @name)
    @broadcast(client, "<i>left the party :(</i>", COLORS.red, COLORS.muted, false)
    @updateSubscriberList(client)
    @debug "unsubscribed client ##{client.index}(#{client.ip})"

  destroy: (client, sendMessage = true) ->
    @debug "channel deleted by #{client.name}[#{client.ip}] (#{@subscribers.length} subscribers)"
    @unsubscribe(c, true, "channel deleted") for c in @subscribers

    for c in @control
      @revokeControl(c, true, "channel deleted by #{client.name}[#{client.ip}]")

    delete @server.channels[@name]

  clientColor: (client) ->
    if @control[@host] == client
      COLORS.red
    else if @control.indexOf(client) > -1
      COLORS.info
    else
      null

  findClient: (client, who) -> Client.find(client, who, @subscribers, "channel")

  # ====================
  # = Channel commands =
  # ====================
  handleMessage: (client, message, msg, control = false) ->
    if control
      return @CHSCMD_seek(client, m[1]) if m = msg.match(/^\/(?:seek)(?:\s([0-9\-+:\.]+))?$/i)
      return @CHSCMD_pause(client) if m = msg.match(/^\/(?:p|pause)$/i)
      return @CHSCMD_resume(client) if m = msg.match(/^\/(?:r|resume)$/i)
      return @CHSCMD_toggle(client) if m = msg.match(/^\/(?:t|toggle)$/i)
      return @CHSCMD_play(client, m[1]) if m = msg.match(/^\/play\s(.+)$/i)
      return @CHSCMD_browse(client, m[1], "HtmlFrame") if m = msg.match(/^\/(?:browse|url)\s(.+)$/i)
      return @CHSCMD_browse(client, m[1], "HtmlImage") if m = msg.match(/^\/(?:image|img|pic(?:ture)?|gif|png|jpg)\s(.+)$/i)
      return @CHSCMD_browse(client, m[1], "HtmlVideo") if m = msg.match(/^\/(?:video|vid|mp4|webp)\s(.+)$/i)
      return @CHSCMD_host(client, m[1]) if m = msg.match(/^\/host(?:\s(.+))?$/i)
      return @CHSCMD_grantControl(client, m[1]) if m = msg.match(/^\/grant(?:\s(.+))?$/i)
      return @CHSCMD_revokeControl(client, m[1]) if m = msg.match(/^\/revoke(?:\s(.+))?$/i)
      return @CHSCMD_loop(client, m[1]) if m = msg.match(/^\/loop(?:\s(.+))?$/i)
      return false
    else
      return @CHSCMD_loop(client, m[1]) if m = msg.match(/^\/loop(?:\s(.+))?$/i)
      return @CHSCMD_ready(client) if m = msg.match(/^\/(?:ready|rdy)$/i)
      return @CHSCMD_retry(client) if m = msg.match(/^\/retry$/i)
      return @CHSCMD_leave(client) if m = msg.match(/^\/leave$/i)
      @broadcast(client, msg, null, @clientColor(client))
      return client.ack()

  CHSCMD_retry: (client) ->
    return unless ch = client.subscribed
    ch.revokeControl(client)
    ch.unsubscribe(client)
    ch.subscribe(client)
    return client.ack()

  CHSCMD_pause: (client) ->
    return client.permissionDenied("pause") unless @control.indexOf(client) > -1
    @desired.state = "pause"
    @broadcastCode(false, "desired", @desired)
    return client.ack()

  CHSCMD_resume: (client) ->
    return client.permissionDenied("resume") unless @control.indexOf(client) > -1
    @desired.state = "play"
    @broadcastCode(false, "desired", @desired)
    return client.ack()

  CHSCMD_toggle: (client) ->
    return client.permissionDenied("toggle") unless @control.indexOf(client) > -1
    @desired.state = if @desired.state == "play" then "pause" else "play"
    @broadcastCode(false, "desired", @desired)
    return client.ack()

  CHSCMD_seek: (client, to) ->
    return client.permissionDenied("seek") unless @control.indexOf(client) > -1
    if to?.charAt(0) == "-"
      to = @desired.seek - UTIL.timestamp2Seconds(to.slice(1))
    else if to?.charAt(0) == "+"
      to = @desired.seek + UTIL.timestamp2Seconds(to.slice(1))
    else if to
      to = UTIL.timestamp2Seconds(to)
    else
      client.sendSystemMessage("Number required (absolute or +/-)")
      return client.ack()

    @desired.seek = parseFloat(to)
    @desired.state = "play" if @desired.state == "ended"
    @broadcastCode(false, "desired", Object.assign({}, @desired, { force: true }))
    return client.ack()

  CHSCMD_ready: (client) ->
    @ready.push(client)
    if @ready.length == @subscribers.length
      clearTimeout(@ready_timeout)
      @desired.state = "play"
      @broadcastCode(false, "video_action", action: "play")
    return client.ack()

  CHSCMD_play: (client, url) ->
    return client.permissionDenied("play") unless @control.indexOf(client) > -1
    if m = url.match(/([A-Za-z0-9_\-]{11})/)
      @liveVideo(m[1])
    else
      client.sendSystemMessage("I don't recognize this URL/YTID format, sorry")

    return client.ack()

  CHSCMD_loop: (client, what) ->
    if what || @control.indexOf(client) > -1
      return client.permissionDenied("loop") unless @control.indexOf(client) > -1
      what = UTIL.strbool(what, !@desired.loop)
      if @desired.loop == what
        client.sendSystemMessage("Loop is already #{if @desired.loop then "enabled" else "disabled"}!")
      else
        @desired.loop = what
        @broadcastCode(false, "desired", @desired)
        @broadcast(client, "<strong>#{if @desired.loop then "enabled" else "disabled"} loop!</strong>", COLORS.warning, @clientColor(client))
    else
      client.sendSystemMessage("Loop is currently #{if @desired.loop then "enabled" else "disabled"}", if @desired.loop then COLORS.green else COLORS.red)

    return client.ack()

  CHSCMD_browse: (client, url, ctype = "frame") ->
    return client.permissionDenied("browse-#{ctype}") unless @control.indexOf(client) > -1
    @liveUrl(url, ctype)
    return client.ack()

  CHSCMD_leave: (client) ->
    if ch = client.subscribed
      ch.unsubscribe(client)
    else
      client.sendSystemMessage("You are not in any channel!")

    return client.ack()

  CHSCMD_host: (client, who) ->
    return client.permissionDenied("host") unless @control.indexOf(client) > -1
    return false unless who = @findClient(client, who)

    if who == @control[@host]
      client.sendSystemMessage("#{who?.name || "Target"} is already host")
    else if @control.indexOf(who) > -1
      @debug "Switching host to #", who.index
      wasHostI = @host
      wasHost = @control[wasHostI]
      newHostI = @control.indexOf(who)
      newHost = @control[newHostI]
      @control[wasHostI] = newHost
      @control[newHostI] = wasHost
      @updateSubscriberList(client)
    else
      client.sendSystemMessage("#{who?.name || "Target"} is not in control and thereby can't be host")
    #@broadcastCode(false, "desired", @desired)
    return client.ack()

  CHSCMD_grantControl: (client, who) ->
    return client.permissionDenied("grantControl") unless @control.indexOf(client) > -1
    return true unless who = @findClient(client, who)

    if @control.indexOf(who) > -1
      client.sendSystemMessage("#{who?.name || "Target"} is already in control")
    else
      @grantControl(who)
      client.sendSystemMessage("#{who?.name || "Target"} is now in control!", COLORS.green)

    return client.ack()

  CHSCMD_revokeControl: (client, who) ->
    return client.permissionDenied("revokeControl") unless @control.indexOf(client) > -1
    return true unless who = @findClient(client, who)

    if @control.indexOf(who) > -1
      @revokeControl(who)
      client.sendSystemMessage("#{who?.name || "Target"} is no longer in control!", COLORS.green)
    else
      client.sendSystemMessage("#{who?.name || "Target"} was not in control")

    return client.ack()

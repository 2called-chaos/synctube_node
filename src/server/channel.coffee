COLORS = require("../colors.js")

exports.Class = class SyncTubeServerChannel
  debug: (a...) -> @server.debug("[#{@name}]", a...)
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
    @desired = { url: @server.DEFAULT_VIDEO, seek: 0, seek_update: new Date, state: if @server.DEFAULT_AUTOPLAY then "play" else "pause" }

  handleMessage: (client, message, msg) ->
    return @CHSCMD_seek(client, m[1]) if m = msg.match(/^\/(?:seek)(?:\s([0-9\-+]+))?$/i)
    return @CHSCMD_pause(client) if m = msg.match(/^\/(?:p|pause)$/i)
    return @CHSCMD_resume(client) if m = msg.match(/^\/(?:r|resume)$/i)
    return @CHSCMD_toggle(client) if m = msg.match(/^\/(?:t|toggle)$/i)
    return @CHSCMD_ready(client) if m = msg.match(/^\/(?:ready|rdy)$/i)
    return @CHSCMD_play(client, m[1]) if m = msg.match(/^\/play\s(.+)$/i)
    return @CHSCMD_host(client, m[1]) if m = msg.match(/^\/host(?:\s(.+))?$/i)
    @broadcast(client, msg, null, (if @control.indexOf(client) > -1 then COLORS.red else null))
    return client.ack()

  CHSCMD_pause: (client) ->
    @desired.state = "pause"
    @broadcastCode(false, "desired", @desired)
    return client.ack()

  CHSCMD_resume: (client) ->
    @desired.state = "play"
    @broadcastCode(false, "desired", @desired)
    return client.ack()

  CHSCMD_toggle: (client) ->
    @desired.state = if @desired.state == "play" then "pause" else "play"
    @broadcastCode(false, "desired", @desired)
    return client.ack()

  CHSCMD_seek: (client, to) ->
    if to.charAt(0) == "-"
      to = @desired.seek - parseFloat(to.slice(1))
    else if to.charAt(0) == "+"
      to = @desired.seek + parseFloat(to.slice(1))
    else if to
      to = to
    else
      client.sendSystemMessage("Number required (absolute or +/-)")
      return client.ack()

    @desired.seek = parseFloat(to)
    @broadcastCode(false, "video_action", action: "sync")
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
    if m = url.match(/([A-Za-z0-9_\-]{11})/)
      @liveVideo(m[1])
    else
      client.sendSystemMessage("I don't recognize this URL/YTID format, sorry")

    return client.ack()

  CHSCMD_host: (client, who) ->
    if who
      found = null

      for sub in @subscribers
        if sub.name.match(new RegExp(who, "i"))
          found = sub
          break

      if found
        who = found
      else
        client.sendSystemMessage("Couldn't find the target in channel")
        return client.ack()
    else
      who = client

    if who == @control[@host]
      client.sendSystemMessage("Target is already host")
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
      client.sendSystemMessage("Target is not in control and thereby can't be host")
    #@broadcastCode(false, "desired", @desired)
    return client.ack()

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

  liveVideo: (url, state = "pause") ->
    @desired = { url: url, seek: 0, state: state }
    @ready = []
    @broadcastCode(false, "desired", @desired)

    # start after grace period
    @ready_timeout = setTimeout((=>
      @desired.state = "play"
      @broadcastCode(false, "video_action", action: "play")
    ), 2000)

  getSubscriberList: (client) ->
    list = []
    list.push(@getSubscriberData(client, c, i)) for c, i in @subscribers
    list

  getSubscriberData: (client, sub, index) ->
    data =
      index: sub.index
      name: sub.name
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
    @subscribers.push(client)
    client.subscribed = this
    client.state = {}
    client.sendSystemMessage("You joined #{@name}!", COLORS.green) if sendMessage
    client.sendCode("subscribe", channel: @name)
    client.sendCode("desired", @desired)
    @broadcast(client, "<i>joined the party!</i>", COLORS.green, COLORS.muted, false)
    @updateSubscriberList(client)
    @debug "subscribed client ##{client.index}(#{client.ip}) to channel #{@name}"

  unsubscribe: (client, sendMessage = true, reason = null) ->
    return if @subscribers.indexOf(client) == -1
    @subscribers.splice(@subscribers.indexOf(client), 1)
    client.subscribed = null
    client.state = {}
    client.sendSystemMessage("You left #{@name}#{if reason then " (#{reason})" else ""}!", COLORS.red) if sendMessage
    client.sendCode("unsubscribe", channel: @name)
    @broadcast(client, "<i>left the party :(</i>", COLORS.red, COLORS.muted, false)
    @updateSubscriberList(client)
    @debug "unsubscribed client ##{client.index}(#{client.ip}) from channel #{@name}"

  destroy: (client, sendMessage = true) ->
    @debug "channel deleted by #{client.name}[#{client.ip}] (#{@subscribers.length} subscribers)"
    @unsubscribe(c, true, "channel deleted") for c in @subscribers

    for c in @control
      @revokeControl(c, true, "channel deleted by #{client.name}[#{client.ip}]")

    delete @server.channels[@name]

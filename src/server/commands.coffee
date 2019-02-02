COLORS = require("./colors.js")
UTIL = require("./util.js")
Channel = require("./channel.js").Class
Client = require("./client.js").Class
XClient = require("./client.js").Class
ShellQuote = require("shell-quote")

x = module.exports =
  handleMessage: (server, client, message, msg) ->
    try
      return @Server["packet"].call(server, client, m[1]) if m = msg.match(/^!packet:(.+)$/i)
      chunks = []
      cmd = null
      if msg && msg.charAt(0) == "/"
        for x in ShellQuote.parse(msg.substr(1))
          chunks.push(if typeof x == "string" then x else x.pattern)
        cmd = chunks.shift()

      return if cmd && @Server[cmd]?.call(server, client, chunks...)
      if ch = client.subscribed
        return if cmd && @Channel[cmd]?.call(ch, client, chunks...)
        ch.broadcast(client, msg, null, ch.clientColor(client))
        return client.ack()

      return client.ack()
    catch err
      server.error err
      client.sendSystemMessage("Sorry, the server encountered an error")
      return client.ack()

  addCommand: (parent, cmds..., proc) ->
    ((cmd)-> x[parent][cmd] = proc)(_cmd) for _cmd in cmds

  Server: {}
  Channel: {}

x.addCommand "Server", "clear", (client) ->
  client.sendCode("ui_clear", component: "chat")
  client.ack()

x.addCommand "Server", "packet", (client, jdata) ->
  try
    json = JSON.parse(jdata)
  catch error
    @error "Invalid JSON", jdata, error
    return

  client.lastPacket = new Date
  ch = client.subscribed
  if ch && (!client.state || (JSON.stringify(client.state) != jdata))
    json.time = new Date
    json.timestamp = UTIL.videoTimestamp(json.seek, json.playtime) if json.seek? && json.playtime?

    client.state = json
    ch.broadcastCode(client, "update_single_subscriber", channel: ch.name, data: ch.getSubscriberData(client, client, client.index))
    if client == ch.control[ch.host] && ch.desired.url == json.url
      seek_was = ch.desired.seek
      ch.desired.state = json.state if json.state == "ended"
      ch.desired.seek = json.seek
      ch.desired.seek_update = new Date()
      ch.broadcastCode(false, "desired", Object.assign({}, ch.desired, { force: Math.abs(ch.desired.seek - seek_was) > (@opts.packetInterval + 0.75) }))
  else
    client.sendCode("desired", ch.desired) if ch
  return true

x.addCommand "Server", "join", (client, chname) ->
  if channel = @channels[chname]
    channel.subscribe(client)
  else if chname
    client.sendSystemMessage("I don't know about this channel, sorry!")
    client.sendSystemMessage("<small>You can create it with <strong>/control #{UTIL.htmlEntities(chname)} [password]</strong></small>", COLORS.info)
  else
    client.sendSystemMessage("Usage: /join &lt;channel&gt;")

  return client.ack()

x.addCommand "Server", "control", (client, name, password) ->
  chname = UTIL.htmlEntities(name || client.subscribed?.name || "")
  unless chname
    client.sendSystemMessage("Channel name required", COLORS.red)
    return client.ack()

  if channel = @channels[chname]
    if channel.control.indexOf(client) > -1 && password == "delete"
      channel.destroy(client)
      return client.ack()
    else
      if channel.password == password
        channel.subscribe(client)
        channel.grantControl(client)
      else
        client.sendSystemMessage("Password incorrect", COLORS.red)
  else
    @channels[chname] = new Channel(this, chname, password)
    client.sendSystemMessage("Channel created!", COLORS.green)
    @channels[chname].subscribe(client)
    @channels[chname].grantControl(client)

  return client.ack()

x.addCommand "Server", "dc", "disconnect", (client) ->
  client.sendSystemMessage("disconnecting...")
  client.sendCode("disconnected")
  client.connection.close()

x.addCommand "Server", "rename", (client, name_parts...) ->
  if new_name = name_parts.join(" ")
    client.old_name = client.name
    client.setUsername(new_name)
  else
    client.sendCode "require_username", maxLength: @opts.nameMaxLength, autofill: false
    client.old_name = client.name
    client.name = null
    client.sendSystemMessage "Tell me your new username!"
  return client.ack()

x.addCommand "Server", "system", (client, subaction, args...) ->
  unless client.isSystemAdmin
    if subaction == "auth"
      if UTIL.argsToStr(args) == @opts.systemPassword
        client.isSystemAdmin = true
        client.sendSystemMessage("Authenticated successfully!", COLORS.green)
      else
        client.sendSystemMessage "invalid password"
    else
      client.sendSystemMessage "system commands require you to `/system auth &lt;syspw&gt;` first!"
    return client.ack()

  switch subaction
    when "restart"
      @eachClient "sendSystemMessage", "Server restart: #{reason}" if reason = UTIL.argsToStr(args)
      client.sendSystemMessage "See ya!"
      throw "bye"
      #UTIL.delay 1000, => client.sendCode "navigate", reload: true
      return true
    when "gracefulRestart"
      if args[0] == "cancel"
        if @pendingRestart?
          @eachClient "sendSystemMessage", "Restart canceled"
          @pendingRestart = null
          @pendingRestartReason = null
          clearTimeout(@pendingRestartTimeout)
        else
          client.sendSystemMessage("No pending restart")
      else
        time = new Date((new Date).getTime() + UTIL.timestamp2Seconds(args.shift()) * 1000)
        clearTimeout(@pendingRestartTimeout)
        @pendingRestart = time
        @pendingRestartReason = UTIL.argsToStr(args)
        @handlePendingRestart(true)
    when "message"
      @eachClient "sendSystemMessage", "#{UTIL.argsToStr(args)}"
    when "chmessage"
      channel = args.shift()
      if ch = @channels[channel]
        ch.broadcast({name: "system"}, UTIL.argsToStr(args), COLORS.red, COLORS.red)
      else
        client.sendSystemMessage "The channel could not be found!"
    when "chkill"
      channel = args.shift()
      if ch = @channels[channel]
        ch.destroy(client, UTIL.argsToStr(args))
        client.sendSystemMessage "Channel destroyed!"
      else
        client.sendSystemMessage "The channel could not be found!"
    when "status"
      client.sendSystemMessage "======================"
      nulled = 0
      nulled += 1 for c in @clients when c is null
      client.sendSystemMessage "Running with pid #{process.pid} since #{UTIL.secondsToTimestamp(process.uptime())} (on #{process.platform})"
      client.sendSystemMessage "#{@clients.length - nulled} active sessions (#{@clients.length} total, #{nulled}/#{@opts.sessionReindex} nulled)"
      client.sendSystemMessage "#{UTIL.microToHuman(process.cpuUsage().user)}/#{UTIL.microToHuman(process.cpuUsage().system)} CPU (usr/sys)"
      client.sendSystemMessage "#{UTIL.bytesToHuman process.memoryUsage().rss} memory (RSS)"
      client.sendSystemMessage "======================"
    when "invoke"
      target = client
      if (i = args.indexOf("-t")) > -1 || (i = args.indexOf("--target")) > -1
        Client = require("./client.js").Class
        x = args.splice(i, 2)
        who = if typeof x[1] == "string" then x[1] else x[1].pattern
        target = Client.find(client, who, @clients)
      return true unless target
      which = args.shift()
      iargs = UTIL.argsToStr(args) || "{}"
      client.sendCode(which, JSON.parse(iargs))
    when "kick"
      who = args.shift()
      target = Client = require("./client.js").Class.find(client, who, @clients)
      return true unless target
      amsg = "Kicked ##{target.index} #{target.name} (#{target.ip}) from server"
      @info amsg
      client.sendSystemMessage(amsg)
      msg = "You got kicked from the server#{if m = UTIL.argsToStr(args) then " (#{m})" else ""}"
      target.sendCode("session_kicked", reason: msg)
      target.sendSystemMessage(msg)
      target.connection.close()
    when "dump"
      what = args[0]
      detail = args[1]
      if what == "client"
        console.log if detail then @clients[parseInt(detail)] else client
      else if what == "channel"
        console.log if detail then @channels[detail] else if client.subscribed then client.subscribed else @channels
  return client.ack()

x.addCommand "Channel", "retry", (client) ->
  return unless ch = client.subscribed
  ch.revokeControl(client)
  ch.unsubscribe(client)
  ch.subscribe(client)
  return client.ack()

x.addCommand "Channel", "p", "pause", (client) ->
  return client.permissionDenied("pause") unless @control.indexOf(client) > -1
  @desired.state = "pause"
  @broadcastCode(false, "desired", @desired)
  return client.ack()

x.addCommand "Channel", "r", "resume", (client) ->
  return client.permissionDenied("resume") unless @control.indexOf(client) > -1
  @desired.state = "play"
  @broadcastCode(false, "desired", @desired)
  return client.ack()

x.addCommand "Channel", "t", "toggle", (client) ->
  return client.permissionDenied("toggle") unless @control.indexOf(client) > -1
  @desired.state = if @desired.state == "play" then "pause" else "play"
  @broadcastCode(false, "desired", @desired)
  return client.ack()

x.addCommand "Channel", "s", "seek", (client, to) ->
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

x.addCommand "Channel", "sync", "resync", (client, args...) ->
  target = [client]
  instant = false
  if (i = args.indexOf("-i")) > -1 || (i = args.indexOf("--instant")) > -1
    args.splice(i, 1)
    instant = true

  if (i = args.indexOf("-t")) > -1 || (i = args.indexOf("--target")) > -1
    x = args.splice(i, 2)
    return client.permissionDenied("resync-target") unless @control.indexOf(client) > -1
    Client = require("./client.js").Class
    who = x[1]
    found = Client.find(client, who, @subscribers)
    target = if found == client then false else [found]

  if (i = args.indexOf("-a")) > -1 || (i = args.indexOf("--all")) > -1
    args.splice(i, 1)
    return client.permissionDenied("resync-all") unless @control.indexOf(client) > -1
    target = @subscribers

  if target && target.length
    for t in target
      if instant
        t?.sendCode("desired", Object.assign({}, @desired, {force: true}))
      else
        t?.sendCode("video_action", action: "sync")
  else
    client.sendSystemMessage("Found no targets")

  return client.ack()

x.addCommand "Channel", "ready", (client) ->
  @ready.push(client)
  if @ready.length == @subscribers.length
    clearTimeout(@ready_timeout)
    @desired.state = "play"
    @broadcastCode(false, "video_action", action: "play")
  return client.ack()

x.addCommand "Channel", "play", "yt", "youtube", (client, url) ->
  return client.permissionDenied("play") unless @control.indexOf(client) > -1
  if m = url.match(/([A-Za-z0-9_\-]{11})/)
    @liveVideo(m[1])
  else
    client.sendSystemMessage("I don't recognize this URL/YTID format, sorry")

  return client.ack()

x.addCommand "Channel", "loop", (client, what) ->
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

x.addCommand "Channel", "url", "browse", (client, url, ctype = "HtmlFrame") ->
  return client.permissionDenied("browse-#{ctype}") unless @control.indexOf(client) > -1
  @liveUrl(url, ctype)
  return client.ack()

x.addCommand "Channel", "img", "image", "pic", "picture", "gif", "png", "jpg", (client, url) -> module.exports.Channel.browse.call(this, client, url, "HtmlImage")
x.addCommand "Channel", "vid", "video", "mp4", "webp", (client, url) -> module.exports.Channel.browse.call(this, client, url, "HtmlVideo")

x.addCommand "Channel", "leave", "quit", (client) ->
  if ch = client.subscribed
    ch.unsubscribe(client)
  else
    client.sendSystemMessage("You are not in any channel!")

  return client.ack()

x.addCommand "Channel", "password", (client, new_password, revoke) ->
  if ch = client.subscribed
    if ch.control.indexOf(client) > -1
      if typeof new_password == "string"
        ch.password = if new_password then new_password else undefined
        revoke = UTIL.strbool(revoke, false)
        client.sendSystemMessage("Password changed#{if revoke then ", revoked all but you" else ""}!")
        if revoke
          for cu in ch.control
            continue if cu == client
            ch.revokeControl(cu, true, "channel password changed")
      else
        client.sendSystemMessage("New password required! (you can use \"\")")
    else
      client.sendSystemMessage("You are not in control!")
  else
    client.sendSystemMessage("You are not in any channel!")

  return client.ack()

x.addCommand "Channel", "kick", (client, who, args...) ->
  if ch = client.subscribed
    if ch.control.indexOf(client) > -1
      target = Client = require("./client.js").Class.find(client, who, ch.subscribers)
      return true unless target
      if target == client
        client.sendSystemMessage("You want to kick yourself?")
        return client.ack()
      amsg = "Kicked ##{target.index} #{target.name} (#{target.ip}) from channel #{ch.name}"
      @info amsg
      client.sendSystemMessage(amsg)
      msg = "You got kicked from the channel#{if m = UTIL.argsToStr(args) then " (#{m})" else ""}"
      target.sendCode("kicked", reason: msg)
      target.sendSystemMessage(msg)
      ch.unsubscribe(target)
    else
      client.sendSystemMessage("You are not in control!")
  else
    client.sendSystemMessage("You are not in any channel!")

  return client.ack()

x.addCommand "Channel", "host", (client, who) ->
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

x.addCommand "Channel", "grant", (client, who) ->
  return client.permissionDenied("grantControl") unless @control.indexOf(client) > -1
  return true unless who = @findClient(client, who)

  if @control.indexOf(who) > -1
    client.sendSystemMessage("#{who?.name || "Target"} is already in control")
  else
    @grantControl(who)
    client.sendSystemMessage("#{who?.name || "Target"} is now in control!", COLORS.green)

  return client.ack()

x.addCommand "Channel", "revoke", (client, who) ->
  return client.permissionDenied("revokeControl") unless @control.indexOf(client) > -1
  return true unless who = @findClient(client, who)

  if @control.indexOf(who) > -1
    @revokeControl(who)
    client.sendSystemMessage("#{who?.name || "Target"} is no longer in control!", COLORS.green)
  else
    client.sendSystemMessage("#{who?.name || "Target"} was not in control")

  return client.ack()
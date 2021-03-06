COLORS = require("./colors.js")
UTIL = require("./util.js")
Channel = require("./channel.js").Class
Client = require("./client.js").Class

x = module.exports =
  handleMessage: (server, client, message, msg) ->
    try
      return @Server["packet"].call(server, client, m[1]) if m = msg.match(/^!packet:(.+)$/i)
      chunks = []
      cmd = null
      if msg && msg.charAt(0) == "/"
        chunks = UTIL.shellSplit(msg.substr(1))
        cmd = chunks.shift()

      return if cmd && @Server[cmd]?.call(server, client, chunks...)
      if ch = client.subscribed
        return if cmd && @Channel[cmd]?.call(ch, client, chunks...)
        ch.broadcastChat(client, msg, null, ch.clientColor(client))
        return client.ack()

      return client.ack()
    catch err
      server.error err
      client.sendSystemMessage("Sorry, the server encountered an error")
      return client.ack()

  addCommand: (parent, cmds..., proc) ->
    for cmd in cmds
      do (cmd) =>
        console.warn("[ST-WARN] ", new Date, "Overwriting handler for existing command #{parent}.#{cmd}") if x[parent][cmd]
        x[parent][cmd] = proc

  Server: {}
  Channel: {}

x.addCommand "Server", "clip", (client) ->
  client.sendCode("ui_clipboard_poll", action: "permission")
  client.ack()

x.addCommand "Server", "clear", (client) ->
  client.sendCode("ui_clear", component: "chat")
  client.ack()

x.addCommand "Server", "tc", "togglechat", (client) ->
  client.sendCode("ui_chat", action: "toggle")
  client.ack()

x.addCommand "Server", "tpl", "togglepl", "toggleplaylist", (client) ->
  client.sendCode("ui_playlist", action: "toggle")
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
      if json.state == "ended" && ch.desired.state != json.state
        ch.desired.state = json.state
        ch.playlistManager?.handleEnded()
      ch.desired.seek = json.seek
      ch.desired.seek_update = new Date()
      ch.broadcastCode(false, "desired", Object.assign({}, ch.desired, { force: Math.abs(ch.desired.seek - seek_was) > (@opts.packetInterval + 0.75) }))
  else
    client.sendCode("desired", ch.desired) if ch
  return true

x.addCommand "Server", "rpc", (client, args...) ->
  key = UTIL.extractArg(args, ["-k", "--key"], 1)?[0]
  channel = UTIL.extractArg(args, ["-c", "--channel"], 1)?[0]

  # authentication
  if channel
    if cobj = @channels[channel]
      if key? && key == cobj.getRPCKey()
        cobj.debug "granted control to RPC client ##{client.index}(#{client.ip})"
        cobj.control.push(client)
        client.control = cobj
      else
        client.sendRPCResponse error: "Authentication failed"
        return
    else
      client.sendRPCResponse error: "No such channel"
      return
  else if !channel
    client.sendRPCResponse error: "Server RPC not allowed"
    return

  # available actions
  action = args.shift()
  try
    switch action
      when "play", "yt", "youtube"
        module.exports.Channel.youtube.call(cobj, client, args...)
      when "browse", "url"
        module.exports.Channel.browse.call(cobj, client, args...)
      when "vid", "video", "mp4", "webp"
        module.exports.Channel.video.call(cobj, client, args...)
      when "img", "image", "pic", "picture", "gif", "png", "jpg"
        module.exports.Channel.image.call(cobj, client, args...)
      else
        client.sendRPCResponse error: "Unknown RPC action"
  catch err
    @error "[RPC]", err
    client.sendRPCResponse error: "Unknown RPC error"

  return client.ack()

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
    client.sendSystemMessage "Usage: /rename &lt;new_name&gt;"
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
      return process.exit(1)
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
        success = true
        try
          dur = UTIL.parseEasyDuration(args.shift())
          time = new Date((new Date).getTime() + UTIL.timestamp2Seconds(dur.toString()) * 1000)
        catch e
          success = false
          client.sendSystemMessage("Invalid duration format (timestamp or EasyDuration)")

        if success
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
      client.sendSystemMessage "Running with pid #{process.pid} for #{UTIL.secondsToTimestamp(process.uptime())} (on #{process.platform})"
      client.sendSystemMessage "#{@clients.length - nulled} active sessions (#{@clients.length} total, #{nulled}/#{@opts.sessionReindex} nulled)"
      client.sendSystemMessage "#{UTIL.microToHuman(process.cpuUsage().user)}/#{UTIL.microToHuman(process.cpuUsage().system)} CPU (usr/sys)"
      client.sendSystemMessage "#{UTIL.bytesToHuman process.memoryUsage().rss} memory (RSS)"
      client.sendSystemMessage "======================"
    when "clients"
      client.sendSystemMessage "======================"
      for c in @clients when c?
        client.sendSystemMessage """
          <span class="soft_elli" style="min-width: 45px">[##{c.index}]</span>
          <span class="elli" style="width: 100px; margin-bottom: -4px">#{c.name || "<em>unnamed</em>"}</span>
          <span>#{c.ip}</span>
        """
      client.sendSystemMessage "======================"
    when "banip"
      ip = args.shift()

      unless ip?
        client.sendSystemMessage("Usage: /system banip &lt;ip&gt; [duration] [message]")
        return client.ack()

      dur = args.shift()
      reason = args.join(" ")
      dur = -1 if dur == "permanent"
      dur = UTIL.parseEasyDuration(dur)
      seconds = try UTIL.timestamp2Seconds("#{dur}") catch e then UTIL.timestamp2Seconds("1:00:00")
      stamp = if dur == -1 then "eternity" else UTIL.secondsToTimestamp(seconds, false)
      @banIp(ip, dur, reason)

      amsg = "Banned IP #{ip} (#{reason || "no reason"}) for #{stamp}"
      @info amsg
      client.sendSystemMessage(amsg)
    when "unbanip"
      ip = args[0]
      if b = @banned.get(ip)
        client.sendSystemMessage("Removed ban for IP #{ip} with expiry #{if b then b else "never"}")
        @banned.purge(ip)
      else
        client.sendSystemMessage("No ban found for IP #{ip}")
    when "invoke"
      target = client
      if x = UTIL.extractArg(args, ["-t", "--target"], 1)
        Client = require("./client.js").Class
        who = if typeof x[0] == "string" then x[0] else x[0].pattern
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
      else if what == "commands"
        console.log module.exports
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
  instant = UTIL.extractArg(args, ["-i", "--instant"])

  if x = UTIL.extractArg(args, ["-t", "--target"], 1)
    return client.permissionDenied("resync-target") unless @control.indexOf(client) > -1
    Client = require("./client.js").Class
    found = Client.find(client, x[0], @subscribers)
    target = if found == client then false else [found]

  if UTIL.extractArg(args, ["-a", "--all"])
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
  return client.ack() unless @ready
  @ready.push(client) unless @ready.indexOf(client) > -1
  if @ready.length == @subscribers.length
    @ready = false
    clearTimeout(@ready_timeout)
    @desired.state = "play"
    @broadcastCode(false, "video_action", action: "resume", reason: "allReady", cancelPauseEnsured: true)
  return client.ack()

x.addCommand "Channel", "play", "yt", "youtube", (client, args...) ->
  return client.permissionDenied("play") unless @control.indexOf(client) > -1
  return client.ack() if @playlistManager.ensurePlaylistQuota(client)
  playNext = UTIL.extractArg(args, ["-n", "--next"])
  intermission = UTIL.extractArg(args, ["-i", "--intermission"])
  url = args.join(" ")

  if m = url.match(/([A-Za-z-0-9_\-]{11})/)
    @play("Youtube", m[1], playNext, intermission)
    client.sendRPCResponse(success: "Video successfully added to playlist")
  else
    client.sendRPCResponse(error: "I don't recognize this URL/YTID format, sorry")
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

x.addCommand "Channel", "url", "browse", (client, args...) ->
  return client.permissionDenied("browse-#{ctype}") unless @control.indexOf(client) > -1
  return client.ack() if @playlistManager.ensurePlaylistQuota(client)

  playNext = UTIL.extractArg(args, ["-n", "--next"])
  intermission = UTIL.extractArg(args, ["-i", "--intermission"])
  ctype = "HtmlFrame"
  ctype = "HtmlImage" if UTIL.extractArg(args, ["--x-HtmlImage"])
  ctype = "HtmlVideo" if UTIL.extractArg(args, ["--x-HtmlVideo"])

  url = args.join(" ")
  url = "https://#{url}" unless UTIL.startsWith(url, "http://", "https://")
  @play(ctype, url, playNext, intermission)
  return client.ack()

x.addCommand "Channel", "img", "image", "pic", "picture", "gif", "png", "jpg", (client, args...) ->
  module.exports.Channel.browse.call(this, client, args..., "--x-HtmlImage")

x.addCommand "Channel", "vid", "video", "mp4", "webp", (client, args...) ->
  module.exports.Channel.browse.call(this, client, args..., "--x-HtmlVideo")

x.addCommand "Channel", "leave", "quit", (client) ->
  if ch = client.subscribed
    ch.unsubscribe(client)
    client.sendCode("desired", ctype: "StuiCreateForm")
  else
    client.sendSystemMessage("You are not in any channel!")

  return client.ack()

x.addCommand "Channel", "password", (client, new_password, revoke) ->
  if ch = client.subscribed
    if ch.control.indexOf(client) > -1
      if typeof new_password == "string"
        ch.persisted.set("password", if new_password then new_password else undefined)
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
      ch.unsubscribe(target)
      target.sendCode("kicked", reason: msg)
      target.sendSystemMessage(msg)
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
    newHost.sendCode("taken_host", channel: @name)
    wasHost.sendCode("lost_host", channel: @name)
    @updateSubscriberList(client)
  else
    client.sendSystemMessage("#{who?.name || "Target"} is not in control and thereby can't be host")

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

x.addCommand "Channel", "rpckey", (client) ->
  return client.permissionDenied("rpckey") unless @control.indexOf(client) > -1
  client.sendSystemMessage("RPC-Key for this channel: #{@getRPCKey()}")
  client.sendSystemMessage("The key will change with the channel password!", COLORS.warning)
  return client.ack()

x.addCommand "Channel", "bookmarklet", (client, args...) ->
  return client.permissionDenied("bookmarklet") unless @control.indexOf(client) > -1

  showHelp = UTIL.extractArg(args, ["-h", "--help"])
  withNotification = UTIL.extractArg(args, ["-n", "--notifications"])
  desiredAction = UTIL.extractArg(args, ["-a", "--action"], 1)?[0] || "yt"
  label = UTIL.extractArg(args, ["-l", "--label"], 1)?[0] || "+ SyncTube (#{desiredAction.toUpperCase()})"

  if showHelp
    client.sendSystemMessage("Usage: /bookmarklet [-h --help] | [-a --action=youtube] [-n --notifications] [-l --label LABEL]", COLORS.info)
    client.sendSystemMessage(" Action might be one of: youtube video image url", COLORS.white)
    client.sendSystemMessage(" Notifications will show you the result if enabled for youtube.com", COLORS.white)
    client.sendSystemMessage(" Label is the name of the button, you can change that in your browser too", COLORS.white)
    client.sendSystemMessage("The embedded key will change with the channel password!", COLORS.warning)
    return client.ack()

  if withNotification
    script = """(function(b){n=Notification;x=function(a){h="%wsurl%";s="https://statics.bmonkeys.net/img/rpcico/";w=window;w.stwsb=w.stwsb||[];if(w.stwsc){if(w.stwsc.readyState!=1){w.stwsb.push(a)}else{w.stwsc.send(a)}}else{w.stwsb.push("rpc_client");w.stwsb.push(a);w.stwsc=new WebSocket(h);w.stwsc.onmessage=function(m){j=JSON.parse(m.data);if(j.type=="rpc_response"){new n("SyncTube",{body:j.data.message,icon:s+j.data.type+".png"})}};w.stwsc.onopen=function(){while(w.stwsb.length){w.stwsc.send(w.stwsb.shift())}};w.stwsc.onerror=function(){alert("stwscError: failed to connect to "+h);console.error(arguments[0])};w.stwsc.onclose=function(){w.stwsc=null}}};if(n.permission==="granted"||n.permission==="denied"){x(b)}else{n.requestPermission().then(function(result){x(b)})}})("/rpc -k %key% -c %channel% %action% "+window.location)"""
  else
    script = """(function(a){h="%wsurl%";w=window;w.stwsb=w.stwsb||[];if(w.stwsc){if(w.stwsc.readyState!=1){w.stwsb.push(a)}else{w.stwsc.send(a)}}else{w.stwsb.push("rpc_client");w.stwsb.push(a);w.stwsc=new WebSocket(h);w.stwsc.onopen=function(){while(w.stwsb.length){w.stwsc.send(w.stwsb.shift())}};w.stwsc.onerror=function(){alert("stwscError: failed to connect to "+h);console.error(arguments[0])};w.stwsc.onclose=function(){w.stwsc=null}}})("/rpc -k %key% -c %channel% %action% "+window.location)"""

  wsurl = client.request.origin.replace(/^https:\/\//, "wss://").replace(/^http:\/\//, "ws://")
  wsurl += "/#{client.request.resourceURL.pathname}"
  script = script.replace "%wsurl%", wsurl
  script = script.replace "%channel%", @name
  script = script.replace "%key%", @getRPCKey()
  script = script.replace "%action%", desiredAction
  client.sendSystemMessage("""
    The embedded key will change with the channel password!<br>
    <span style="color: #{COLORS.info}">Drag the following button to your bookmark bar:</span>
    <a href="javascript:#{encodeURIComponent script}" class="btn btn-primary btn-xs" style="font-size: 10px">#{label}</a>
  """, COLORS.warning)
  return client.ack()

x.addCommand "Channel", "copt", (client, opt, value) ->
  return client.permissionDenied("copt") unless @control.indexOf(client) > -1
  return true unless who = @findClient(client, who)

  if opt
    if @options.hasOwnProperty(opt)
      ok = opt
      ov = @options[opt]
      ot = typeof ov
      if value?
        try
          if ot == "number"
            nv = if !isNaN(x = Number(value)) then x else throw "value must be a number"
          else if ot == "boolean"
            nv = if (x = UTIL.strbool(value, null))? then x else throw "value must be a boolean(like)"
          else if ot == "string"
            nv = value
          else
            throw "unknown option value type (#{ot})"

          throw "value hasn't changed" if nv == ov
          @options[opt] = nv
          @sendSettings()

          c.sendSystemMessage("""
            <span style="color: #{COLORS.warning}">CHANGED</span> channel option
            <span style="color: #{COLORS.info}">#{ok}</span>
            from <span style="color: #{COLORS.magenta}">#{ov}</span>
            to <span style="color: #{COLORS.magenta}">#{nv}</span>
          """, COLORS.white) for c in @control
        catch err
          client.sendSystemMessage("Failed to change channel option: #{err}")
      else
        client.sendSystemMessage("""
          <span style="color: #{COLORS.info}">#{ok}</span>
          is currently set to <span style="color: #{COLORS.magenta}">#{ov}</span>
          <em style="color: #{COLORS.muted}">(#{ot})</em>
        """, COLORS.white)
    else
      client.sendSystemMessage("Unknown option!")
  else
    cols = ["The following channel options are available:"]
    for ok, ov of @options
      cols.push """
        <span style="color: #{COLORS.info}">#{ok}</span>
        <span style="color: #{COLORS.magenta}">#{ov}</span>
        <em style="color: #{COLORS.muted}">#{typeof ov}</em>
      """
    client.sendSystemMessage(cols.join("<br>"), COLORS.white)
  return client.ack()

# requires
http = require('http');
fs = require('fs');
webSocketServer = require('websocket').server;

COLORS =
  green: "#62c462", success: "#62c462"
  red: "#ee5f5b", danger: "#ee5f5b"
  yellow: "#f89406", warning: "#f89406"
  aqua: "#5bc0de", info: "#5bc0de"
  muted: "#7a8288"

class SyncTubeServer
  SERVE_STATIC: [
    "/"
    "/favicon.ico"
    "/dist/client.js"
  ]

  PROTECTED_NAMES: [
    "admin"
    "system"
  ]

  DEFAULT_VIDEO: "6Dh-RL__uN4"
  DEFAULT_AUTOPLAY: false

  debug: (msg...) ->
    return unless @opts.debug
    msg.unshift new Date
    msg.unshift "[ST]"
    console.debug.apply(@, msg)

  warn: (msg...) ->
    msg.unshift new Date
    msg.unshift "[ST]"
    console.warn.apply(@, msg)

  error: (msg...) ->
    msg.unshift new Date
    msg.unshift "[ST]"
    console.error.apply(@, msg)

  constructor: (@opts = {}) ->
    # set process title
    process.title = 'synctube-server';

    # options
    @opts.debug     ?= false
    @opts.ws_port   ?= 1337 # Don't forget to change in client as well

    @clients = []
    @channels = {}

  listen: ->
    throw "HTTP server is already bound!" if @http
    @debug "Creating HTTP server..."
    @http = http.createServer((a...) => @handleHTTPRequest(a...))

    @debug "Binding HTTP/WS server on port #{@opts.ws_port}..."
    @http.listen @opts.ws_port, => @debug "HTTP/WS server is listening on port #{@opts.ws_port}!"

    # create WS socket server
    @ws = new webSocketServer httpServer: @http
    @ws.on "request", (request) => @handleWSRequest(request)

  htmlEntities: (str) ->
    String(str)
      .replace(/&/g, '&amp;').replace(/</g, '&lt;')
      .replace(/>/g, '&gt;').replace(/"/g, '&quot;')

  delay: (ms, func) -> setTimeout(func, ms)

  eachClient: (method, args...) -> c[method]?(args...) for c in @clients

  handleHTTPRequest: (request, response) ->
    if @SERVE_STATIC.indexOf(request.url) > -1
      file = request.url
      file = "/index.html" if file == "/"
      file = ".#{file}"
      type = "text/html"
      type = "application/javascript" if file.slice(-3) == ".js"
      if fs.existsSync(file)
        @debug "200: served #{file} (#{type}) IP: #{request.connection.remoteAddress}"
        response.writeHead(200, 'Content-Type': 'text/html')
        response.end(fs.readFileSync(file))
      else
        @warn "404: Not Found (#{request.url}) IP: #{request.connection.remoteAddress}"
        response.writeHead(404, 'Content-Type': 'text/plain')
        response.end("Error 404: Not Found")
    else
      @warn "400: Bad Request (#{request.url}) IP: #{request.connection.remoteAddress}"
      response.writeHead(400, 'Content-Type': 'text/plain')
      response.end("Error 400: Bad Request")

  handleWSRequest: (request) ->
    client = new Client(this)
    client.accept(request).listen()

  handleMessage: (client, message, msg) ->
    return @SCMD_packet(client, m[1]) if m = msg.match(/!packet:(.+)/i)
    return @SCMD_invoke(client, m[1], m[2]) if m = msg.match(/\/invoke\s([^\s]+)(?:\s(.+))?/i)
    return @SCMD_rename(client) if msg.match(/\/rename/i)
    return @SCMD_restart(client) if m = msg.match(/\/restart/i)
    return @SCMD_retry(client) if m = msg.match(/\/retry/i)
    return @SCMD_control(client, m[1], m[2]) if m = msg.match(/\/control(?:\s([^\s]+)(?:\s(.+))?)?/i)
    return @SCMD_join(client, m[1]) if m = msg.match(/\/join\s([^\s]+)/i)
    return false

  SCMD_packet: (client, jdata) ->
    try
      json = JSON.parse(jdata)
    catch error
      @error "Invalid JSON", jdata, error
      return

    client.lastPacket = new Date
    console.log 1, client.index, client.state?.state
    if !client.state || (JSON.stringify(client.state) != jdata)
      ch = client.subscribed
      console.log 2, client.index, client.state?.state, json.state, ["playing", "buffering", "cued", "ready"].indexOf(client.state?.state)
      ch.updateDesired(client, json)
      console.log "desired", ch.desired.state, "state", ch.playVideo
      ch["#{ch.desired.state}Video"](client)
      client.state = json
      ch.broadcastCode(client, "update_single_subscriber", channel: ch.name, data: ch.getSubscriberData(client, client, client.index)) if ch = client.subscribed
    return true

  SCMD_invoke: (client, which, args) ->
    args ||= "{}"
    client.sendCode(which, JSON.parse(args))
    client.ack()
    return true

  SCMD_rename: (client) ->
    client.sendCode "require_username", autofill: false
    client.old_name = client.name
    client.name = null
    client.sendSystemMessage "Tell me your new username!"
    client.ack()
    return true

  SCMD_restart: (client) ->
    client.sendSystemMessage   "See ya!"
    throw "bye"
    #@delay 1000, => client.sendCode "navigate", reload: true
    return true

  SCMD_retry: (client) ->
    return unless ch = client.subscribed
    ch.revokeControl(client)
    ch.unsubscribe(client)
    ch.subscribe(client)
    return client.ack()

  SCMD_control: (client, name, password) ->
    chname = @htmlEntities(name || client.subscribed?.name || "")
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

  SCMD_join: (client, chname) ->
    if channel = @channels[chname]
      channel.subscribe(client)
    else
      client.sendSystemMessage("I don't know about this channel, sorry!")
      client.sendSystemMessage("<small>You can create it with <strong>/control #{@htmlEntities(chname)} [password]</strong></small>", COLORS.info)

    return client.ack()

  class Channel
    debug: (a...) -> @server.debug("[#{@name}]", a...)
    warn: (a...) -> @server.warn("[#{@name}]", a...)
    error: (a...) -> @server.error("[#{@name}]", a...)

    constructor: (@server, @name, @password) ->
      @control = []
      @subscribers = []
      @queue = []
      @playlist = []
      @playlist_index = 0
      @desired = { url: null, time: 0, state: "pause"}

    handleMessage: (client, message, msg) ->
      @broadcast(client, msg, null, (if @control.indexOf(client) > -1 then COLORS.red else null))

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

    updateDesired: (client) ->
      @desired.url = client.state?.url
      @desired.state = if ["playing", "buffering"].indexOf(client.state?.state) > -1 then "play" else "pause"
      @desired.time = client.state?.seek || 0

    getSubscriberList: (client) ->
      list = []
      list.push(@getSubscriberData(client, c, i)) for c, i in @subscribers
      list

    getSubscriberData: (client, sub, index) ->
      data =
        index: sub.index
        name: sub.name
        control: @control.indexOf(sub) > -1
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
      @broadcastCode(client, "video_action", action: "pause")
      @broadcastCode(client, "video_action", action: "seek", to: client.state.seek, true) if client.state?.seek?

    playVideo: (client, sendMessage = true) ->
      return unless @control.indexOf(client) > -1
      @broadcastCode(client, "video_action", action: "resume")

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
      client.sendCode("load_video", ytid: @server.DEFAULT_VIDEO, cue: !@server.DEFAULT_AUTOPLAY)
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

  class Client
    debug: (a...) -> @server.debug("[##{@index}]", a...)
    warn: (a...) -> @server.warn("[##{@index}]", a...)
    error: (a...) -> @server.error("[##{@index}]", a...)

    constructor: (@server) ->
      @index = -1
      @name ?= null
      @control = null
      @subscribed = null

    accept: (@request) ->
      @debug "Accepting connection from origin #{@request.origin}"
      @connection = @request.accept(null, @request.origin)
      @ip = @connection.remoteAddress
      @index = @server.clients.push(this) - 1
      @connection.on("close", => @disconnect())
      @debug "Connection accepted (#{@index}): #{@ip}"
      @sendCode "require_username"
      return this

    listen: ->
      @connection.on "message", (message) =>
        msg = message.utf8Data
        if message.type != "utf8"
          @warn "Received non-utf8 data", message
          return

        @debug "Received message from #{@ip}: #{msg}"

        if @name
          @server.handleMessage(this, message, msg) || @control?.handleMessage(this, message, msg) || @subscribed?.handleMessage(this, message, msg)
        else
          @setUsername(msg)

      this

    disconnect: ->
      @debug "Peer #{@ip} disconnected."
      @control?.revokeControl?(this)
      @subscribed?.unsubscribe?(this)

      # delete reference and reindex clients
      @server.clients.splice(@index, 1)
      @server.eachClient("reindex")

    reindex: ->
      was_index = @index
      @index = @server.clients.indexOf(this)
      @debug "Reindexed client session from #{was_index} to #{@index}"
      return this

    sendCode: (type, data = {}) ->
      @connection.sendUTF JSON.stringify type: "code", data: Object.assign({}, data, { type: type })
      return this

    sendMessage: (message, color, author, author_color) ->
      @connection.sendUTF JSON.stringify
        type: "message"
        data:
          author: author
          author_color: author_color
          text: message
          text_color: color
          time: (new Date()).getTime()
      return this

    sendSystemMessage: (message, color) -> @sendMessage(message, color || COLORS.red, "system", COLORS.red)

    ack: ->
      @sendCode "ack"
      true

    setUsername: (name) ->
      @name = @server.htmlEntities(name)
      if @server.PROTECTED_NAMES.indexOf(@name.toLowerCase()) > -1
        @name = null
        @sendSystemMessage "This name is not allowed!", COLORS.red
        @sendCode "require_username"
      else
        if @old_name
          if @subscribed
            _name = @name
            @name = @old_name
            @subscribed.broadcast(this, "<i>changed his name to #{_name}</i>", COLORS.info, COLORS.muted)
            @name = _name
          else
            @sendSystemMessage "You changed your name from #{@old_name} to #{@name}!", COLORS.info
          @old_name = null
        else
          @hello()

      @sendCode "username", username: @name
      @ack()

    hello: ->
      @sendSystemMessage "Welcome, #{@name}!", COLORS.green
      @sendSystemMessage "To create or control a channel type <strong>/control &lt;channel&gt; [password]</strong>", COLORS.info
      @sendSystemMessage "To join an existing channel type <strong>/join &lt;channel&gt;</strong>", COLORS.info


server = new SyncTubeServer
  debug: true
  http_port: 1338
server.listen()

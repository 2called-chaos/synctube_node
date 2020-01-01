COLORS = require("./colors.js")
UTIL = require("./util.js")
Commands = require("./commands.js")

exports.Class = class SyncTubeServerClient
  @find: (client, who, collection = @server.clients, context) ->
    return client unless who

    # exact match?
    for sub in collection
      return sub if sub && sub.name.toLowerCase?() == who.toLowerCase?()

    # regex search
    who = "^#{who}" unless who.charAt(0) == "^"
    try
      for sub in collection
        return sub if sub && sub.name.match(new RegExp(who, "i"))
    catch e
      client?.sendSystemMessage(e.message)
      client?.ack()
      return false

    client?.sendSystemMessage("Couldn't find the target#{if context then " in #{context}" else ""}")
    client?.ack()
    return false

  debug: (a...) -> @server.debug("[##{@index}]", a...)
  info: (a...) -> @server.info("[##{@index}]", a...)
  warn: (a...) -> @server.warn("[##{@index}]", a...)
  error: (a...) -> @server.error("[##{@index}]", a...)

  constructor: (@server) ->
    @index = -1
    @name ?= null
    @control = null
    @subscribed = null

  accept: (@request) ->
    @info "Accepting connection from origin #{@request.origin}"
    @connection = @request.accept(null, @request.origin)
    @ip = @connection.remoteAddress
    @index = @server.clients.push(this) - 1
    @connection.on("close", => @disconnect())
    return this if @server.guardBanned(this)
    @info "Connection accepted (#{@index}): #{@ip}"
    @sendCode "session_index", index: @index
    @sendCode "require_username", maxLength: @server.opts.nameMaxLength
    return this

  listen: ->
    @connection.on "message", (message) =>
      msg = message.utf8Data
      if message.type != "utf8"
        @warn "Received non-utf8 data", message
        return

      if !UTIL.startsWith(msg, "!packet") || @server.opts.debug_packets
        @debug "<<< from #{@ip}: #{msg}"

      if @name
        Commands.handleMessage(@server, this, message, msg)
      else
        @setUsername(msg)
        @isRPC = true if @name == "rpc_client"

    return this

  disconnect: ->
    @info "Peer #{@ip} disconnected."
    @control?.revokeControl?(this)
    @subscribed?.unsubscribe?(this)
    @server.nullSession(this)

  reindex: ->
    was_index = @index
    @index = @server.clients.indexOf(this)
    @sendCode "session_index", index: @index
    @subscribed? && @sendCode("subscriber_list", channel: @subscribed.name, subscribers: @subscribed.getSubscriberList(this))
    @debug "Reindexed client session from #{was_index} to #{@index}"
    return this

  permissionDenied: (context) ->
    msg = "You don't have the required permissions to perform this action"
    msg += " (#{context})" if context
    if @isRPC then @sendRPCResponse(error: msg) else @sendSystemMessage(msg)
    return @ack()

  send: (message) ->
    @debug ">>> to #{@ip}: #{message}" if @server.opts.debug_codes
    @connection.send(message)

  sendUTF: (message) ->
    @debug ">>> to #{@ip}: #{message}" if @server.opts.debug_codes
    @connection.sendUTF(message)

  sendCode: (type, data = {}) ->
    @sendUTF JSON.stringify type: "code", data: Object.assign({}, data, { type: type })
    return this

  sendMessage: (message, color, author, author_color, escape = false) ->
    @sendUTF JSON.stringify
      type: "message"
      data:
        author: author
        author_color: author_color
        text: message
        text_color: color
        escape: escape
        time: (new Date()).getTime()
    return this

  sendRPCResponse: (data = {}) ->
    return unless @isRPC

    if data.error?
      data.type = "error"
      data.message = data.error
      delete data["error"]

    if data.success?
      data.type = "success"
      data.message = data.success
      delete data["success"]

    @sendUTF JSON.stringify
      type: "rpc_response"
      data: Object.assign({}, data, { time: (new Date()).getTime() })
    return this

  sendSystemMessage: (message, color) ->
    return if @isRPC
    @sendMessage(message, color || COLORS.red, "system", COLORS.red)

  ack: ->
    @sendCode "ack"
    return true

  isNameProtected: (name) ->
    cname = name.toLowerCase().replace(/[^a-z0-9]+/, "")
    for n in @server.opts.protectedNames
      if UTIL.isRegExp(n)
        return true if cname.match(n)
      else
        return true if n == cname
        cname.indexOf(cname) > -1
    return false

  setUsername: (name) ->
    nameLength = UTIL.trim(name).length
    @old_name = if @name? then @name else null
    @name = UTIL.trim(name)
    if UTIL.startsWith(@name, "!packet:")
      # ignore packets
      @name = @old_name
      return @ack()
    else if nameLength > @server.opts.nameMaxLength
      @name = @old_name
      @sendSystemMessage "Usernames can't be longer than #{@server.opts.nameMaxLength} characters! You've got #{nameLength}", COLORS.red
      return @ack()
    else if @isNameProtected(@name)
      @name = @old_name
      @sendSystemMessage "This name is not allowed!", COLORS.red
      return @ack()
    else if @name.charAt(0) == "/" || @name.charAt(0) == "!" || @name.charAt(0) == "§" || @name.charAt(0) == "$"
      @name = @old_name
      @sendSystemMessage "Name may not start with a / $ § or ! character", COLORS.red
      return @ack()
    else
      if @old_name
        if @subscribed
          _name = @name
          @name = @old_name
          @subscribed.broadcast(this, "<i>changed his name to #{_name}</i>", COLORS.info, COLORS.muted)
          @name = _name
          @subscribed.broadcastCode(this, "update_single_subscriber", channel: @subscribed.name, data: @subscribed.getSubscriberData(this, this, @index))
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
    if @server.pendingRestart?
      @server.handlePendingRestart()
      fdiff = UTIL.secondsToTimestamp((@server.pendingRestart - (new Date).getTime()) / 1000, false)
      @sendSystemMessage "Server will restart in #{fdiff}!"

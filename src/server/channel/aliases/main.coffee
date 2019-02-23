exports._module = module
exports.setup = (@server, classes) ->
  @hookChannelConstructor(classes.Channel, classes.Commands, classes.UTIL)
  @hookCommandsHandleMessage(classes.Commands)
  @registerAlias(classes.Commands, classes.COLORS)

exports.hookChannelConstructor = (klass, Commands, UTIL) ->
  old = klass::init
  klass::init = (a...) ->
    old(a...)
    @persisted.plugin_aliases = @plugin_aliases = {}
    @plugin_aliases.__fetch = (msg) ->
      return if UTIL.startsWith(msg, "!packet:")
      for n, v of this
        continue if typeof v == "function"
        args = false
        if n == msg
          args = []
        else if UTIL.startsWith(msg, "#{n} ")
          argstr = msg.slice(n.length + 1)
          args = UTIL.shellSplit(argstr)
          args.unshift(argstr)

        if args
          commandParts = UTIL.shellSplit(v, Object.assign({}, args))
          return UTIL.shellQuote(commandParts)
      return false

exports.hookCommandsHandleMessage = (klass) ->
  old = klass.handleMessage
  klass.handleMessage = (server, client, message, msg) ->
    try
      msg = al if al = client?.subscribed?.plugin_aliases?.__fetch?(msg)
    catch err
      server.error "Plugin-ChannelAliases:", err
      client.sendSystemMessage("Sorry, the server encountered an error in alias resolution :/")
      return client.ack()

    old.call(this, server, client, message, msg)

exports.registerAlias = (klass, COLORS) ->
  klass.addCommand "Channel", "alias", "aliases", (client, args...) ->
    return client.permissionDenied("alias") unless @control.indexOf(client) > -1
    deleteAlias = false

    # Usage (no args)
    unless args.length
      client.sendSystemMessage("Usage: /alias [-l --list] | &lt;name&gt; [-d --delete] [command]")
      return client.ack()

    formatEntry = (name, command) ->
      return "" if typeof command == "function"
      r = ""
      r += """ <span style="color: #{COLORS.info}">#{name}</span> """
      r += """ => <span style="color: #{COLORS.magenta}">#{command}</span> """ if command?
      r

    # list
    if (i = args.indexOf("-l")) > -1 || (i = args.indexOf("--list")) > -1
      count = Object.keys(@plugin_aliases).length
      if count
        args.splice(i, 1)
        msg = ["#{count} aliases:"]
        msg.push(formatEntry(name, command)) for name, command of @plugin_aliases when typeof command isnt "function"
        client.sendSystemMessage(msg.join("<br>"), COLORS.muted)
      else
        client.sendSystemMessage("No aliases registered so far!")
      return client.ack()

    # delete flag
    if (i = args.indexOf("-d")) > -1 || (i = args.indexOf("--delete")) > -1
      args.splice(i, 1)
      deleteAlias = true

    return client.ack() unless args[0] || deleteAlias
    name = args.shift()
    value = args.join(" ")

    # safeguard :P
    if name == "__fetch"
      client.sendSystemMessage("That ain't a coincidence eh?")
      return client.ack()

    # CRUD
    if current = @plugin_aliases[name]
      if deleteAlias
        delete @plugin_aliases[name]
        client.sendSystemMessage("Removed #{formatEntry(name)}", COLORS.danger)
      else if value
        if value == current
          client.sendSystemMessage("Remains #{formatEntry(name, value)}", COLORS.warning)
        else
          @plugin_aliases[name] = value
          client.sendSystemMessage("Changed #{formatEntry(name, value)}", COLORS.success)
      else
        client.sendSystemMessage(formatEntry(name, current))
    else if value && !deleteAlias
      @plugin_aliases[name] = value
      client.sendSystemMessage("Added #{formatEntry(name, value)}", COLORS.success)
    else
      client.sendSystemMessage("alias not currently set")

    client.ack()

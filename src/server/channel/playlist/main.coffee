exports._module = module
exports.setup = (@server, classes) ->
  @registerPlaylist(classes.Commands, classes.COLORS, classes.UTIL)

exports.registerPlaylist = (klass, COLORS, UTIL) ->
  klass.addCommand "Channel", "playlist", "pl", (client, args...) ->
    return client.permissionDenied("playlist") unless @control.indexOf(client) > -1
    unless @playlistManager
      client.sendSystemMessage("This channel has no playlist manager!")
      return client.ack

    if @options.playlistMode == "disabled"
      client.sendSystemMessage("This channel has disabled playlists!")
      return client.ack

    action = args.shift()
    switch action
      when "list"
        msg = ["Listing #{Object.keys(@playlistManager.data).length} playlists:"]
        for name, data of @playlistManager.data
          r = """<span style="color: #{if @playlistManager.set == name then COLORS.warning else COLORS.info}">#{name}</span>"""
          r += """ => <span style="color: #{COLORS.magenta}">#{data.entries.length} entries</span>"""
          msg.push(r)
        client.sendSystemMessage(msg.join("<br>"), COLORS.muted)
      when "load"
        volatile = UTIL.extractArg(args, ["-v", "--volatile"])
        if !args[0]
          client.sendSystemMessage("Usage: /playlist load &lt;name&gt; [-v --volatile]")
        else if args[0] == @playlistManager.set
          client.sendSystemMessage("Given playlist already active!")
        else if @playlistManager.data[args[0]]
          client.sendSystemMessage("Warning: volatile flag has no effect on existing playlist", COLORS.warning) if volatile
          client.sendSystemMessage("Loading existing playlist #{args[0]}", COLORS.success)
          @playlistManager.load(args[0])
        else
          client.sendSystemMessage("Loading new #{if volatile then "volatile" else ""} playlist #{args[0]}", COLORS.success)
          @playlistManager.load(args[0])
          @playlistManager.sdata().persisted = false if volatile
      when "saveas"
        client.sendSystemMessage("Not implemented")
      when "delete"
        if !args[0]
          client.sendSystemMessage("Usage: /playlist delete &lt;name&gt;")
        else if args[0] == "default"
          client.sendSystemMessage("Cannot delete default playlist, use clear!")
        else if data = @playlistManager.data[args[0]]
          if args[0] == @playlistManager.set
            client.sendSystemMessage("Switching to default playlist...", COLORS.info)
            @playlistManager.load("default")
          client.sendSystemMessage("Purged playlist with #{data.entries.length} entries", COLORS.warning)
          @playlistManager.delete(args[0])
        else
          client.sendSystemMessage("Playlist not found")
      when "clear"
        client.sendSystemMessage("Purged #{@playlistManager.sdata().entries.length} entries", COLORS.warning)
        @playlistManager.clear()
      when "opt"
        avail_opts = [
          "autoPlayNext"
          "autoRemove"
          "loadImageThumbs"
          "loop"
          "maxListSize"
          "persisted"
          "shuffle"
        ]

        unless args[0]
          cols = ["The following playlist options are available:"]
          for ok in avail_opts
            ov = @playlistManager.sdata()[ok]
            cols.push """
              <span style="color: #{COLORS.info}">#{ok}</span>
              <span style="color: #{COLORS.magenta}">#{ov}</span>
              <em style="color: #{COLORS.muted}">#{typeof ov}</em>
            """
          client.sendSystemMessage(cols.join("<br>"), COLORS.white)
          return client.ack()

        unless avail_opts.indexOf(args[0]) > -1
          client.sendSystemMessage("Unknown option!")
          return client.ack()

        ok = args[0]
        ov = @playlistManager.sdata()[ok]
        ot = typeof ov
        value = args[1]

        unless value?
          client.sendSystemMessage("""
            <span style="color: #{COLORS.info}">#{ok}</span>
            is currently set to <span style="color: #{COLORS.magenta}">#{ov}</span>
            <em style="color: #{COLORS.muted}">(#{ot})</em>
          """, COLORS.white)
          return client.ack()

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
          @playlistManager.sdata()[ok] = nv
          c.sendSystemMessage("""
            <span style="color: #{COLORS.warning}">CHANGED</span> playlist option
            <span style="color: #{COLORS.info}">#{ok}</span>
            from <span style="color: #{COLORS.magenta}">#{ov}</span>
            to <span style="color: #{COLORS.magenta}">#{nv}</span>
          """, COLORS.white) for c in @control
        catch err
          client.sendSystemMessage("Failed to change playlist option: #{err}")
      when "next"
        client.sendSystemMessage("Not implemented")
      when "prev"
        client.sendSystemMessage("Not implemented")
      when "play"
        if args[0]?
          index = parseInt(args[0])
          if @playlistManager.sdata().entries[index]
            @playlistManager.cPlayI(args[0])
          else
            client.sendSystemMessage("Current playlist has no such index")
        else
          client.sendSystemMessage("Usage: /playlist play &lt;index&gt;")
      when "remove"
        if args[0]?
          index = parseInt(args[0])
          if @playlistManager.sdata().entries[index]
            @playlistManager.removeItemAtIndex(args[0])
            client.sendSystemMessage("Removed entry successfully", COLORS.success)
          else
            client.sendSystemMessage("Current playlist has no such index")
        else
          client.sendSystemMessage("Usage: /playlist remove &lt;index&gt;")
      else
        # Usage (no args)
        client.sendSystemMessage("Usage: /playlist list")
        client.sendSystemMessage("Usage: /playlist load &lt;name&gt; [-v --volatile]")
        client.sendSystemMessage("Usage: /playlist saveas &lt;name&gt;")
        client.sendSystemMessage("Usage: /playlist delete &lt;name&gt;")
        client.sendSystemMessage("Usage: /playlist clear")
        client.sendSystemMessage("Usage: /playlist opt [option] [newvalue]")
        client.sendSystemMessage("Usage: /playlist next/prev")
        client.sendSystemMessage("Usage: /playlist play/remove &lt;index&gt;")

    client.ack()

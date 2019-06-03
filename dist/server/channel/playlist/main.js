// Generated by CoffeeScript 2.3.2
(function() {
  exports._module = module;

  exports.setup = function(server, classes) {
    this.server = server;
    return this.registerPlaylist(classes.Commands, classes.COLORS, classes.UTIL);
  };

  exports.registerPlaylist = function(klass, COLORS, UTIL) {
    return klass.addCommand("Channel", "playlist", "pl", function(client, ...args) {
      var action, avail_opts, c, cols, data, err, i, index, j, len, len1, msg, name, nv, ok, ot, ov, r, ref, ref1, value, volatile, x;
      if (!(this.control.indexOf(client) > -1)) {
        return client.permissionDenied("playlist");
      }
      if (!this.playlistManager) {
        client.sendSystemMessage("This channel has no playlist manager!");
        return client.ack;
      }
      if (this.options.playlistMode === "disabled") {
        client.sendSystemMessage("This channel has disabled playlists!");
        return client.ack;
      }
      action = args.shift();
      switch (action) {
        case "list":
          msg = [`Listing ${(Object.keys(this.playlistManager.data).length)} playlists:`];
          ref = this.playlistManager.data;
          for (name in ref) {
            data = ref[name];
            r = `<span style="color: ${(this.playlistManager.set === name ? COLORS.warning : COLORS.info)}">${name}</span>`;
            r += ` => <span style="color: ${COLORS.magenta}">${data.entries.length} entries</span>`;
            msg.push(r);
          }
          client.sendSystemMessage(msg.join("<br>"), COLORS.muted);
          break;
        case "load":
          volatile = UTIL.extractArg(args, ["-v", "--volatile"]);
          if (!args[0]) {
            client.sendSystemMessage("Usage: /playlist load &lt;name&gt; [-v --volatile]");
          } else if (args[0] === this.playlistManager.set) {
            client.sendSystemMessage("Given playlist already active!");
          } else if (this.playlistManager.data[args[0]]) {
            if (volatile) {
              client.sendSystemMessage("Warning: volatile flag has no effect on existing playlist", COLORS.warning);
            }
            client.sendSystemMessage(`Loading existing playlist ${args[0]}`, COLORS.success);
            this.playlistManager.load(args[0]);
          } else {
            client.sendSystemMessage(`Loading new ${(volatile ? "volatile" : "")} playlist ${args[0]}`, COLORS.success);
            this.playlistManager.load(args[0]);
            if (volatile) {
              this.playlistManager.sdata().persisted = false;
            }
          }
          break;
        case "saveas":
          client.sendSystemMessage("Not implemented");
          break;
        case "delete":
          if (!args[0]) {
            client.sendSystemMessage("Usage: /playlist delete &lt;name&gt;");
          } else if (args[0] === "default") {
            client.sendSystemMessage("Cannot delete default playlist, use clear!");
          } else if (data = this.playlistManager.data[args[0]]) {
            if (args[0] === this.playlistManager.set) {
              client.sendSystemMessage("Switching to default playlist...", COLORS.info);
              this.playlistManager.load("default");
            }
            client.sendSystemMessage(`Purged playlist with ${data.entries.length} entries`, COLORS.warning);
            this.playlistManager.delete(args[0]);
          } else {
            client.sendSystemMessage("Playlist not found");
          }
          break;
        case "clear":
          client.sendSystemMessage(`Purged ${(this.playlistManager.sdata().entries.length)} entries`, COLORS.warning);
          this.playlistManager.clear();
          break;
        case "opt":
          avail_opts = ["autoPlayNext", "autoRemove", "loadImageThumbs", "loop", "maxListSize", "persisted", "shuffle"];
          if (!args[0]) {
            cols = ["The following playlist options are available:"];
            for (i = 0, len = avail_opts.length; i < len; i++) {
              ok = avail_opts[i];
              ov = this.playlistManager.sdata()[ok];
              cols.push(`<span style="color: ${COLORS.info}">${ok}</span>\n<span style="color: ${COLORS.magenta}">${ov}</span>\n<em style="color: ${COLORS.muted}">${typeof ov}</em>`);
            }
            client.sendSystemMessage(cols.join("<br>"), COLORS.white);
            return client.ack();
          }
          if (!(avail_opts.indexOf(args[0]) > -1)) {
            client.sendSystemMessage("Unknown option!");
            return client.ack();
          }
          ok = args[0];
          ov = this.playlistManager.sdata()[ok];
          ot = typeof ov;
          value = args[1];
          if (value == null) {
            client.sendSystemMessage(`<span style="color: ${COLORS.info}">${ok}</span>\nis currently set to <span style="color: ${COLORS.magenta}">${ov}</span>\n<em style="color: ${COLORS.muted}">(${ot})</em>`, COLORS.white);
            return client.ack();
          }
          try {
            if (ot === "number") {
              nv = (function() {
                if (!isNaN(x = Number(value))) {
                  return x;
                } else {
                  throw "value must be a number";
                }
              })();
            } else if (ot === "boolean") {
              nv = (function() {
                if ((x = UTIL.strbool(value, null)) != null) {
                  return x;
                } else {
                  throw "value must be a boolean(like)";
                }
              })();
            } else if (ot === "string") {
              nv = value;
            } else {
              throw `unknown option value type (${ot})`;
            }
            if (nv === ov) {
              throw "value hasn't changed";
            }
            this.playlistManager.sdata()[ok] = nv;
            ref1 = this.control;
            for (j = 0, len1 = ref1.length; j < len1; j++) {
              c = ref1[j];
              c.sendSystemMessage(`<span style="color: ${COLORS.warning}">CHANGED</span> playlist option\n<span style="color: ${COLORS.info}">${ok}</span>\nfrom <span style="color: ${COLORS.magenta}">${ov}</span>\nto <span style="color: ${COLORS.magenta}">${nv}</span>`, COLORS.white);
            }
          } catch (error) {
            err = error;
            client.sendSystemMessage(`Failed to change playlist option: ${err}`);
          }
          break;
        case "next":
          client.sendSystemMessage("Not implemented");
          break;
        case "prev":
          client.sendSystemMessage("Not implemented");
          break;
        case "play":
          if (args[0] != null) {
            index = parseInt(args[0]);
            if (this.playlistManager.sdata().entries[index]) {
              this.playlistManager.cPlayI(args[0]);
            } else {
              client.sendSystemMessage("Current playlist has no such index");
            }
          } else {
            client.sendSystemMessage("Usage: /playlist play &lt;index&gt;");
          }
          break;
        case "remove":
          if (args[0] != null) {
            index = parseInt(args[0]);
            if (this.playlistManager.sdata().entries[index]) {
              this.playlistManager.removeItemAtIndex(args[0]);
              client.sendSystemMessage("Removed entry successfully", COLORS.success);
            } else {
              client.sendSystemMessage("Current playlist has no such index");
            }
          } else {
            client.sendSystemMessage("Usage: /playlist remove &lt;index&gt;");
          }
          break;
        default:
          // Usage (no args)
          client.sendSystemMessage("Usage: /playlist list");
          client.sendSystemMessage("Usage: /playlist load &lt;name&gt; [-v --volatile]");
          client.sendSystemMessage("Usage: /playlist saveas &lt;name&gt;");
          client.sendSystemMessage("Usage: /playlist delete &lt;name&gt;");
          client.sendSystemMessage("Usage: /playlist clear");
          client.sendSystemMessage("Usage: /playlist opt [option] [newvalue]");
          client.sendSystemMessage("Usage: /playlist next/prev");
          client.sendSystemMessage("Usage: /playlist play/remove &lt;index&gt;");
      }
      return client.ack();
    });
  };

}).call(this);

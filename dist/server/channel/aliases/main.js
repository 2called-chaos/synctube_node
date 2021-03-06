// Generated by CoffeeScript 2.3.2
(function() {
  exports._module = module;

  exports.setup = function(server1, classes) {
    this.server = server1;
    this.hookChannelConstructor(classes.Channel, classes.Commands, classes.UTIL);
    this.hookCommandsHandleMessage(classes.Commands);
    return this.registerAlias(classes.Commands, classes.COLORS, classes.UTIL);
  };

  exports.hookChannelConstructor = function(klass, Commands, UTIL) {
    var old;
    old = klass.prototype.init;
    return klass.prototype.init = function(...a) {
      old(...a);
      if (!this.persisted.hasKey("plugin_aliases")) {
        this.persisted.set("plugin_aliases", {});
      }
      this.persisted.beforeSave((ps, store) => {
        return ps.rem("__fetch");
      });
      this.plugin_aliases = this.persisted.get("plugin_aliases");
      return this.plugin_aliases.__fetch = function(msg) {
        var args, argstr, commandParts, n, ref, v;
        if (UTIL.startsWith(msg, "!packet:")) {
          return;
        }
        ref = this;
        for (n in ref) {
          v = ref[n];
          if (typeof v === "function") {
            continue;
          }
          args = false;
          if (n === msg) {
            args = [];
          } else if (UTIL.startsWith(msg, `${n} `)) {
            argstr = msg.slice(n.length + 1);
            args = UTIL.shellSplit(argstr);
            args.unshift(argstr);
          }
          if (args) {
            commandParts = UTIL.shellSplit(v, Object.assign({}, args));
            return UTIL.shellQuote(commandParts);
          }
        }
        return false;
      };
    };
  };

  exports.hookCommandsHandleMessage = function(klass) {
    var old;
    old = klass.handleMessage;
    return klass.handleMessage = function(server, client, message, msg) {
      var al, err, ref, ref1;
      try {
        if (al = client != null ? (ref = client.subscribed) != null ? (ref1 = ref.plugin_aliases) != null ? typeof ref1.__fetch === "function" ? ref1.__fetch(msg) : void 0 : void 0 : void 0 : void 0) {
          msg = al;
        }
      } catch (error) {
        err = error;
        server.error("Plugin-ChannelAliases:", err);
        client.sendSystemMessage("Sorry, the server encountered an error in alias resolution :/");
        return client.ack();
      }
      return old.call(this, server, client, message, msg);
    };
  };

  exports.registerAlias = function(klass, COLORS, UTIL) {
    return klass.addCommand("Channel", "alias", "aliases", function(client, ...args) {
      var command, count, current, deleteAlias, formatEntry, msg, name, ref, value;
      if (!(this.control.indexOf(client) > -1)) {
        return client.permissionDenied("alias");
      }
      deleteAlias = UTIL.extractArg(args, ["-d", "--delete"]);
      // Usage (no args)
      if (!args.length) {
        client.sendSystemMessage("Usage: /alias [-l --list] | &lt;name&gt; [-d --delete] [command]");
        return client.ack();
      }
      formatEntry = function(name, command) {
        var r;
        if (typeof command === "function") {
          return "";
        }
        r = "";
        r += ` <span style="color: ${COLORS.info}">${name}</span> `;
        if (command != null) {
          r += ` => <span style="color: ${COLORS.magenta}">${command}</span> `;
        }
        return r;
      };
      // list
      if (UTIL.extractArg(args, ["-l", "--list"])) {
        count = Object.keys(this.plugin_aliases).length - 1;
        if (count) {
          msg = [`${count} aliases:`];
          ref = this.plugin_aliases;
          for (name in ref) {
            command = ref[name];
            if (typeof command !== "function") {
              msg.push(formatEntry(name, command));
            }
          }
          client.sendSystemMessage(msg.join("<br>"), COLORS.muted);
        } else {
          client.sendSystemMessage("No aliases registered so far!");
        }
        return client.ack();
      }
      if (!(args[0] || deleteAlias)) {
        return client.ack();
      }
      name = args.shift();
      value = args.join(" ");
      // safeguard :P
      if (name === "__fetch") {
        client.sendSystemMessage("That ain't a coincidence eh?");
        return client.ack();
      }
      // CRUD
      if (current = this.plugin_aliases[name]) {
        if (deleteAlias) {
          delete this.plugin_aliases[name];
          client.sendSystemMessage(`Removed ${formatEntry(name)}`, COLORS.danger);
        } else if (value) {
          if (value === current) {
            client.sendSystemMessage(`Remains ${formatEntry(name, value)}`, COLORS.warning);
          } else {
            this.plugin_aliases[name] = value;
            client.sendSystemMessage(`Changed ${formatEntry(name, value)}`, COLORS.success);
          }
        } else {
          client.sendSystemMessage(formatEntry(name, current));
        }
      } else if (value && !deleteAlias) {
        this.plugin_aliases[name] = value;
        client.sendSystemMessage(`Added ${formatEntry(name, value)}`, COLORS.success);
      } else {
        client.sendSystemMessage("alias not currently set");
      }
      return client.ack();
    });
  };

}).call(this);

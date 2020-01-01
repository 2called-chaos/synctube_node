// Generated by CoffeeScript 2.3.2
(function() {
  var COLORS, Commands, SyncTubeServerClient, UTIL;

  COLORS = require("./colors.js");

  UTIL = require("./util.js");

  Commands = require("./commands.js");

  exports.Class = SyncTubeServerClient = class SyncTubeServerClient {
    static find(client, who, collection = this.server.clients, context) {
      var base, e, i, j, k, len, len1, len2, sindex, sub;
      if (!who) {
        return client;
      }
      // session index?
      if (who[0] === "§" && (sindex = parseInt(who.substring(1))) !== (0/0)) {
        for (i = 0, len = collection.length; i < len; i++) {
          sub = collection[i];
          if (sub && sub.index === sindex) {
            return sub;
          }
        }
      }
// exact match?
      for (j = 0, len1 = collection.length; j < len1; j++) {
        sub = collection[j];
        if (sub && (typeof (base = sub.name).toLowerCase === "function" ? base.toLowerCase() : void 0) === (typeof who.toLowerCase === "function" ? who.toLowerCase() : void 0)) {
          return sub;
        }
      }
      if (who.charAt(0) !== "^") {
        // regex search
        who = `^${who}`;
      }
      try {
        for (k = 0, len2 = collection.length; k < len2; k++) {
          sub = collection[k];
          if (sub && sub.name.match(new RegExp(who, "i"))) {
            return sub;
          }
        }
      } catch (error) {
        e = error;
        if (client != null) {
          client.sendSystemMessage(e.message);
        }
        if (client != null) {
          client.ack();
        }
        return false;
      }
      if (client != null) {
        client.sendSystemMessage(`Couldn't find the target${(context ? ` in ${context}` : "")}`);
      }
      if (client != null) {
        client.ack();
      }
      return false;
    }

    debug(...a) {
      return this.server.debug(`[#${this.index}]`, ...a);
    }

    info(...a) {
      return this.server.info(`[#${this.index}]`, ...a);
    }

    warn(...a) {
      return this.server.warn(`[#${this.index}]`, ...a);
    }

    error(...a) {
      return this.server.error(`[#${this.index}]`, ...a);
    }

    constructor(server) {
      this.server = server;
      this.index = -1;
      if (this.name == null) {
        this.name = null;
      }
      this.control = null;
      this.subscribed = null;
    }

    accept(request) {
      this.request = request;
      this.info(`Accepting connection from origin ${this.request.origin}`);
      this.connection = this.request.accept(null, this.request.origin);
      this.ip = this.connection.remoteAddress;
      this.index = this.server.clients.push(this) - 1;
      this.connection.on("close", () => {
        return this.disconnect();
      });
      if (this.server.guardBanned(this)) {
        return this;
      }
      this.info(`Connection accepted (${this.index}): ${this.ip}`);
      this.sendCode("session_index", {
        index: this.index
      });
      this.sendCode("require_username", {
        maxLength: this.server.opts.nameMaxLength
      });
      return this;
    }

    listen() {
      this.connection.on("message", (message) => {
        var msg;
        msg = message.utf8Data;
        if (message.type !== "utf8") {
          this.warn("Received non-utf8 data", message);
          return;
        }
        if (!UTIL.startsWith(msg, "!packet") || this.server.opts.debug_packets) {
          this.debug(`<<< from ${this.ip}: ${msg}`);
        }
        if (this.name) {
          return Commands.handleMessage(this.server, this, message, msg);
        } else {
          this.setUsername(msg);
          if (this.name === "rpc_client") {
            return this.isRPC = true;
          }
        }
      });
      return this;
    }

    disconnect() {
      var ref, ref1;
      this.info(`Peer ${this.ip} disconnected.`);
      if ((ref = this.control) != null) {
        if (typeof ref.revokeControl === "function") {
          ref.revokeControl(this);
        }
      }
      if ((ref1 = this.subscribed) != null) {
        if (typeof ref1.unsubscribe === "function") {
          ref1.unsubscribe(this);
        }
      }
      return this.server.nullSession(this);
    }

    reindex() {
      var was_index;
      was_index = this.index;
      this.index = this.server.clients.indexOf(this);
      this.sendCode("session_index", {
        index: this.index
      });
      (this.subscribed != null) && this.sendCode("subscriber_list", {
        channel: this.subscribed.name,
        subscribers: this.subscribed.getSubscriberList(this)
      });
      this.debug(`Reindexed client session from ${was_index} to ${this.index}`);
      return this;
    }

    permissionDenied(context) {
      var msg;
      msg = "You don't have the required permissions to perform this action";
      if (context) {
        msg += ` (${context})`;
      }
      if (this.isRPC) {
        this.sendRPCResponse({
          error: msg
        });
      } else {
        this.sendSystemMessage(msg);
      }
      return this.ack();
    }

    send(message) {
      if (this.server.opts.debug_codes) {
        this.debug(`>>> to ${this.ip}: ${message}`);
      }
      return this.connection.send(message);
    }

    sendUTF(message) {
      if (this.server.opts.debug_codes) {
        this.debug(`>>> to ${this.ip}: ${message}`);
      }
      return this.connection.sendUTF(message);
    }

    sendCode(type, data = {}) {
      this.sendUTF(JSON.stringify({
        type: "code",
        data: Object.assign({}, data, {
          type: type
        })
      }));
      return this;
    }

    sendMessage(message, color, author, author_color, escape = false) {
      this.sendUTF(JSON.stringify({
        type: "message",
        data: {
          author: author,
          author_color: author_color,
          text: message,
          text_color: color,
          escape: escape,
          time: (new Date()).getTime()
        }
      }));
      return this;
    }

    sendRPCResponse(data = {}) {
      if (!this.isRPC) {
        return;
      }
      if (data.error != null) {
        data.type = "error";
        data.message = data.error;
        delete data["error"];
      }
      if (data.success != null) {
        data.type = "success";
        data.message = data.success;
        delete data["success"];
      }
      this.sendUTF(JSON.stringify({
        type: "rpc_response",
        data: Object.assign({}, data, {
          time: (new Date()).getTime()
        })
      }));
      return this;
    }

    sendSystemMessage(message, color) {
      if (this.isRPC) {
        return;
      }
      return this.sendMessage(message, color || COLORS.red, "system", COLORS.red);
    }

    ack() {
      this.sendCode("ack");
      return true;
    }

    isNameProtected(name) {
      var cname, i, len, n, ref;
      cname = name.toLowerCase().replace(/[^a-z0-9]+/, "");
      ref = this.server.opts.protectedNames;
      for (i = 0, len = ref.length; i < len; i++) {
        n = ref[i];
        if (UTIL.isRegExp(n)) {
          if (cname.match(n)) {
            return true;
          }
        } else {
          if (n === cname) {
            return true;
          }
          cname.indexOf(cname) > -1;
        }
      }
      return false;
    }

    setUsername(name) {
      var _name, nameLength;
      nameLength = UTIL.trim(name).length;
      this.old_name = this.name != null ? this.name : null;
      this.name = UTIL.trim(name);
      if (UTIL.startsWith(this.name, "!packet:")) {
        // ignore packets
        this.name = this.old_name;
        return this.ack();
      } else if (nameLength > this.server.opts.nameMaxLength) {
        this.name = this.old_name;
        this.sendSystemMessage(`Usernames can't be longer than ${this.server.opts.nameMaxLength} characters! You've got ${nameLength}`, COLORS.red);
        return this.ack();
      } else if (this.isNameProtected(this.name)) {
        this.name = this.old_name;
        this.sendSystemMessage("This name is not allowed!", COLORS.red);
        return this.ack();
      } else if (this.name.charAt(0) === "/" || this.name.charAt(0) === "!" || this.name.charAt(0) === "§" || this.name.charAt(0) === "$") {
        this.name = this.old_name;
        this.sendSystemMessage("Name may not start with a / $ § or ! character", COLORS.red);
        return this.ack();
      } else {
        if (this.old_name) {
          if (this.subscribed) {
            _name = this.name;
            this.name = this.old_name;
            this.subscribed.broadcast(this, `<i>changed his name to ${_name}</i>`, COLORS.info, COLORS.muted);
            this.name = _name;
            this.subscribed.broadcastCode(this, "update_single_subscriber", {
              channel: this.subscribed.name,
              data: this.subscribed.getSubscriberData(this, this, this.index)
            });
          } else {
            this.sendSystemMessage(`You changed your name from ${this.old_name} to ${this.name}!`, COLORS.info);
          }
          this.old_name = null;
        } else {
          this.hello();
        }
      }
      this.sendCode("username", {
        username: this.name
      });
      return this.ack();
    }

    hello() {
      var fdiff;
      this.sendSystemMessage(`Welcome, ${this.name}!`, COLORS.green);
      this.sendSystemMessage("To create or control a channel type <strong>/control &lt;channel&gt; [password]</strong>", COLORS.info);
      this.sendSystemMessage("To join an existing channel type <strong>/join &lt;channel&gt;</strong>", COLORS.info);
      if (this.server.pendingRestart != null) {
        this.server.handlePendingRestart();
        fdiff = UTIL.secondsToTimestamp((this.server.pendingRestart - (new Date).getTime()) / 1000, false);
        return this.sendSystemMessage(`Server will restart in ${fdiff}!`);
      }
    }

  };

}).call(this);

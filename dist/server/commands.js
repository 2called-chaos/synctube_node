// Generated by CoffeeScript 2.3.2
(function() {
  var COLORS, Channel, Client, UTIL, x,
    splice = [].splice;

  COLORS = require("./colors.js");

  UTIL = require("./util.js");

  Channel = require("./channel.js").Class;

  Client = require("./client.js").Class;

  x = module.exports = {
    handleMessage: function(server, client, message, msg) {
      var ch, chunks, cmd, err, m, ref, ref1;
      try {
        if (m = msg.match(/^!packet:(.+)$/i)) {
          return this.Server["packet"].call(server, client, m[1]);
        }
        chunks = [];
        cmd = null;
        if (msg && msg.charAt(0) === "/") {
          chunks = UTIL.shellSplit(msg.substr(1));
          cmd = chunks.shift();
        }
        if (cmd && ((ref = this.Server[cmd]) != null ? ref.call(server, client, ...chunks) : void 0)) {
          return;
        }
        if (ch = client.subscribed) {
          if (cmd && ((ref1 = this.Channel[cmd]) != null ? ref1.call(ch, client, ...chunks) : void 0)) {
            return;
          }
          ch.broadcastChat(client, msg, null, ch.clientColor(client));
          return client.ack();
        }
        return client.ack();
      } catch (error1) {
        err = error1;
        server.error(err);
        client.sendSystemMessage("Sorry, the server encountered an error");
        return client.ack();
      }
    },
    addCommand: function(parent, ...cmds) {
      var cmd, i, len, proc, ref, results;
      ref = cmds, [...cmds] = ref, [proc] = splice.call(cmds, -1);
      results = [];
      for (i = 0, len = cmds.length; i < len; i++) {
        cmd = cmds[i];
        results.push(((cmd) => {
          if (x[parent][cmd]) {
            console.warn("[ST-WARN] ", new Date, `Overwriting handler for existing command ${parent}.${cmd}`);
          }
          return x[parent][cmd] = proc;
        })(cmd));
      }
      return results;
    },
    Server: {},
    Channel: {}
  };

  x.addCommand("Server", "clip", function(client) {
    client.sendCode("ui_clipboard_poll", {
      action: "permission"
    });
    return client.ack();
  });

  x.addCommand("Server", "clear", function(client) {
    client.sendCode("ui_clear", {
      component: "chat"
    });
    return client.ack();
  });

  x.addCommand("Server", "tc", "togglechat", function(client) {
    client.sendCode("ui_chat_toggle");
    return client.ack();
  });

  x.addCommand("Server", "tpl", "togglepl", "toggleplaylist", function(client) {
    client.sendCode("ui_playlist_toggle");
    return client.ack();
  });

  x.addCommand("Server", "packet", function(client, jdata) {
    var ch, error, json, ref, seek_was;
    try {
      json = JSON.parse(jdata);
    } catch (error1) {
      error = error1;
      this.error("Invalid JSON", jdata, error);
      return;
    }
    client.lastPacket = new Date;
    ch = client.subscribed;
    if (ch && (!client.state || (JSON.stringify(client.state) !== jdata))) {
      json.time = new Date;
      if ((json.seek != null) && (json.playtime != null)) {
        json.timestamp = UTIL.videoTimestamp(json.seek, json.playtime);
      }
      client.state = json;
      ch.broadcastCode(client, "update_single_subscriber", {
        channel: ch.name,
        data: ch.getSubscriberData(client, client, client.index)
      });
      if (client === ch.control[ch.host] && ch.desired.url === json.url) {
        seek_was = ch.desired.seek;
        if (json.state === "ended" && ch.desired.state !== json.state) {
          ch.desired.state = json.state;
          if ((ref = ch.playlistManager) != null) {
            ref.handleEnded();
          }
        }
        ch.desired.seek = json.seek;
        ch.desired.seek_update = new Date();
        ch.broadcastCode(false, "desired", Object.assign({}, ch.desired, {
          force: Math.abs(ch.desired.seek - seek_was) > (this.opts.packetInterval + 0.75)
        }));
      }
    } else {
      if (ch) {
        client.sendCode("desired", ch.desired);
      }
    }
    return true;
  });

  x.addCommand("Server", "rpc", function(client, ...args) {
    var action, channel, cobj, err, key, ref, ref1;
    key = (ref = UTIL.extractArg(args, ["-k", "--key"], 1)) != null ? ref[0] : void 0;
    channel = (ref1 = UTIL.extractArg(args, ["-c", "--channel"], 1)) != null ? ref1[0] : void 0;
    // authentication
    if (channel) {
      if (cobj = this.channels[channel]) {
        if ((key != null) && key === cobj.getRPCKey()) {
          cobj.debug(`granted control to RPC client #${client.index}(${client.ip})`);
          cobj.control.push(client);
          client.control = cobj;
        } else {
          client.sendRPCResponse({
            error: "Authentication failed"
          });
          return;
        }
      } else {
        client.sendRPCResponse({
          error: "No such channel"
        });
        return;
      }
    } else if (!channel) {
      client.sendRPCResponse({
        error: "Server RPC not allowed"
      });
      return;
    }
    // available actions
    action = args.shift();
    try {
      switch (action) {
        case "play":
        case "yt":
        case "youtube":
          module.exports.Channel.youtube.call(cobj, client, ...args);
          break;
        case "browse":
        case "url":
          module.exports.Channel.browse.call(cobj, client, ...args);
          break;
        case "vid":
        case "video":
        case "mp4":
        case "webp":
          module.exports.Channel.video.call(cobj, client, ...args);
          break;
        case "img":
        case "image":
        case "pic":
        case "picture":
        case "gif":
        case "png":
        case "jpg":
          module.exports.Channel.image.call(cobj, client, ...args);
          break;
        default:
          client.sendRPCResponse({
            error: "Unknown RPC action"
          });
      }
    } catch (error1) {
      err = error1;
      this.error("[RPC]", err);
      client.sendRPCResponse({
        error: "Unknown RPC error"
      });
    }
    return client.ack();
  });

  x.addCommand("Server", "join", function(client, chname) {
    var channel;
    if (channel = this.channels[chname]) {
      channel.subscribe(client);
    } else if (chname) {
      client.sendSystemMessage("I don't know about this channel, sorry!");
      client.sendSystemMessage(`<small>You can create it with <strong>/control ${UTIL.htmlEntities(chname)} [password]</strong></small>`, COLORS.info);
    } else {
      client.sendSystemMessage("Usage: /join &lt;channel&gt;");
    }
    return client.ack();
  });

  x.addCommand("Server", "control", function(client, name, password) {
    var channel, chname, ref;
    chname = UTIL.htmlEntities(name || ((ref = client.subscribed) != null ? ref.name : void 0) || "");
    if (!chname) {
      client.sendSystemMessage("Channel name required", COLORS.red);
      return client.ack();
    }
    if (channel = this.channels[chname]) {
      if (channel.control.indexOf(client) > -1 && password === "delete") {
        channel.destroy(client);
        return client.ack();
      } else {
        if (channel.password === password) {
          channel.subscribe(client);
          channel.grantControl(client);
        } else {
          client.sendSystemMessage("Password incorrect", COLORS.red);
        }
      }
    } else {
      this.channels[chname] = new Channel(this, chname, password);
      client.sendSystemMessage("Channel created!", COLORS.green);
      this.channels[chname].subscribe(client);
      this.channels[chname].grantControl(client);
    }
    return client.ack();
  });

  x.addCommand("Server", "dc", "disconnect", function(client) {
    client.sendSystemMessage("disconnecting...");
    client.sendCode("disconnected");
    return client.connection.close();
  });

  x.addCommand("Server", "rename", function(client, ...name_parts) {
    var new_name;
    if (new_name = name_parts.join(" ")) {
      client.old_name = client.name;
      client.setUsername(new_name);
    } else {
      client.sendSystemMessage("Usage: /rename &lt;new_name&gt;");
    }
    return client.ack();
  });

  x.addCommand("Server", "system", function(client, subaction, ...args) {
    var amsg, b, c, ch, channel, detail, dur, e, i, iargs, ip, j, len, len1, m, msg, nulled, reason, ref, ref1, seconds, stamp, success, target, time, what, which, who;
    if (!client.isSystemAdmin) {
      if (subaction === "auth") {
        if (UTIL.argsToStr(args) === this.opts.systemPassword) {
          client.isSystemAdmin = true;
          client.sendSystemMessage("Authenticated successfully!", COLORS.green);
        } else {
          client.sendSystemMessage("invalid password");
        }
      } else {
        client.sendSystemMessage("system commands require you to `/system auth &lt;syspw&gt;` first!");
      }
      return client.ack();
    }
    switch (subaction) {
      case "restart":
        if (reason = UTIL.argsToStr(args)) {
          this.eachClient("sendSystemMessage", `Server restart: ${reason}`);
        }
        client.sendSystemMessage("See ya!");
        return process.exit(1);
      case "gracefulRestart":
        if (args[0] === "cancel") {
          if (this.pendingRestart != null) {
            this.eachClient("sendSystemMessage", "Restart canceled");
            this.pendingRestart = null;
            this.pendingRestartReason = null;
            clearTimeout(this.pendingRestartTimeout);
          } else {
            client.sendSystemMessage("No pending restart");
          }
        } else {
          success = true;
          try {
            dur = UTIL.parseEasyDuration(args.shift());
            time = new Date((new Date).getTime() + UTIL.timestamp2Seconds(dur.toString()) * 1000);
          } catch (error1) {
            e = error1;
            success = false;
            client.sendSystemMessage("Invalid duration format (timestamp or EasyDuration)");
          }
          if (success) {
            clearTimeout(this.pendingRestartTimeout);
            this.pendingRestart = time;
            this.pendingRestartReason = UTIL.argsToStr(args);
            this.handlePendingRestart(true);
          }
        }
        break;
      case "message":
        this.eachClient("sendSystemMessage", `${UTIL.argsToStr(args)}`);
        break;
      case "chmessage":
        channel = args.shift();
        if (ch = this.channels[channel]) {
          ch.broadcast({
            name: "system"
          }, UTIL.argsToStr(args), COLORS.red, COLORS.red);
        } else {
          client.sendSystemMessage("The channel could not be found!");
        }
        break;
      case "chkill":
        channel = args.shift();
        if (ch = this.channels[channel]) {
          ch.destroy(client, UTIL.argsToStr(args));
          client.sendSystemMessage("Channel destroyed!");
        } else {
          client.sendSystemMessage("The channel could not be found!");
        }
        break;
      case "status":
        client.sendSystemMessage("======================");
        nulled = 0;
        ref = this.clients;
        for (i = 0, len = ref.length; i < len; i++) {
          c = ref[i];
          if (c === null) {
            nulled += 1;
          }
        }
        client.sendSystemMessage(`Running with pid ${process.pid} for ${UTIL.secondsToTimestamp(process.uptime())} (on ${process.platform})`);
        client.sendSystemMessage(`${this.clients.length - nulled} active sessions (${this.clients.length} total, ${nulled}/${this.opts.sessionReindex} nulled)`);
        client.sendSystemMessage(`${UTIL.microToHuman(process.cpuUsage().user)}/${UTIL.microToHuman(process.cpuUsage().system)} CPU (usr/sys)`);
        client.sendSystemMessage(`${UTIL.bytesToHuman(process.memoryUsage().rss)} memory (RSS)`);
        client.sendSystemMessage("======================");
        break;
      case "clients":
        client.sendSystemMessage("======================");
        ref1 = this.clients;
        for (j = 0, len1 = ref1.length; j < len1; j++) {
          c = ref1[j];
          if (c != null) {
            client.sendSystemMessage(`<span class="soft_elli" style="min-width: 45px">[#${c.index}]</span>\n<span class="elli" style="width: 100px; margin-bottom: -4px">${c.name || "<em>unnamed</em>"}</span>\n<span>${c.ip}</span>`);
          }
        }
        client.sendSystemMessage("======================");
        break;
      case "banip":
        ip = args.shift();
        if (ip == null) {
          client.sendSystemMessage("Usage: /system banip &lt;ip&gt; [duration] [message]");
          return client.ack();
        }
        dur = args.shift();
        reason = args.join(" ");
        if (dur === "permanent") {
          dur = -1;
        }
        dur = UTIL.parseEasyDuration(dur);
        seconds = (function() {
          try {
            return UTIL.timestamp2Seconds(`${dur}`);
          } catch (error1) {
            e = error1;
            return UTIL.timestamp2Seconds("1:00:00");
          }
        })();
        stamp = dur === -1 ? "eternity" : UTIL.secondsToTimestamp(seconds, false);
        this.banIp(ip, dur, reason);
        amsg = `Banned IP ${ip} (${reason || "no reason"}) for ${stamp}`;
        this.info(amsg);
        client.sendSystemMessage(amsg);
        break;
      case "unbanip":
        ip = args[0];
        if (b = this.banned.get(ip)) {
          client.sendSystemMessage(`Removed ban for IP ${ip} with expiry ${(b ? b : "never")}`);
          this.banned.purge(ip);
        } else {
          client.sendSystemMessage(`No ban found for IP ${ip}`);
        }
        break;
      case "invoke":
        target = client;
        if (x = UTIL.extractArg(args, ["-t", "--target"], 1)) {
          Client = require("./client.js").Class;
          who = typeof x[0] === "string" ? x[0] : x[0].pattern;
          target = Client.find(client, who, this.clients);
        }
        if (!target) {
          return true;
        }
        which = args.shift();
        iargs = UTIL.argsToStr(args) || "{}";
        client.sendCode(which, JSON.parse(iargs));
        break;
      case "kick":
        who = args.shift();
        target = Client = require("./client.js").Class.find(client, who, this.clients);
        if (!target) {
          return true;
        }
        amsg = `Kicked #${target.index} ${target.name} (${target.ip}) from server`;
        this.info(amsg);
        client.sendSystemMessage(amsg);
        msg = `You got kicked from the server${((m = UTIL.argsToStr(args)) ? ` (${m})` : "")}`;
        target.sendCode("session_kicked", {
          reason: msg
        });
        target.sendSystemMessage(msg);
        target.connection.close();
        break;
      case "dump":
        what = args[0];
        detail = args[1];
        if (what === "client") {
          console.log(detail ? this.clients[parseInt(detail)] : client);
        } else if (what === "channel") {
          console.log(detail ? this.channels[detail] : client.subscribed ? client.subscribed : this.channels);
        } else if (what === "commands") {
          console.log(module.exports);
        }
    }
    return client.ack();
  });

  x.addCommand("Channel", "retry", function(client) {
    var ch;
    if (!(ch = client.subscribed)) {
      return;
    }
    ch.revokeControl(client);
    ch.unsubscribe(client);
    ch.subscribe(client);
    return client.ack();
  });

  x.addCommand("Channel", "p", "pause", function(client) {
    if (!(this.control.indexOf(client) > -1)) {
      return client.permissionDenied("pause");
    }
    this.desired.state = "pause";
    this.broadcastCode(false, "desired", this.desired);
    return client.ack();
  });

  x.addCommand("Channel", "r", "resume", function(client) {
    if (!(this.control.indexOf(client) > -1)) {
      return client.permissionDenied("resume");
    }
    this.desired.state = "play";
    this.broadcastCode(false, "desired", this.desired);
    return client.ack();
  });

  x.addCommand("Channel", "t", "toggle", function(client) {
    if (!(this.control.indexOf(client) > -1)) {
      return client.permissionDenied("toggle");
    }
    this.desired.state = this.desired.state === "play" ? "pause" : "play";
    this.broadcastCode(false, "desired", this.desired);
    return client.ack();
  });

  x.addCommand("Channel", "s", "seek", function(client, to) {
    if (!(this.control.indexOf(client) > -1)) {
      return client.permissionDenied("seek");
    }
    if ((to != null ? to.charAt(0) : void 0) === "-") {
      to = this.desired.seek - UTIL.timestamp2Seconds(to.slice(1));
    } else if ((to != null ? to.charAt(0) : void 0) === "+") {
      to = this.desired.seek + UTIL.timestamp2Seconds(to.slice(1));
    } else if (to) {
      to = UTIL.timestamp2Seconds(to);
    } else {
      client.sendSystemMessage("Number required (absolute or +/-)");
      return client.ack();
    }
    this.desired.seek = parseFloat(to);
    if (this.desired.state === "ended") {
      this.desired.state = "play";
    }
    this.broadcastCode(false, "desired", Object.assign({}, this.desired, {
      force: true
    }));
    return client.ack();
  });

  x.addCommand("Channel", "sync", "resync", function(client, ...args) {
    var found, i, instant, len, t, target;
    target = [client];
    instant = UTIL.extractArg(args, ["-i", "--instant"]);
    if (x = UTIL.extractArg(args, ["-t", "--target"], 1)) {
      if (!(this.control.indexOf(client) > -1)) {
        return client.permissionDenied("resync-target");
      }
      Client = require("./client.js").Class;
      found = Client.find(client, x[0], this.subscribers);
      target = found === client ? false : [found];
    }
    if (UTIL.extractArg(args, ["-a", "--all"])) {
      if (!(this.control.indexOf(client) > -1)) {
        return client.permissionDenied("resync-all");
      }
      target = this.subscribers;
    }
    if (target && target.length) {
      for (i = 0, len = target.length; i < len; i++) {
        t = target[i];
        if (instant) {
          if (t != null) {
            t.sendCode("desired", Object.assign({}, this.desired, {
              force: true
            }));
          }
        } else {
          if (t != null) {
            t.sendCode("video_action", {
              action: "sync"
            });
          }
        }
      }
    } else {
      client.sendSystemMessage("Found no targets");
    }
    return client.ack();
  });

  x.addCommand("Channel", "ready", function(client) {
    if (!this.ready) {
      return client.ack();
    }
    if (!(this.ready.indexOf(client) > -1)) {
      this.ready.push(client);
    }
    if (this.ready.length === this.subscribers.length) {
      this.ready = false;
      clearTimeout(this.ready_timeout);
      this.desired.state = "play";
      this.broadcastCode(false, "video_action", {
        action: "resume",
        reason: "allReady",
        cancelPauseEnsured: true
      });
    }
    return client.ack();
  });

  x.addCommand("Channel", "play", "yt", "youtube", function(client, ...args) {
    var intermission, m, playNext, url;
    if (!(this.control.indexOf(client) > -1)) {
      return client.permissionDenied("play");
    }
    if (this.playlistManager.ensurePlaylistQuota(client)) {
      return client.ack();
    }
    playNext = UTIL.extractArg(args, ["-n", "--next"]);
    intermission = UTIL.extractArg(args, ["-i", "--intermission"]);
    url = args.join(" ");
    if (m = url.match(/([A-Za-z-0-9_\-]{11})/)) {
      this.play("Youtube", m[1], playNext, intermission);
      client.sendRPCResponse({
        success: "Video successfully added to playlist"
      });
    } else {
      client.sendRPCResponse({
        error: "I don't recognize this URL/YTID format, sorry"
      });
      client.sendSystemMessage("I don't recognize this URL/YTID format, sorry");
    }
    return client.ack();
  });

  x.addCommand("Channel", "loop", function(client, what) {
    if (what || this.control.indexOf(client) > -1) {
      if (!(this.control.indexOf(client) > -1)) {
        return client.permissionDenied("loop");
      }
      what = UTIL.strbool(what, !this.desired.loop);
      if (this.desired.loop === what) {
        client.sendSystemMessage(`Loop is already ${(this.desired.loop ? "enabled" : "disabled")}!`);
      } else {
        this.desired.loop = what;
        this.broadcastCode(false, "desired", this.desired);
        this.broadcast(client, `<strong>${(this.desired.loop ? "enabled" : "disabled")} loop!</strong>`, COLORS.warning, this.clientColor(client));
      }
    } else {
      client.sendSystemMessage(`Loop is currently ${(this.desired.loop ? "enabled" : "disabled")}`, this.desired.loop ? COLORS.green : COLORS.red);
    }
    return client.ack();
  });

  x.addCommand("Channel", "url", "browse", function(client, ...args) {
    var ctype, intermission, playNext, url;
    if (!(this.control.indexOf(client) > -1)) {
      return client.permissionDenied(`browse-${ctype}`);
    }
    if (this.playlistManager.ensurePlaylistQuota(client)) {
      return client.ack();
    }
    playNext = UTIL.extractArg(args, ["-n", "--next"]);
    intermission = UTIL.extractArg(args, ["-i", "--intermission"]);
    ctype = "HtmlFrame";
    if (UTIL.extractArg(args, ["--x-HtmlImage"])) {
      ctype = "HtmlImage";
    }
    if (UTIL.extractArg(args, ["--x-HtmlVideo"])) {
      ctype = "HtmlVideo";
    }
    url = args.join(" ");
    if (!UTIL.startsWith(url, "http://", "https://")) {
      url = `https://${url}`;
    }
    this.play(ctype, url, playNext, intermission);
    return client.ack();
  });

  x.addCommand("Channel", "img", "image", "pic", "picture", "gif", "png", "jpg", function(client, ...args) {
    return module.exports.Channel.browse.call(this, client, ...args, "--x-HtmlImage");
  });

  x.addCommand("Channel", "vid", "video", "mp4", "webp", function(client, ...args) {
    return module.exports.Channel.browse.call(this, client, ...args, "--x-HtmlVideo");
  });

  x.addCommand("Channel", "leave", "quit", function(client) {
    var ch;
    if (ch = client.subscribed) {
      ch.unsubscribe(client);
      client.sendCode("desired", {
        ctype: "StuiCreateForm"
      });
    } else {
      client.sendSystemMessage("You are not in any channel!");
    }
    return client.ack();
  });

  x.addCommand("Channel", "password", function(client, new_password, revoke) {
    var ch, cu, i, len, ref;
    if (ch = client.subscribed) {
      if (ch.control.indexOf(client) > -1) {
        if (typeof new_password === "string") {
          ch.persisted.set("password", new_password ? new_password : void 0);
          revoke = UTIL.strbool(revoke, false);
          client.sendSystemMessage(`Password changed${(revoke ? ", revoked all but you" : "")}!`);
          if (revoke) {
            ref = ch.control;
            for (i = 0, len = ref.length; i < len; i++) {
              cu = ref[i];
              if (cu === client) {
                continue;
              }
              ch.revokeControl(cu, true, "channel password changed");
            }
          }
        } else {
          client.sendSystemMessage("New password required! (you can use \"\")");
        }
      } else {
        client.sendSystemMessage("You are not in control!");
      }
    } else {
      client.sendSystemMessage("You are not in any channel!");
    }
    return client.ack();
  });

  x.addCommand("Channel", "kick", function(client, who, ...args) {
    var amsg, ch, m, msg, target;
    if (ch = client.subscribed) {
      if (ch.control.indexOf(client) > -1) {
        target = Client = require("./client.js").Class.find(client, who, ch.subscribers);
        if (!target) {
          return true;
        }
        if (target === client) {
          client.sendSystemMessage("You want to kick yourself?");
          return client.ack();
        }
        amsg = `Kicked #${target.index} ${target.name} (${target.ip}) from channel ${ch.name}`;
        this.info(amsg);
        client.sendSystemMessage(amsg);
        msg = `You got kicked from the channel${((m = UTIL.argsToStr(args)) ? ` (${m})` : "")}`;
        ch.unsubscribe(target);
        target.sendCode("kicked", {
          reason: msg
        });
        target.sendSystemMessage(msg);
      } else {
        client.sendSystemMessage("You are not in control!");
      }
    } else {
      client.sendSystemMessage("You are not in any channel!");
    }
    return client.ack();
  });

  x.addCommand("Channel", "host", function(client, who) {
    var newHost, newHostI, wasHost, wasHostI;
    if (!(this.control.indexOf(client) > -1)) {
      return client.permissionDenied("host");
    }
    if (!(who = this.findClient(client, who))) {
      return false;
    }
    if (who === this.control[this.host]) {
      client.sendSystemMessage(`${(who != null ? who.name : void 0) || "Target"} is already host`);
    } else if (this.control.indexOf(who) > -1) {
      this.debug("Switching host to #", who.index);
      wasHostI = this.host;
      wasHost = this.control[wasHostI];
      newHostI = this.control.indexOf(who);
      newHost = this.control[newHostI];
      this.control[wasHostI] = newHost;
      this.control[newHostI] = wasHost;
      newHost.sendCode("taken_host", {
        channel: this.name
      });
      wasHost.sendCode("lost_host", {
        channel: this.name
      });
      this.updateSubscriberList(client);
    } else {
      client.sendSystemMessage(`${(who != null ? who.name : void 0) || "Target"} is not in control and thereby can't be host`);
    }
    return client.ack();
  });

  x.addCommand("Channel", "grant", function(client, who) {
    if (!(this.control.indexOf(client) > -1)) {
      return client.permissionDenied("grantControl");
    }
    if (!(who = this.findClient(client, who))) {
      return true;
    }
    if (this.control.indexOf(who) > -1) {
      client.sendSystemMessage(`${(who != null ? who.name : void 0) || "Target"} is already in control`);
    } else {
      this.grantControl(who);
      client.sendSystemMessage(`${(who != null ? who.name : void 0) || "Target"} is now in control!`, COLORS.green);
    }
    return client.ack();
  });

  x.addCommand("Channel", "revoke", function(client, who) {
    if (!(this.control.indexOf(client) > -1)) {
      return client.permissionDenied("revokeControl");
    }
    if (!(who = this.findClient(client, who))) {
      return true;
    }
    if (this.control.indexOf(who) > -1) {
      this.revokeControl(who);
      client.sendSystemMessage(`${(who != null ? who.name : void 0) || "Target"} is no longer in control!`, COLORS.green);
    } else {
      client.sendSystemMessage(`${(who != null ? who.name : void 0) || "Target"} was not in control`);
    }
    return client.ack();
  });

  x.addCommand("Channel", "rpckey", function(client) {
    if (!(this.control.indexOf(client) > -1)) {
      return client.permissionDenied("rpckey");
    }
    client.sendSystemMessage(`RPC-Key for this channel: ${this.getRPCKey()}`);
    client.sendSystemMessage("The key will change with the channel password!", COLORS.warning);
    return client.ack();
  });

  x.addCommand("Channel", "bookmarklet", function(client, ...args) {
    var desiredAction, label, ref, ref1, script, showHelp, withNotification, wsurl;
    if (!(this.control.indexOf(client) > -1)) {
      return client.permissionDenied("bookmarklet");
    }
    showHelp = UTIL.extractArg(args, ["-h", "--help"]);
    withNotification = UTIL.extractArg(args, ["-n", "--notifications"]);
    desiredAction = ((ref = UTIL.extractArg(args, ["-a", "--action"], 1)) != null ? ref[0] : void 0) || "yt";
    label = ((ref1 = UTIL.extractArg(args, ["-l", "--label"], 1)) != null ? ref1[0] : void 0) || `+ SyncTube (${desiredAction.toUpperCase()})`;
    if (showHelp) {
      client.sendSystemMessage("Usage: /bookmarklet [-h --help] | [-a --action=youtube] [-n --notifications] [-l --label LABEL]", COLORS.info);
      client.sendSystemMessage(" Action might be one of: youtube video image url", COLORS.white);
      client.sendSystemMessage(" Notifications will show you the result if enabled for youtube.com", COLORS.white);
      client.sendSystemMessage(" Label is the name of the button, you can change that in your browser too", COLORS.white);
      client.sendSystemMessage("The embedded key will change with the channel password!", COLORS.warning);
      return client.ack();
    }
    if (withNotification) {
      script = "(function(b){n=Notification;x=function(a){h=\"%wsurl%\";s=\"https://statics.bmonkeys.net/img/rpcico/\";w=window;w.stwsb=w.stwsb||[];if(w.stwsc){if(w.stwsc.readyState!=1){w.stwsb.push(a)}else{w.stwsc.send(a)}}else{w.stwsb.push(\"rpc_client\");w.stwsb.push(a);w.stwsc=new WebSocket(h);w.stwsc.onmessage=function(m){j=JSON.parse(m.data);if(j.type==\"rpc_response\"){new n(\"SyncTube\",{body:j.data.message,icon:s+j.data.type+\".png\"})}};w.stwsc.onopen=function(){while(w.stwsb.length){w.stwsc.send(w.stwsb.shift())}};w.stwsc.onerror=function(){alert(\"stwscError: failed to connect to \"+h);console.error(arguments[0])};w.stwsc.onclose=function(){w.stwsc=null}}};if(n.permission===\"granted\"||n.permission===\"denied\"){x(b)}else{n.requestPermission().then(function(result){x(b)})}})(\"/rpc -k %key% -c %channel% %action% \"+window.location)";
    } else {
      script = "(function(a){h=\"%wsurl%\";w=window;w.stwsb=w.stwsb||[];if(w.stwsc){if(w.stwsc.readyState!=1){w.stwsb.push(a)}else{w.stwsc.send(a)}}else{w.stwsb.push(\"rpc_client\");w.stwsb.push(a);w.stwsc=new WebSocket(h);w.stwsc.onopen=function(){while(w.stwsb.length){w.stwsc.send(w.stwsb.shift())}};w.stwsc.onerror=function(){alert(\"stwscError: failed to connect to \"+h);console.error(arguments[0])};w.stwsc.onclose=function(){w.stwsc=null}}})(\"/rpc -k %key% -c %channel% %action% \"+window.location)";
    }
    wsurl = client.request.origin.replace(/^https:\/\//, "wss://").replace(/^http:\/\//, "ws://");
    wsurl += `/${client.request.resourceURL.pathname}`;
    script = script.replace("%wsurl%", wsurl);
    script = script.replace("%channel%", this.name);
    script = script.replace("%key%", this.getRPCKey());
    script = script.replace("%action%", desiredAction);
    client.sendSystemMessage(`The embedded key will change with the channel password!<br>\n<span style="color: ${COLORS.info}">Drag the following button to your bookmark bar:</span>\n<a href="javascript:${encodeURIComponent(script)}" class="btn btn-primary btn-xs" style="font-size: 10px">${label}</a>`, COLORS.warning);
    return client.ack();
  });

  x.addCommand("Channel", "copt", function(client, opt, value) {
    var c, cols, err, i, len, nv, ok, ot, ov, ref, ref1, who;
    if (!(this.control.indexOf(client) > -1)) {
      return client.permissionDenied("copt");
    }
    if (!(who = this.findClient(client, who))) {
      return true;
    }
    if (opt) {
      if (this.options.hasOwnProperty(opt)) {
        ok = opt;
        ov = this.options[opt];
        ot = typeof ov;
        if (value != null) {
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
            this.options[opt] = nv;
            this.sendSettings();
            ref = this.control;
            for (i = 0, len = ref.length; i < len; i++) {
              c = ref[i];
              c.sendSystemMessage(`<span style="color: ${COLORS.warning}">CHANGED</span> channel option\n<span style="color: ${COLORS.info}">${ok}</span>\nfrom <span style="color: ${COLORS.magenta}">${ov}</span>\nto <span style="color: ${COLORS.magenta}">${nv}</span>`, COLORS.white);
            }
          } catch (error1) {
            err = error1;
            client.sendSystemMessage(`Failed to change channel option: ${err}`);
          }
        } else {
          client.sendSystemMessage(`<span style="color: ${COLORS.info}">${ok}</span>\nis currently set to <span style="color: ${COLORS.magenta}">${ov}</span>\n<em style="color: ${COLORS.muted}">(${ot})</em>`, COLORS.white);
        }
      } else {
        client.sendSystemMessage("Unknown option!");
      }
    } else {
      cols = ["The following channel options are available:"];
      ref1 = this.options;
      for (ok in ref1) {
        ov = ref1[ok];
        cols.push(`<span style="color: ${COLORS.info}">${ok}</span>\n<span style="color: ${COLORS.magenta}">${ov}</span>\n<em style="color: ${COLORS.muted}">${typeof ov}</em>`);
      }
      client.sendSystemMessage(cols.join("<br>"), COLORS.white);
    }
    return client.ack();
  });

}).call(this);

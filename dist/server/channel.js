// Generated by CoffeeScript 2.3.2
(function() {
  var COLORS, Client, SyncTubeServerChannel, UTIL;

  COLORS = require("./colors.js");

  UTIL = require("./util.js");

  Client = require("./client.js").Class;

  exports.Class = SyncTubeServerChannel = class SyncTubeServerChannel {
    debug(...a) {
      return this.server.debug(`[${this.name}]`, ...a);
    }

    info(...a) {
      return this.server.info(`[${this.name}]`, ...a);
    }

    warn(...a) {
      return this.server.warn(`[${this.name}]`, ...a);
    }

    error(...a) {
      return this.server.error(`[${this.name}]`, ...a);
    }

    constructor(server, name, password) {
      this.server = server;
      this.name = name;
      this.password = password;
      this.control = [];
      this.host = 0;
      this.subscribers = [];
      this.queue = [];
      this.ready = [];
      this.ready_timeout = null;
      this.playlist = [];
      this.playlist_index = 0;
      this.desired = {
        ctype: this.server.opts.defaultCtype,
        url: this.server.opts.defaultUrl,
        seek: 0,
        loop: false,
        seek_update: new Date,
        state: this.server.opts.defaultAutoplay ? "play" : "pause"
      };
    }

    broadcast(client, message, color, client_color, sendToAuthor = true) {
      var c, j, len, ref, results;
      ref = this.subscribers;
      results = [];
      for (j = 0, len = ref.length; j < len; j++) {
        c = ref[j];
        if (c === client && !sendToAuthor) {
          continue;
        }
        results.push(c.sendMessage(message, color, client.name, client_color || (client != null ? client.color : void 0)));
      }
      return results;
    }

    broadcastCode(client, type, data, sendToAuthor = true) {
      var c, j, len, ref, results;
      ref = this.subscribers;
      results = [];
      for (j = 0, len = ref.length; j < len; j++) {
        c = ref[j];
        if (c === client && !sendToAuthor) {
          continue;
        }
        results.push(c.sendCode(type, data));
      }
      return results;
    }

    updateSubscriberList(client) {
      return this.broadcastCode(client, "subscriber_list", {
        channel: this.name,
        subscribers: this.getSubscriberList(client)
      });
    }

    getSubscriberList(client) {
      var c, i, j, len, list, ref;
      list = [];
      ref = this.subscribers;
      for (i = j = 0, len = ref.length; j < len; i = ++j) {
        c = ref[i];
        list.push(this.getSubscriberData(client, c, i));
      }
      return list;
    }

    getSubscriberData(client, sub, index) {
      var data, leader, ref, ref1, ref2, ref3, seekdiff;
      data = {
        index: sub.index,
        name: sub.name || sub.old_name,
        control: this.control.indexOf(sub) > -1,
        isHost: this.control[this.host] === sub,
        isyou: client === sub,
        drift: 0,
        state: sub.state || {}
      };
      // calculcate drift
      leader = this.control[0];
      if (((ref = sub.state) != null ? ref.seek : void 0) && ((leader != null ? (ref1 = leader.state) != null ? ref1.seek : void 0 : void 0) != null)) {
        seekdiff = (leader != null ? (ref2 = leader.state) != null ? ref2.seek : void 0 : void 0) - client.state.seek;
        if (leader.lastPacket && client.lastPacket) {
          seekdiff -= (leader.lastPacket - client.lastPacket) / 1000;
        }
        data.drift = seekdiff.toFixed(3);
        if (data.drift === "0.000") {
          data.drift = 0;
        }
      }
      data.progress = data.state.state || "uninitialized";
      switch ((ref3 = data.state) != null ? ref3.state : void 0) {
        case "unstarted":
          data.icon = "cog";
          data.icon_class = "text-muted";
          break;
        case "ended":
          data.icon = "stop";
          data.icon_class = "text-danger";
          break;
        case "playing":
          data.icon = "play";
          data.icon_class = "text-success";
          break;
        case "paused":
          data.icon = "pause";
          data.icon_class = "text-warning";
          break;
        case "buffering":
          data.icon = "spinner";
          data.icon_class = "text-warning";
          break;
        case "cued":
          data.icon = "eject";
          data.icon_class = "text-muted";
          break;
        case "ready":
          data.icon = "check-square-o";
          data.icon_class = "text-muted";
          break;
        default:
          data.icon = "cog";
          data.icon_class = "text-danger";
      }
      return data;
    }

    liveVideo(url, state = "pause") {
      this.desired = {
        ctype: "Youtube",
        url: url,
        state: state,
        seek: 0,
        loop: false,
        seek_update: new Date
      };
      this.ready = [];
      this.broadcastCode(false, "desired", this.desired);
      // start after grace period
      return this.ready_timeout = UTIL.delay(2000, () => {
        this.desired.state = "play";
        return this.broadcastCode(false, "video_action", {
          action: "play"
        });
      });
    }

    liveUrl(url, ctype = "HtmlFrame") {
      if (!UTIL.startsWith(url, "http://", "https://")) {
        url = `https://${url}`;
      }
      this.desired = {
        ctype: ctype,
        url: url,
        loop: false,
        state: "play"
      };
      this.ready = [];
      return this.broadcastCode(false, "desired", this.desired);
    }

    pauseVideo(client, sendMessage = true) {
      var ref;
      if (!(this.control.indexOf(client) > -1)) {
        return;
      }
      this.broadcastCode(client, "video_action", {
        action: "pause"
      }, {}, false);
      if (((ref = client.state) != null ? ref.seek : void 0) != null) {
        return this.broadcastCode(client, "video_action", {
          action: "seek",
          to: client.state.seek,
          paused: true
        }, false);
      }
    }

    playVideo(client, sendMessage = true) {
      if (!(this.control.indexOf(client) > -1)) {
        return;
      }
      return this.broadcastCode(client, "video_action", {
        action: "resume"
      }, false);
    }

    grantControl(client, sendMessage = true) {
      if (this.control.indexOf(client) > -1) {
        return;
      }
      this.control.push(client);
      client.control = this;
      if (sendMessage) {
        client.sendSystemMessage(`You are in control of ${this.name}!`, COLORS.green);
      }
      client.sendCode("taken_control", {
        channel: this.name
      });
      this.updateSubscriberList(client);
      return this.debug(`granted control to client #${client.index}(${client.ip})`);
    }

    revokeControl(client, sendMessage = true, reason = null) {
      if (this.control.indexOf(client) === -1) {
        return;
      }
      this.control.splice(this.control.indexOf(client), 1);
      client.control = null;
      if (sendMessage) {
        client.sendSystemMessage(`You lost control of ${this.name}${(reason ? ` (${reason})` : "")}!`, COLORS.red);
      }
      client.sendCode("lost_control", {
        channel: this.name
      });
      this.updateSubscriberList(client);
      return this.debug(`revoked control from client #${client.index}(${client.ip})`);
    }

    subscribe(client, sendMessage = true) {
      var ref;
      if (this.subscribers.indexOf(client) > -1) {
        return;
      }
      if ((ref = client.subscribed) != null) {
        if (typeof ref.unsubscribe === "function") {
          ref.unsubscribe(client);
        }
      }
      this.subscribers.push(client);
      client.subscribed = this;
      client.state = {};
      if (sendMessage) {
        client.sendSystemMessage(`You joined ${this.name}!`, COLORS.green);
      }
      client.sendCode("subscribe", {
        channel: this.name
      });
      client.sendCode("desired", Object.assign({}, this.desired, {
        force: true
      }));
      this.broadcast(client, "<i>joined the party!</i>", COLORS.green, COLORS.muted, false);
      this.updateSubscriberList(client);
      return this.debug(`subscribed client #${client.index}(${client.ip})`);
    }

    unsubscribe(client, sendMessage = true, reason = null) {
      if (this.subscribers.indexOf(client) === -1) {
        return;
      }
      if (client.control === this) {
        client.control.revokeControl(client);
      }
      this.subscribers.splice(this.subscribers.indexOf(client), 1);
      client.subscribed = null;
      client.state = {};
      if (sendMessage) {
        client.sendSystemMessage(`You left ${this.name}${(reason ? ` (${reason})` : "")}!`, COLORS.red);
      }
      client.sendCode("unsubscribe", {
        channel: this.name
      });
      this.broadcast(client, "<i>left the party :(</i>", COLORS.red, COLORS.muted, false);
      this.updateSubscriberList(client);
      return this.debug(`unsubscribed client #${client.index}(${client.ip})`);
    }

    destroy(client, sendMessage = true) {
      var c, j, k, len, len1, ref, ref1;
      this.debug(`channel deleted by ${client.name}[${client.ip}] (${this.subscribers.length} subscribers)`);
      ref = this.subscribers;
      for (j = 0, len = ref.length; j < len; j++) {
        c = ref[j];
        this.unsubscribe(c, true, "channel deleted");
      }
      ref1 = this.control;
      for (k = 0, len1 = ref1.length; k < len1; k++) {
        c = ref1[k];
        this.revokeControl(c, true, `channel deleted by ${client.name}[${client.ip}]`);
      }
      return delete this.server.channels[this.name];
    }

    clientColor(client) {
      if (this.control[this.host] === client) {
        return COLORS.red;
      } else if (this.control.indexOf(client) > -1) {
        return COLORS.info;
      } else {
        return null;
      }
    }

    findClient(client, who) {
      return Client.find(client, who, this.subscribers, "channel");
    }

    // ====================
    // = Channel commands =
    // ====================
    handleMessage(client, message, msg, control = false) {
      var m;
      if (control) {
        if (m = msg.match(/^\/(?:seek)(?:\s([0-9\-+:\.]+))?$/i)) {
          return this.CHSCMD_seek(client, m[1]);
        }
        if (m = msg.match(/^\/(?:p|pause)$/i)) {
          return this.CHSCMD_pause(client);
        }
        if (m = msg.match(/^\/(?:r|resume)$/i)) {
          return this.CHSCMD_resume(client);
        }
        if (m = msg.match(/^\/(?:t|toggle)$/i)) {
          return this.CHSCMD_toggle(client);
        }
        if (m = msg.match(/^\/play\s(.+)$/i)) {
          return this.CHSCMD_play(client, m[1]);
        }
        if (m = msg.match(/^\/(?:browse|url)\s(.+)$/i)) {
          return this.CHSCMD_browse(client, m[1], "HtmlFrame");
        }
        if (m = msg.match(/^\/(?:image|img|pic(?:ture)?|gif|png|jpg)\s(.+)$/i)) {
          return this.CHSCMD_browse(client, m[1], "HtmlImage");
        }
        if (m = msg.match(/^\/(?:video|vid|mp4|webp)\s(.+)$/i)) {
          return this.CHSCMD_browse(client, m[1], "HtmlVideo");
        }
        if (m = msg.match(/^\/host(?:\s(.+))?$/i)) {
          return this.CHSCMD_host(client, m[1]);
        }
        if (m = msg.match(/^\/grant(?:\s(.+))?$/i)) {
          return this.CHSCMD_grantControl(client, m[1]);
        }
        if (m = msg.match(/^\/revoke(?:\s(.+))?$/i)) {
          return this.CHSCMD_revokeControl(client, m[1]);
        }
        if (m = msg.match(/^\/loop(?:\s(.+))?$/i)) {
          return this.CHSCMD_loop(client, m[1]);
        }
        return false;
      } else {
        if (m = msg.match(/^\/loop(?:\s(.+))?$/i)) {
          return this.CHSCMD_loop(client, m[1]);
        }
        if (m = msg.match(/^\/(?:ready|rdy)$/i)) {
          return this.CHSCMD_ready(client);
        }
        if (m = msg.match(/^\/retry$/i)) {
          return this.CHSCMD_retry(client);
        }
        if (m = msg.match(/^\/leave$/i)) {
          return this.CHSCMD_leave(client);
        }
        this.broadcast(client, msg, null, this.clientColor(client));
        return client.ack();
      }
    }

    CHSCMD_retry(client) {
      var ch;
      if (!(ch = client.subscribed)) {
        return;
      }
      ch.revokeControl(client);
      ch.unsubscribe(client);
      ch.subscribe(client);
      return client.ack();
    }

    CHSCMD_pause(client) {
      if (!(this.control.indexOf(client) > -1)) {
        return client.permissionDenied("pause");
      }
      this.desired.state = "pause";
      this.broadcastCode(false, "desired", this.desired);
      return client.ack();
    }

    CHSCMD_resume(client) {
      if (!(this.control.indexOf(client) > -1)) {
        return client.permissionDenied("resume");
      }
      this.desired.state = "play";
      this.broadcastCode(false, "desired", this.desired);
      return client.ack();
    }

    CHSCMD_toggle(client) {
      if (!(this.control.indexOf(client) > -1)) {
        return client.permissionDenied("toggle");
      }
      this.desired.state = this.desired.state === "play" ? "pause" : "play";
      this.broadcastCode(false, "desired", this.desired);
      return client.ack();
    }

    CHSCMD_seek(client, to) {
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
    }

    CHSCMD_ready(client) {
      this.ready.push(client);
      if (this.ready.length === this.subscribers.length) {
        clearTimeout(this.ready_timeout);
        this.desired.state = "play";
        this.broadcastCode(false, "video_action", {
          action: "play"
        });
      }
      return client.ack();
    }

    CHSCMD_play(client, url) {
      var m;
      if (!(this.control.indexOf(client) > -1)) {
        return client.permissionDenied("play");
      }
      if (m = url.match(/([A-Za-z0-9_\-]{11})/)) {
        this.liveVideo(m[1]);
      } else {
        client.sendSystemMessage("I don't recognize this URL/YTID format, sorry");
      }
      return client.ack();
    }

    CHSCMD_loop(client, what) {
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
    }

    CHSCMD_browse(client, url, ctype = "frame") {
      if (!(this.control.indexOf(client) > -1)) {
        return client.permissionDenied(`browse-${ctype}`);
      }
      this.liveUrl(url, ctype);
      return client.ack();
    }

    CHSCMD_leave(client) {
      var ch;
      if (ch = client.subscribed) {
        ch.unsubscribe(client);
      } else {
        client.sendSystemMessage("You are not in any channel!");
      }
      return client.ack();
    }

    CHSCMD_host(client, who) {
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
        this.updateSubscriberList(client);
      } else {
        client.sendSystemMessage(`${(who != null ? who.name : void 0) || "Target"} is not in control and thereby can't be host`);
      }
      //@broadcastCode(false, "desired", @desired)
      return client.ack();
    }

    CHSCMD_grantControl(client, who) {
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
    }

    CHSCMD_revokeControl(client, who) {
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
    }

  };

}).call(this);

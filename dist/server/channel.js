// Generated by CoffeeScript 2.3.2
(function() {
  var COLORS, PlaylistManager, SyncTubeServerChannel, UTIL;

  PlaylistManager = require("./playlist_manager.js").Class;

  COLORS = require("./colors.js");

  UTIL = require("./util.js");

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
      this.playlists = {};
      this.ready = [];
      this.ready_timeout = null;
      this.options = {
        defaultCtype: this.server.opts.defaultCtype,
        defaultUrl: this.server.opts.defaultUrl,
        defaultAutoplay: this.server.opts.defaultAutoplay,
        maxDrift: this.server.opts.maxDrift,
        packetInterval: this.server.opts.packetInterval,
        readyGracePeriod: 2000,
        chatMode: "public", // public, admin-only, disabled
        playlistMode: "full" // full, disabled
      };
      this.persisted = {
        queue: this.queue,
        playlists: this.playlists,
        desired: this.desired,
        options: this.options
      };
      this.setDefaultDesired();
      this.playlistManager = new PlaylistManager(this, this.playlists);
      this.playlistManager.load("default");
      this.init();
    }

    init() {} // plugin hook

    setDefaultDesired(broadcast = true) {
      this.persisted.desired = this.desired = {
        ctype: this.options.defaultCtype,
        url: this.options.defaultUrl,
        seek: 0,
        loop: false,
        seek_update: new Date,
        state: this.options.defaultAutoplay ? "play" : "pause"
      };
      return this.broadcastCode(false, "desired", this.desired);
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

    broadcastChat(client, message, color, client_color, sendToAuthor = true) {
      if (this.options.chatMode === "disabled" || (this.options.chatMode === "admin-only" && this.control.indexOf(client) === -1)) {
        return client.sendSystemMessage(`chat is ${this.options.chatMode}!`, COLORS.muted);
      }
      return this.broadcast(client, message, color, client_color, sendToAuthor);
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

    sendSettings(client) {
      var clients, j, len, results, sub;
      clients = client ? [client] : this.subscribers;
      results = [];
      for (j = 0, len = clients.length; j < len; j++) {
        sub = clients[j];
        results.push(sub.sendCode("server_settings", {
          packetInterval: this.options.packetInterval,
          maxDrift: this.options.maxDrift
        }));
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
      var data, leader, ref, ref1, ref2, ref3, ref4, seekdiff;
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
        seekdiff = (leader != null ? (ref2 = leader.state) != null ? ref2.seek : void 0 : void 0) - sub.state.seek;
        if (leader.lastPacket && sub.lastPacket && (leader != null ? (ref3 = leader.state) != null ? ref3.state : void 0 : void 0) === "playing") {
          seekdiff -= (leader.lastPacket - sub.lastPacket) / 1000;
        }
        data.drift = seekdiff.toFixed(3);
        if (data.drift === "0.000") {
          data.drift = 0;
        }
      }
      data.progress = data.state.state || "uninitialized";
      switch ((ref4 = data.state) != null ? ref4.state : void 0) {
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

    live(ctype, url) {
      this.persisted.desired = this.desired = {
        ctype: ctype,
        url: url,
        state: "pause",
        seek: 0,
        loop: false,
        seek_update: new Date
      };
      this.ready = [];
      this.broadcastCode(false, "desired", this.desired);
      // start after grace period
      return this.ready_timeout = UTIL.delay(this.options.readyGracePeriod, () => {
        this.desired.state = "play";
        return this.broadcastCode(false, "video_action", {
          action: "play"
        });
      });
    }

    play(ctype, url, playNext = false, intermission = false) {
      if (intermission) {
        return this.playlistManager.intermission(ctype, url);
      } else if (playNext) {
        return this.playlistManager.playNext(ctype, url);
      } else {
        return this.playlistManager.append(ctype, url);
      }
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
      if (this.host === this.control.indexOf(client)) {
        client.sendCode("taken_host", {
          channel: this.name
        });
      }
      this.updateSubscriberList(client);
      return this.debug(`granted control to client #${client.index}(${client.ip})`);
    }

    revokeControl(client, sendMessage = true, reason = null) {
      if (this.control.indexOf(client) === -1) {
        return;
      }
      if (this.host === this.control.indexOf(client)) {
        client.sendCode("lost_host", {
          channel: this.name
        });
      }
      client.sendCode("lost_control", {
        channel: this.name
      });
      if (sendMessage) {
        client.sendSystemMessage(`You lost control of ${this.name}${(reason ? ` (${reason})` : "")}!`, COLORS.red);
      }
      this.control.splice(this.control.indexOf(client), 1);
      client.control = null;
      this.updateSubscriberList(client);
      return this.debug(`revoked control from client #${client.index}(${client.ip})`);
    }

    subscribe(client, sendMessage = true) {
      var ref, ref1;
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
      this.sendSettings(client);
      if ((ref1 = this.playlistManager) != null) {
        ref1.cUpdateList(client);
      }
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
        client.control.revokeControl(client, sendMessage, reason);
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

    destroy(client, reason) {
      var c, j, len, ref;
      this.info(`channel deleted by ${client.name}[${client.ip}] (${this.subscribers.length} subscribers)${(reason ? `: ${reason}` : "")}`);
      ref = this.subscribers.slice(0).reverse();
      for (j = 0, len = ref.length; j < len; j++) {
        c = ref[j];
        this.unsubscribe(c, true, `channel deleted${(reason ? ` (${reason})` : "")}`);
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
      return require("./client.js").Class.find(client, who, this.subscribers, "channel");
    }

  };

}).call(this);

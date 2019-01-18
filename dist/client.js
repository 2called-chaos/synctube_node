// Generated by CoffeeScript 2.3.2
(function() {
  var SyncTubeClient, SyncTubeClient_History, SyncTubeClient_Player_HtmlFrame, SyncTubeClient_Player_HtmlImage, SyncTubeClient_Player_HtmlVideo, SyncTubeClient_Player_Youtube, ref;

  window.SyncTubeClient_ControlCodes = {
    CMD_server_settings: function(data) {
      var k, results, v;
      results = [];
      for (k in data) {
        v = data[k];
        if (k === "type") {
          continue;
        }
        this.debug("Accepting server controlled setting", k, "was", this.opts.synced[k], "new", v);
        results.push(this.opts.synced[k] = v);
      }
      return results;
    },
    CMD_ack: function() {
      return this.enableInput();
    },
    CMD_taken_control: function() {
      return this.control = true;
    },
    CMD_lost_control: function() {
      return this.control = false;
    },
    CMD_unsubscribe: function() {
      this.clients.html("");
      return this.CMD_video_action({
        action: "destroy"
      });
    },
    CMD_desired: function(data) {
      var e, klass, ref;
      if (data.ctype !== ((ref = this.player) != null ? ref.ctype : void 0)) {
        this.CMD_video_action({
          action: "destroy"
        });
        klass = `SyncTubeClient_Player_${data.ctype}`;
        try {
          this.player = new window[klass](this);
        } catch (error1) {
          e = error1;
          this.addError(`Failed to load player ${data.ctype}! ${e.toString().replace("window[klass]", klass)}`);
          throw e;
          return;
        }
      }
      return this.player.updateDesired(data);
    },
    CMD_video_action: function(data) {
      var ref, ref1, ref2, ref3;
      switch (data.action) {
        case "resume":
          return (ref = this.player) != null ? ref.play() : void 0;
        case "pause":
          return (ref1 = this.player) != null ? ref1.pause() : void 0;
        case "sync":
          return (ref2 = this.player) != null ? ref2.force_resync = true : void 0;
        case "seek":
          return (ref3 = this.player) != null ? ref3.seekTo(data.to, data.paused) : void 0;
        case "destroy":
          this.dontBroadcast = false;
          this.stopBroadcast();
          if (this.player) {
            this.player.destroy();
            this.player = null;
            return this.broadcastState(-666);
          }
      }
    },
    CMD_navigate: function(data) {
      if (data.reload) {
        return window.location.reload();
      } else if (data.location) {
        return window.location.href = data.location;
      }
    },
    CMD_session_index: function(data) {
      return this.index = data.index;
    },
    CMD_require_username: function(data) {
      var hparams, p;
      this.enableInput();
      if (data.maxLength != null) {
        this.input.attr("maxLength", data.maxLength);
      }
      this.status.text("Choose name:");
      // check hash params
      if (data.autofill === false) {
        return;
      }
      hparams = this.getHashParams();
      if (p = hparams.user || hparams.username || hparams.name) {
        return this.connection.send(p);
      }
    },
    CMD_username: function(data) {
      var ch, cmd, hparams;
      this.name = data.username;
      this.input.removeAttr("maxLength");
      this.status.text(`${this.name}:`);
      // check hash params
      hparams = this.getHashParams();
      if (ch = hparams.channel || hparams.join) {
        this.connection.send(`/join ${ch}`);
      }
      if (hparams.control) {
        cmd = `/control ${hparams.control}`;
        if (hparams.password != null) {
          cmd += ` ${hparams.password}`;
        }
        return this.connection.send(cmd);
      }
    },
    CMD_update_single_subscriber: function(resp) {
      var _el, data, el, k, ref, v;
      data = (resp != null ? resp.data : void 0) || {};
      if (data.index == null) {
        return;
      }
      el = this.clients.find(`[data-client-index=${data.index}]`);
      if (!el.length || data.state.istate === -666) {
        _el = $(this.buildSubscriberElement());
        _el.attr("data-client-index", data.index);
        if (el.length) {
          el.replaceWith(_el);
        } else {
          this.clients.append(_el);
        }
        el = _el;
      }
      for (k in data) {
        v = data[k];
        el.find(`[data-attr=${k}]`).html(v);
      }
      ref = data.state;
      for (k in ref) {
        v = ref[k];
        el.find(`[data-attr=${k}]`).html(v);
      }
      el.find("[data-attr=progress-bar-buffered]").css({
        width: `${(data.state.loaded_fraction || 0) * 100}%`
      });
      el.find("[data-attr=progress-bar-position]").css({
        left: `${(data.state.seek <= 0 ? 0 : data.state.seek / data.state.playtime * 100)}%`
      });
      if (data.icon) {
        el.find("[data-attr=icon-ctn] i").attr("class", `fa fa-${data.icon} ${data.icon_class}`);
      }
      if (data.control) {
        el.find("[data-attr=admin-ctn] i").attr("class", "fa fa-shield text-info").attr("title", "ADMIN");
      }
      if (data.isHost) {
        el.find("[data-attr=admin-ctn] i").attr("class", "fa fa-shield text-danger").attr("title", "HOST");
      }
      el.find("[data-attr=drift-ctn] i").attr("class", `fa fa-${(data.drift ? data.drift > 0 ? "backward" : "forward" : "circle-o-notch")} text-warning`);
      el.find("[data-attr=drift]").html(el.find("[data-attr=drift]").html().replace("-", ""));
      if ((this.index != null) && data.index === this.index) {
        return this.drift = parseFloat(data.drift);
      }
    },
    CMD_subscriber_list: function(data) {
      var j, len, ref, results, sub, subs;
      this.clients.html("");
      // get ordered list
      subs = data.subscribers.sort(function(a, b) {
        if (a.isHost) {
          return -1;
        }
        if (!a.control) {
          return 1;
        }
        return 0;
      });
      ref = data.subscribers;
      results = [];
      for (j = 0, len = ref.length; j < len; j++) {
        sub = ref[j];
        results.push(this.CMD_update_single_subscriber({
          data: sub
        }));
      }
      return results;
    }
  };

  window.SyncTubeClient = SyncTubeClient = (function() {
    class SyncTubeClient {
      static include(obj, into) {
        var key, ref, value;
        for (key in obj) {
          value = obj[key];
          if (key !== "included" && key !== "start" && key !== "init") {
            this.prototype[key] = value;
          }
        }
        return (ref = obj.included) != null ? ref.call(this, into) : void 0;
      }

      include(addon) {
        this.included.push(addon);
        return this.constructor.include(addon, this);
      }

      constructor(opts = {}) {
        var base, base1, base2, base3, inc, j, len, ref, ref1;
        this.opts = opts;
        // options
        if ((base = this.opts).debug == null) {
          base.debug = false;
        }
        if (this.opts.debug) {
          window.client = this;
        }
        // synced settings (controlled by server)
        if ((base1 = this.opts).synced == null) {
          base1.synced = {};
        }
        if ((base2 = this.opts.synced).maxDrift == null) {
          base2.maxDrift = 60000; // superseded by server instructions
        }
        if ((base3 = this.opts.synced).packetInterval == null) {
          base3.packetInterval = 10000; // superseded by server instructions
        }
        
        // Client data
        this.index = null;
        this.name = null;
        this.control = false;
        this.drift = 0;
        // modules
        this.include(SyncTubeClient_Util);
        this.include(SyncTubeClient_ControlCodes);
        this.include(SyncTubeClient_Network);
        this.include(SyncTubeClient_UI);
        this.include(SyncTubeClient_Player_Youtube);
        this.include(SyncTubeClient_Player_HtmlFrame);
        this.include(SyncTubeClient_Player_HtmlImage);
        this.include(SyncTubeClient_Player_HtmlVideo);
        this.include(SyncTubeClient_History);
        ref = this.included;
        for (j = 0, len = ref.length; j < len; j++) {
          inc = ref[j];
          if ((ref1 = inc.init) != null) {
            ref1.apply(this);
          }
        }
      }

      start() {
        var inc, j, len, ref, ref1;
        ref = this.included;
        for (j = 0, len = ref.length; j < len; j++) {
          inc = ref[j];
          if ((ref1 = inc.start) != null) {
            ref1.apply(this);
          }
        }
        return this.listen();
      }

      // ===========
      // = Logging =
      // ===========
      debug(...msg) {
        if (!this.opts.debug) {
          return;
        }
        msg.unshift(`[ST ${(new Date).toISOString()}]`);
        return console.debug.apply(this, msg);
      }

      info(...msg) {
        msg.unshift(`[ST ${(new Date).toISOString()}]`);
        return console.log.apply(this, msg);
      }

      warn(...msg) {
        msg.unshift(`[ST ${(new Date).toISOString()}]`);
        return console.warn.apply(this, msg);
      }

      error(...msg) {
        msg.unshift(`[ST ${(new Date).toISOString()}]`);
        return console.error.apply(this, msg);
      }

    };

    SyncTubeClient.prototype.VIEW_COMPONENTS = ["content", "view", "input", "status", "queue", "playlist", "clients"];

    SyncTubeClient.prototype.included = [];

    return SyncTubeClient;

  }).call(this);

  window.SyncTubeClient_History = SyncTubeClient_History = class SyncTubeClient_History {
    constructor(client1, opts = {}) {
      var base, base1;
      this.client = client1;
      this.opts = opts;
      if ((base = this.opts).limit == null) {
        base.limit = 100;
      }
      if ((base1 = this.opts).save == null) {
        base1.save = true; // @todo set to false
      }
      this.log = this.opts.save ? this.loadLog() : [];
      this.index = -1;
      this.buffer = null;
      this.captureInput();
    }

    captureInput() {
      return this.client.input.keydown((event) => {
        if (event.keyCode === 27) { // ESC
          if (this.index !== -1) {
            this.index = -1;
            if (this.buffer != null) {
              this.client.input.val(this.buffer);
            }
            this.buffer = null;
          }
          return true;
        }
        if (event.keyCode === 38) { // ArrowUp
          if (this.log[this.index + 1] == null) {
            return false;
          }
          if (this.index === -1) {
            this.buffer = this.client.input.val();
          }
          this.index++;
          this.client.input.val(this.log[this.index]);
          return false;
        }
        if (event.keyCode === 40) { // ArrowDown
          if (this.index === 0) {
            this.index = -1;
            this.restoreBuffer();
            return false;
          }
          if (this.log[this.index - 1] == null) {
            return false;
          }
          this.index--;
          this.client.input.val(this.log[this.index]);
          return false;
        }
        return true;
      });
    }

    restoreBuffer() {
      if (this.buffer != null) {
        this.client.input.val(this.buffer);
      }
      return this.buffer = null;
    }

    append(cmd) {
      if (cmd && this.log.length && this.log[0] !== cmd) {
        this.log.unshift(cmd);
      }
      while (this.log.length > this.opts.limit) {
        this.log.pop();
      }
      if (this.opts.save) {
        this.saveLog();
      }
      this.index = -1;
      return this.buffer = null;
    }

    saveLog() {
      return localStorage.setItem("synctube_client_history", JSON.stringify(this.log));
    }

    loadLog() {
      var e;
      try {
        return JSON.parse(localStorage.getItem("synctube_client_history")) || [];
      } catch (error1) {
        e = error1;
        return [];
      }
    }

  };

  window.SyncTubeClient_History.start = function() {
    return this.history = new SyncTubeClient_History(this, this.opts.history);
  };

  window.SyncTubeClient_Network = {
    init: function() {
      var base, base1, base2, discoveredHost, discoveredPort, discoveredProtocol;
      discoveredHost = document.location.hostname;
      discoveredPort = document.location.port || (document.location.protocol === "https:" ? 443 : 80);
      discoveredProtocol = document.location.protocol === "https:" ? "wss" : "ws";
      if ((base = this.opts).wsIp == null) {
        base.wsIp = $("meta[name=synctube-server-ip]").attr("content") || discoveredHost;
      }
      if ((base1 = this.opts).wsPort == null) {
        base1.wsPort = $("meta[name=synctube-server-port]").attr("content") || discoveredPort;
      }
      if ((base2 = this.opts).wsProtocol == null) {
        base2.wsProtocol = $("meta[name=synctube-server-protocol]").attr("content") || discoveredProtocol;
      }
      return this.dontBroadcast = false;
    },
    start: function() {
      this.openWSconnection();
      return this.detectBrokenConnection();
    },
    openWSconnection: function() {
      var address;
      // mozilla fallback
      window.WebSocket = window.WebSocket || window.MozWebSocket;
      // if browser doesn't support WebSocket, just show some notification and exit
      if (!window.WebSocket) {
        this.content.html($("<p>", {
          text: "Sorry, but your browser doesn't support WebSocket."
        }));
        this.status.hide();
        this.input.hide();
        return;
      }
      // open connection
      address = `${this.opts.wsProtocol}://${this.opts.wsIp}:${this.opts.wsPort}/cable`;
      this.debug(`Opening connection to ${address}`);
      this.connection = new WebSocket(address);
      this.connection.onopen = () => {
        return this.debug("WS connection opened");
      };
      return this.connection.onerror = (error) => {
        this.error("WS connection encountered an error", error);
        return this.content.html($("<p>", {
          text: "Sorry, but there's some problem with your connection or the server is down."
        }));
      };
    },
    detectBrokenConnection: function() {
      return setInterval((() => {
        if (this.connection.readyState !== 1) {
          this.status.text("Error");
          this.disableInput().val("Unable to communicate with the WebSocket server. Please reload!");
          return setTimeout((function() {
            return window.location.reload();
          }), 1000);
        }
      }), 3000);
    },
    listen: function() {
      return this.connection.onmessage = (message) => {
        var error, json;
        try {
          json = JSON.parse(message.data);
        } catch (error1) {
          error = error1;
          this.error("Invalid JSON", message.data, error);
          return;
        }
        switch (json.type) {
          case "code":
            //@debug "received CODE", json.data
            if (this[`CMD_${json.data.type}`] != null) {
              return this[`CMD_${json.data.type}`](json.data);
            } else {
              return this.warn(`no client implementation for CMD_${json.data.type}`);
            }
            break;
          case "message":
            //@debug "received MESSAGE", json.data
            return this.addMessage(json.data);
          default:
            return this.warn("Hmm..., I've never seen JSON like this:", json);
        }
      };
    },
    startBroadcast: function() {
      if (this.broadcastStateInterval != null) {
        return;
      }
      return this.broadcastStateInterval = setInterval((() => {
        return this.broadcastState();
      }), this.opts.synced.packetInterval);
    },
    stopBroadcast: function() {
      clearInterval(this.broadcastStateInterval);
      return this.broadcastStateInterval = null;
    },
    sendControl: function(cmd) {
      if (!this.control) {
        return;
      }
      this.debug("send control", cmd);
      return this.connection.send(cmd);
    },
    broadcastState: function(ev = (ref = this.player) != null ? ref.getState() : void 0) {
      var packet, ref1, ref2, ref3, ref4, state;
      if (this.dontBroadcast) {
        return;
      }
      state = (function() {
        switch (ev) {
          case -666:
            return "uninitialized";
          case -1:
            return "unstarted";
          case 0:
            return "ended";
          case 1:
            return "playing";
          case 2:
            return "paused";
          case 3:
            return "buffering";
          case 5:
            return "cued";
          default:
            return "ready";
        }
      })();
      packet = {
        state: state,
        istate: ev,
        seek: (ref1 = this.player) != null ? ref1.getCurrentTime() : void 0,
        playtime: (ref2 = this.player) != null ? ref2.getDuration() : void 0,
        loaded_fraction: (ref3 = this.player) != null ? ref3.getLoadedFraction() : void 0,
        url: (ref4 = this.player) != null ? ref4.getUrl() : void 0
      };
      return this.connection.send("!packet:" + JSON.stringify(packet));
    }
  };

  window.SyncTubeClient_Player_HtmlFrame = SyncTubeClient_Player_HtmlFrame = (function() {
    class SyncTubeClient_Player_HtmlFrame {
      constructor(client1) {
        this.client = client1;
        this.state = -1;
        this.loaded = 0;
        this.frame = $("<iframe>", {
          id: "view_frame",
          width: "100%",
          height: "100%"
        }).appendTo(this.client.view);
        this.frame.on("load", () => {
          this.state = this.loaded = 1;
          return this.client.broadcastState();
        });
      }

      destroy() {
        return this.frame.remove();
      }

      updateDesired(data) {
        if (data.url !== this.frame.attr("src")) {
          this.loaded = 0;
          this.state = 3;
          this.frame.attr("src", data.url);
          return this.client.broadcastState();
        }
      }

      getUrl() {
        return this.frame.attr("src");
      }

      getState() {
        return this.state;
      }

      getLoadedFraction() {
        return this.loaded;
      }

      // null api functions
      play() {}

      pause() {}

      seekTo(time, paused = false) {}

      getCurrentTime() {}

      getDuration() {}

    };

    SyncTubeClient_Player_HtmlFrame.prototype.ctype = "HtmlFrame";

    return SyncTubeClient_Player_HtmlFrame;

  }).call(this);

  window.SyncTubeClient_Player_HtmlImage = SyncTubeClient_Player_HtmlImage = (function() {
    class SyncTubeClient_Player_HtmlImage {
      constructor(client1) {
        this.client = client1;
        this.state = -1;
        this.loaded = 0;
        this.image = $("<img>", {
          id: "view_image",
          height: "100%"
        }).appendTo(this.client.view);
        this.image.on("load", () => {
          this.state = this.loaded = 1;
          return this.client.broadcastState();
        });
      }

      destroy() {
        return this.image.remove();
      }

      updateDesired(data) {
        if (data.url !== this.image.attr("src")) {
          this.loaded = 0;
          this.state = 3;
          this.image.attr("src", data.url);
          return this.client.broadcastState();
        }
      }

      getUrl() {
        return this.image.attr("src");
      }

      getState() {
        return this.state;
      }

      getLoadedFraction() {
        return this.loaded;
      }

      // null api functions
      play() {}

      pause() {}

      seekTo(time, paused = false) {}

      getCurrentTime() {}

      getDuration() {}

    };

    SyncTubeClient_Player_HtmlImage.prototype.ctype = "HtmlImage";

    return SyncTubeClient_Player_HtmlImage;

  }).call(this);

  // when -0 then "unstarted"
  // when 0 then "ended"
  // when 1 then "playing"
  // when 2 then "paused"
  // when 3 then "buffering"
  // when 5 then "cued"
  // else "ready"
  window.SyncTubeClient_Player_HtmlVideo = SyncTubeClient_Player_HtmlVideo = (function() {
    class SyncTubeClient_Player_HtmlVideo {
      constructor(client1) {
        this.client = client1;
        this.video = $("<video>", {
          id: "view_video",
          width: "100%",
          height: "100%",
          controls: true
        }).appendTo(this.client.view);
        this.video.on("click", () => {
          if (!(this.client.control || !this.everPlayed)) {
            return;
          }
          if (this.getState() === 1) {
            return this.pause();
          } else {
            return this.play();
          }
        });
        //@video.on "canplay", => console.log "canplay", (new Date).toISOString()
        this.video.on("canplaythrough", () => {
          return this.sendReady();
        });
        this.video.on("error", () => {
          return this.error = this.video.get(0).error;
        });
        this.video.on("playing", () => {
          return this.sendResume();
        });
        this.video.on("pause", () => {
          if (this.getCurrentTime() !== this.getDuration()) {
            return this.sendPause();
          }
        });
        this.video.on("timeupdate", () => {
          if (!this.seeking) {
            return this.lastKnownTime = this.getCurrentTime();
          }
        });
        this.video.on("ended", () => {
          if (this.getCurrentTime() === this.getDuration()) {
            return this.sendEnded();
          }
        });
        this.video.on("seeking", () => {
          return this.seeking = true;
        });
        this.video.on("seeked", (a) => {
          this.seeking = false;
          if (this.systemSeek) {
            return this.systemSeek = false;
          } else {
            return this.sendSeek();
          }
        });
      }

      destroy() {
        return this.video.remove();
      }

      updateDesired(data) {
        console.log(data.state);
        if (data.state === "play") {
          this.video.attr("autoplay", "autoplay");
        } else {
          this.video.removeAttr("autoplay");
        }
        if (data.url !== this.video.attr("src")) {
          this.client.debug("switching video from", this.getUrl(), "to", data.url);
          this.video.attr("src", data.url);
          this.error = false;
          this.playing = false;
          this.everPlayed = false;
          this.client.startBroadcast();
          this.client.broadcastState();
        }
        if (data.loop) {
          this.video.attr("loop", "loop");
          if (this.getCurrentTime() === this.getDuration() && this.getDuration() > 0) {
            this.play();
          }
        } else {
          this.video.removeAttr("loop");
        }
        if (!this.error && this.getState() === 1 && data.state === "pause") {
          this.client.debug("pausing playback", data.state, data.seek, this.getState());
          this.systemPause = true;
          this.pause();
          this.seekTo(data.seek, true);
          return;
        }
        if (!this.error && this.getState() !== 1 && data.state === "play") {
          this.client.debug("starting playback");
          this.systemResume = true;
          this.play();
        }
        if (Math.abs(this.client.drift * 1000) > this.client.opts.synced.maxDrift || this.force_resync || data.force) {
          this.force_resync = false;
          this.client.debug("seek to correct drift", this.client.drift, data.seek);
          if (!(this.getCurrentTime() === 0 && data.seek === 0)) {
            return this.seekTo(data.seek, true);
          }
        }
      }

      getState() {
        if (this.video.get(0).readyState === 0) {
          // uninitalized
          return -1;
        }
        if (this.video.get(0).readyState === 2 || this.video.get(0).readyState === 3) {
          // buffering
          return 3;
        }
        if (this.getCurrentTime() === this.getDuration() && this.video.get(0).paused) {
          // ended playback
          return 0;
        }
        // paused or playing
        if (this.video.get(0).paused) {
          return 2;
        } else if (this.playing) {
          return 1;
        } else {
          return -1;
        }
      }

      getUrl() {
        return this.video.get(0).currentSrc;
      }

      play() {
        if (this.video.length) {
          return this.video.get(0).play();
        }
      }

      pause() {
        if (this.video.length) {
          return this.video.get(0).pause();
        }
      }

      getCurrentTime() {
        if (this.seeking) {
          return this.lastKnownTime;
        } else {
          return this.video.get(0).currentTime;
        }
      }

      getDuration() {
        if (this.video.get(0).seekable.length) {
          return this.video.get(0).seekable.end(0);
        } else {
          return 0;
        }
      }

      seekTo(time, paused = false) {
        this.systemSeek = true;
        return this.video.get(0).currentTime = time;
      }

      getLoadedFraction() {
        var cur, end, j, maxbuf, n, ref1;
        if (!this.video.get(0).seekable.length || this.video.get(0).seekable.end(0) === 0) {
          return 0;
        }
        maxbuf = 0;
        cur = this.getCurrentTime();
        for (n = j = 0, ref1 = this.video.get(0).buffered.length; (0 <= ref1 ? j < ref1 : j > ref1); n = 0 <= ref1 ? ++j : --j) {
          end = this.video.get(0).buffered.end(n);
          if (cur >= this.video.get(0).buffered.start(n) && cur <= end) {
            maxbuf = end;
            break;
          } else if (end > maxbuf) {
            maxbuf = end;
          }
        }
        return parseFloat(maxbuf) / parseFloat(this.video.get(0).seekable.end(0));
      }

      sendSeek(time = this.getCurrentTime()) {
        if (!this.client.dontBroadcast) {
          return this.client.sendControl(`/seek ${time}`);
        }
      }

      sendReady() {
        return this.client.sendControl("/ready");
      }

      sendResume() {
        this.everPlayed = true;
        this.playing = true;
        if (this.systemResume) {
          this.systemResume = false;
        } else {
          if (!this.client.dontBroadcast) {
            this.client.sendControl("/resume");
          }
        }
        return this.client.broadcastState();
      }

      sendPause() {
        this.playing = false;
        if (this.systemPause) {
          this.systemPause = false;
        } else {
          if (!this.client.dontBroadcast) {
            this.client.sendControl("/pause");
          }
        }
        return this.client.broadcastState();
      }

      sendEnded() {
        this.playing = false;
        if (this.everPlayed) {
          return this.client.broadcastState();
        }
      }

    };

    SyncTubeClient_Player_HtmlVideo.prototype.ctype = "HtmlVideo";

    return SyncTubeClient_Player_HtmlVideo;

  }).call(this);

  window.SyncTubeClient_Player_Youtube = SyncTubeClient_Player_Youtube = (function() {
    class SyncTubeClient_Player_Youtube {
      constructor(client1) {
        this.client = client1;
      }

      destroy() {
        var ref1;
        if ((ref1 = this.api) != null) {
          ref1.destroy();
        }
        this.api = null;
        return this.pauseEnsured();
      }

      updateDesired(data) {
        var current_ytid, ref1, ref2;
        if (!this.api) {
          this.loadVideo(data.url, data.state !== "play", data.seek);
          this.ensurePause(data);
          return;
        }
        current_ytid = (ref1 = this.getUrl()) != null ? (ref2 = ref1.match(/([A-Za-z0-9_\-]{11})/)) != null ? ref2[0] : void 0 : void 0;
        if (current_ytid !== data.url) {
          this.client.debug("switching video from", current_ytid, "to", data.url);
          this.loadVideo(data.url);
          return;
        }
        if (this.getState() === 1 && data.state === "pause") {
          this.client.debug("pausing playback, state:", this.getState());
          this.pause();
          this.seekTo(data.seek, true);
          return;
        }
        if (this.getState() !== 1 && data.state === "play") {
          this.client.debug("starting playback, state:", this.getState());
          this.play();
          return;
        }
        if (Math.abs(this.client.drift * 1000) > this.client.opts.synced.maxDrift || this.force_resync || data.force) {
          this.force_resync = false;
          this.client.debug("seek to correct drift", this.client.drift, data.seek, this.getState());
          if (!(this.getCurrentTime() === 0 && data.seek === 0)) {
            this.seekTo(data.seek, true);
          }
          // ensure paused player at correct position when it was cued
          // seekTo on a cued video will start playback delayed
          return this.ensurePause(data);
        }
      }

      seekTo(time, paused = false) {
        var ref1, ref2, ref3;
        if ((ref1 = this.api) != null) {
          if (typeof ref1.seekTo === "function") {
            ref1.seekTo(time, true);
          }
        }
        if (paused) {
          return (ref2 = this.player) != null ? ref2.pause() : void 0;
        } else {
          return (ref3 = this.player) != null ? ref3.play() : void 0;
        }
      }

      getState() {
        var ref1;
        if (((ref1 = this.api) != null ? ref1.getPlayerState : void 0) != null) {
          return this.api.getPlayerState();
        } else {
          return -1;
        }
      }

      play() {
        var ref1;
        return (ref1 = this.api) != null ? typeof ref1.playVideo === "function" ? ref1.playVideo() : void 0 : void 0;
      }

      pause() {
        var ref1;
        return (ref1 = this.api) != null ? typeof ref1.pauseVideo === "function" ? ref1.pauseVideo() : void 0 : void 0;
      }

      getCurrentTime() {
        var ref1;
        if (((ref1 = this.api) != null ? ref1.getCurrentTime : void 0) != null) {
          return this.api.getCurrentTime();
        } else {
          return 0;
        }
      }

      getDuration() {
        var ref1;
        if (((ref1 = this.api) != null ? ref1.getDuration : void 0) != null) {
          return this.api.getDuration();
        } else {
          return 0;
        }
      }

      getLoadedFraction() {
        var ref1;
        if (((ref1 = this.api) != null ? ref1.getVideoLoadedFraction : void 0) != null) {
          return this.api.getVideoLoadedFraction();
        } else {
          return 0;
        }
      }

      getUrl() {
        var ref1, ref2, ref3;
        return (ref1 = this.api) != null ? typeof ref1.getVideoUrl === "function" ? (ref2 = ref1.getVideoUrl()) != null ? (ref3 = ref2.match(/([A-Za-z0-9_\-]{11})/)) != null ? ref3[0] : void 0 : void 0 : void 0 : void 0;
      }

      // ----------------------
      loadYTAPI(callback) {
        var firstScriptTag, tag;
        if (document.YouTubeIframeAPIHasLoaded) {
          if (typeof callback === "function") {
            callback();
          }
          return;
        }
        window.onYouTubeIframeAPIReady = () => {
          document.YouTubeIframeAPIHasLoaded = true;
          return typeof callback === "function" ? callback() : void 0;
        };
        tag = document.createElement('script');
        tag.src = "https://www.youtube.com/iframe_api";
        firstScriptTag = document.getElementsByTagName('script')[0];
        return firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);
      }

      loadVideo(ytid, cue = false, seek = 0) {
        var m;
        if (m = ytid.match(/([A-Za-z0-9_\-]{11})/)) {
          ytid = m[1];
        } else {
          throw "unknown ID";
        }
        return this.loadYTAPI(() => {
          var base, base1;
          if (this.api) {
            if (cue) {
              if (typeof (base = this.api).cueVideoById === "function") {
                base.cueVideoById(ytid, seek);
              }
            } else {
              if (typeof (base1 = this.api).loadVideoById === "function") {
                base1.loadVideoById(ytid, seek);
              }
            }
            return this.api;
          } else {
            return this.api = new YT.Player('view', {
              videoId: ytid,
              height: '100%',
              width: '100%',
              //playerVars: controls: 0
              events: {
                onReady: (ev) => {
                  if (cue) {
                    this.api.cueVideoById(ytid, seek);
                  } else {
                    this.seekTo(seek);
                    this.play();
                  }
                  this.client.broadcastState(ev.data);
                  this.lastPlayerState = this.getState() != null ? this.getState() : 2;
                  return this.client.startBroadcast();
                },
                onStateChange: (ev) => {
                  var newState;
                  newState = this.getState();
                  if (!this.client.dontBroadcast && (this.lastPlayerState != null) && ([-1, 2].indexOf(this.lastPlayerState) > -1 && [1, 3].indexOf(newState) > -1)) {
                    console.log("send resume", this.lastPlayerState, newState);
                    this.client.sendControl("/resume");
                  } else if (!this.client.dontBroadcast && (this.lastPlayerState != null) && ([1, 3].indexOf(this.lastPlayerState) > -1 && [2].indexOf(newState) > -1)) {
                    console.log("send pause");
                    this.client.sendControl("/pause");
                  }
                  console.log("state", "was", this.lastPlayerState, "is", newState);
                  this.lastPlayerState = newState;
                  return this.client.broadcastState(ev.data);
                }
              }
            });
          }
        });
      }

      ensurePause(data) {
        var fails;
        this.client.dontBroadcast = true;
        fails = 0;
        return this.ensurePauseInterval = setInterval((() => {
          if (this.getState() == null) {
            return fails += 1;
          }
          if (data.state !== "pause") {
            return this.pauseEnsured();
          }
          if (!([5, -1].indexOf(this.getState()) > -1)) {
            return this.pauseEnsured();
          }
          if (this.getCurrentTime() === 0 && data.seek === 0) {
            return this.pauseEnsured();
          }
          if ([-1, 2].indexOf(this.getState()) > -1 && Math.abs(this.getCurrentTime() - data.seek) <= 0.5) {
            this.pauseEnsured();
            return this.client.broadcastState();
          } else {
            this.seekTo(data.seek, true);
            this.play() && this.pause();
            if ((fails += 1) > 40) {
              return this.pauseEnsured();
            }
          }
        }), 100);
      }

      pauseEnsured() {
        clearInterval(this.ensurePauseInterval);
        return this.client.dontBroadcast = false;
      }

    };

    SyncTubeClient_Player_Youtube.prototype.ctype = "Youtube";

    return SyncTubeClient_Player_Youtube;

  }).call(this);

  window.SyncTubeClient_UI = {
    init: function() {
      var base, base1, j, l, len, len1, ref1, ref2, results, x;
      if ((base = this.opts).maxWidth == null) {
        base.maxWidth = 12;
      }
      ref1 = this.VIEW_COMPONENTS;
      for (j = 0, len = ref1.length; j < len; j++) {
        x = ref1[j];
        if ((base1 = this.opts)[x] == null) {
          base1[x] = $(`#${x}`);
        }
      }
      ref2 = this.VIEW_COMPONENTS;
      results = [];
      for (l = 0, len1 = ref2.length; l < len1; l++) {
        x = ref2[l];
        results.push(this[x] = $(this.opts[x]));
      }
      return results;
    },
    start: function() {
      this.adjustMaxWidth();
      return this.captureInput();
    },
    adjustMaxWidth: function(i) {
      var hparams, maxWidth;
      hparams = this.getHashParams();
      maxWidth = i || hparams.maxWidth || hparams.width || hparams.mw || this.opts.maxWidth;
      return $("#page > .col").attr("class", `col col-${maxWidth}`);
    },
    captureInput: function() {
      return this.input.keydown((event) => {
        var i, m, msg, ref1, ref2;
        if (event.keyCode !== 13) {
          return true;
        }
        if (!(msg = this.input.val())) {
          return;
        }
        if ((ref1 = this.history) != null) {
          ref1.append(msg);
        }
        if (msg.charAt(0) === "/") {
          this.addSendCommand(msg);
        }
        if (m = msg.match(/^\/(?:mw|maxwidth|width)(?:\s([0-9]+))?$/i)) {
          i = parseInt(m[1]);
          if (m[1] && i >= 1 && i <= 12) {
            this.adjustMaxWidth(this.opts.maxWidth = i);
            this.input.val("");
          } else {
            this.content.append("<p>Usage: /maxwidth [1-12]</p>");
          }
          return;
        } else if (m = msg.match(/^\/(?:s|sync|resync)$/i)) {
          if ((ref2 = this.player) != null) {
            ref2.force_resync = true;
          }
          this.input.val("");
          return;
        } else if (m = msg.match(/^\/clear$/i)) {
          this.content.html("");
          this.input.val("");
          return;
        }
        this.connection.send(msg);
        return this.disableInput();
      });
    },
    enableInput: function(focus = true, clear = true) {
      if (clear && this.input.is(":disabled")) {
        this.input.val("");
      }
      this.input.removeAttr("disabled");
      if (focus) {
        this.input.focus();
      }
      return this.input;
    },
    disableInput: function() {
      this.input.attr("disabled", "disabled");
      return this.input;
    },
    addError: function(error) {
      var dt;
      dt = new Date();
      this.content.append(`<p>\n  <strong style="color: #ee5f5b">error</strong>\n  @ ${`0${dt.getHours()}`.slice(-2)}:${`0${dt.getMinutes()}`.slice(-2)}\n  <span style="color: #ee5f5b">${error}</span>\n</p>`);
      return this.content.scrollTop(this.content.prop("scrollHeight"));
    },
    addMessage: function(data) {
      var dt, tagname;
      dt = new Date(data.time);
      tagname = data.author === "system" ? "strong" : "span";
      this.content.append(`<p>\n  <${tagname} style="color:${data.author_color}">${data.author}</${tagname}>\n  @ ${`0${dt.getHours()}`.slice(-2)}:${`0${dt.getMinutes()}`.slice(-2)}\n  <span style="color: ${data.text_color}">${data.text}</span>\n</p>`);
      return this.content.scrollTop(this.content.prop("scrollHeight"));
    },
    buildSubscriberElement: function() {
      return $("<div data-client-index=\"\">\n  <div class=\"first\">\n    <span data-attr=\"admin-ctn\"><i></i></span>\n    <span data-attr=\"name\"></span>\n  </div>\n  <div class=\"second\">\n    <span data-attr=\"icon-ctn\"><i><span data-attr=\"progress\"></span> <span data-attr=\"timestamp\"></span></i></span>\n    <span data-attr=\"drift-ctn\" style=\"float:right\"><i><span data-attr=\"drift\"></span></i></span>\n    <div data-attr=\"progress-bar\"><div data-attr=\"progress-bar-buffered\"></div><div data-attr=\"progress-bar-position\"></div></div>\n  </div>\n</div>");
    },
    addSendCommand: function(msg) {
      var dt;
      dt = new Date();
      this.content.append(`<p style="color: #7a8288">\n  <span><i class="fa fa-terminal"></i></span>\n  @ ${`0${dt.getHours()}`.slice(-2)}:${`0${dt.getMinutes()}`.slice(-2)}\n  <span>${msg}</span>\n</p>`);
      return this.content.scrollTop(this.content.prop("scrollHeight"));
    }
  };

  window.SyncTubeClient_Util = {
    getHashParams: function() {
      var j, key, kv, kvp, len, parts, result;
      result = {};
      if (window.location.hash) {
        parts = window.location.hash.substr(1).split("&");
        for (j = 0, len = parts.length; j < len; j++) {
          kv = parts[j];
          kvp = kv.split("=");
          key = kvp.shift();
          result[key] = kvp.join("=");
        }
      }
      return result;
    }
  };

  // ./client/*.coffee will be inserted here by "npm run build" or "npm run dev"
  $(function() {
    var client;
    client = new SyncTubeClient({
      debug: true
    });
    return client.start();
  });

}).call(this);

// Generated by CoffeeScript 2.3.2
(function() {
  var SyncTubeClient;

  window.SyncTubeClient = SyncTubeClient = (function() {
    var ref;

    class SyncTubeClient {
      debug(...msg) {
        if (!this.opts.debug) {
          return;
        }
        msg.unshift(`[ST ${(new Date).toISOString()}]`);
        return console.debug.apply(this, msg);
      }

      warn(...msg) {
        msg.unshift(`[ST ${(new Date).toISOString()}]`);
        return console.warn.apply(this, msg);
      }

      error(...msg) {
        msg.unshift(`[ST ${(new Date).toISOString()}]`);
        return console.error.apply(this, msg);
      }

      constructor(opts = {}) {
        var base, base1, base2, base3, base4, base5, base6, base7, base8, j, l, len, len1, ref, ref1, x;
        this.opts = opts;
        // options
        if ((base = this.opts).debug == null) {
          base.debug = false;
        }
        if ((base1 = this.opts).maxWidth == null) {
          base1.maxWidth = 12;
        }
        ref = this.VIEW_COMPONENTS;
        for (j = 0, len = ref.length; j < len; j++) {
          x = ref[j];
          if ((base2 = this.opts)[x] == null) {
            base2[x] = $(`#${x}`);
          }
        }
        // synced settings (controlled by server)
        if ((base3 = this.opts).synced == null) {
          base3.synced = {};
        }
        if ((base4 = this.opts.synced).maxDrift == null) {
          base4.maxDrift = 60; // superseded by server instructions
        }
        if ((base5 = this.opts.synced).packetInterval == null) {
          base5.packetInterval = 10000; // superseded by server instructions
        }
        ref1 = this.VIEW_COMPONENTS;
        for (l = 0, len1 = ref1.length; l < len1; l++) {
          x = ref1[l];
          
          // DOM
          this[x] = $(this.opts[x]);
        }
        // connection options
        if ((base6 = this.opts).wsIp == null) {
          base6.wsIp = $("meta[name=synctube-server-ip]").attr("content");
        }
        if ((base7 = this.opts).wsPort == null) {
          base7.wsPort = $("meta[name=synctube-server-port]").attr("content");
        }
        if ((base8 = this.opts).wsProtocol == null) {
          base8.wsProtocol = $("meta[name=synctube-server-protocol]").attr("content");
        }
        // Client data
        this.name = null;
        this.index = null;
        this.drift = 0;
      }

      getHashParams() {
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

      start() {
        this.adjustMaxWidth();
        this.openWSconnection();
        this.detectBrokenConnection();
        this.captureInput();
        return this.listen();
      }

      adjustMaxWidth(i) {
        var hparams, maxWidth;
        hparams = this.getHashParams();
        maxWidth = i || hparams.maxWidth || hparams.width || hparams.mw || this.opts.maxWidth;
        return $("#page > .col").attr("class", `col col-${maxWidth}`);
      }

      openWSconnection() {
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
      }

      detectBrokenConnection() {
        return setInterval((() => {
          if (this.connection.readyState !== 1) {
            this.status.text("Error");
            this.disableInput().val("Unable to communicate with the WebSocket server. Please reload!");
            return setTimeout((function() {
              return window.location.reload();
            }), 1000);
          }
        }), 3000);
      }

      captureInput() {
        return this.input.keydown((event) => {
          var i, m, msg;
          if (event.keyCode !== 13) {
            return true;
          }
          if (!(msg = this.input.val())) {
            return;
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
            this.force_resync = true;
            this.input.val("");
            return;
          }
          this.connection.send(msg);
          return this.disableInput().val("");
        });
      }

      listen() {
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
      }

      enableInput(focus = true) {
        this.input.removeAttr("disabled");
        if (focus) {
          this.input.focus();
        }
        return this.input;
      }

      disableInput() {
        this.input.attr("disabled", "disabled");
        return this.input;
      }

      addMessage(data) {
        var dt, tagname;
        dt = new Date(data.time);
        tagname = data.author === "system" ? "strong" : "span";
        this.content.append(`<p>\n  <${tagname} style="color:${data.author_color}">${data.author}</${tagname}>\n  @ ${`0${dt.getHours()}`.slice(-2)}:${`0${dt.getMinutes()}`.slice(-2)}\n  <span style="color: ${data.text_color}">${data.text}</span>\n</p>`);
        return this.content.scrollTop(this.content.prop("scrollHeight"));
      }

      // =============
      // = YT Player =
      // =============
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
        this.destroyIframe();
        this.destroyImage();
        this.destroyVideo();
        if (m = ytid.match(/([A-Za-z0-9_\-]{11})/)) {
          ytid = m[1];
        } else {
          throw "unknown ID";
        }
        return this.loadYTAPI(() => {
          if (this.player) {
            if (cue) {
              this.player.cueVideoById(ytid, 0);
            } else {
              this.player.loadVideoById(ytid, 0);
            }
            return this.player;
          } else {
            return window.player = this.player = new YT.Player('view', {
              videoId: ytid,
              height: '100%',
              width: '100%',
              //playerVars: controls: 0
              events: {
                onReady: (ev) => {
                  var ref, ref1;
                  if (!cue) {
                    this.player.playVideo();
                  }
                  this.broadcastState(ev);
                  this.lastPlayerState = ((ref = this.player) != null ? ref.getPlayerState() : void 0) != null ? (ref1 = this.player) != null ? ref1.getPlayerState() : void 0 : 2;
                  return this.broadcastStateInterval = setInterval((() => {
                    return this.broadcastState({
                      data: this.lastPlayerState
                    });
                  }), this.opts.synced.packetInterval);
                },
                onStateChange: (ev) => {
                  var newState;
                  newState = this.player.getPlayerState();
                  if ((this.lastPlayerState != null) && ([-1, 2].indexOf(this.lastPlayerState) > -1 && [1, 3].indexOf(newState) > -1)) {
                    console.log("send resume");
                    this.connection.send("/resume");
                  } else if ((this.lastPlayerState != null) && ([1, 3].indexOf(this.lastPlayerState) > -1 && [2].indexOf(newState) > -1)) {
                    console.log("send pause");
                    this.connection.send("/pause");
                  }
                  console.log("state", "was", this.lastPlayerState, "is", newState);
                  this.lastPlayerState = newState;
                  return this.broadcastState(ev);
                }
              }
            });
          }
        });
      }

      openIframe(data) {
        this.destroyPlayer();
        this.destroyIframe();
        this.destroyImage();
        this.destroyVideo();
        return this.view.append(`<iframe id="view_frame" src="${data.url}" width="100%" height="100%"></iframe>`);
      }

      openImage(data) {
        this.destroyPlayer();
        this.destroyIframe();
        this.destroyImage();
        this.destroyVideo();
        return this.view.append(`<img id="view_image" src="${data.url}" height="100%">`);
      }

      openVideo(data) {
        var tag;
        this.destroyPlayer();
        this.destroyIframe();
        this.destroyImage();
        if (!this.view.find("#view_video").length) {
          this.view.append("<video id=\"view_video\" width=\"100%\" height=\"100%\" controls=\"true\">");
        }
        tag = this.view.find("#view_video");
        if (data.url !== tag.attr("src")) {
          tag.attr("src", data.url);
        }
        if (data.state === "play") {
          tag.attr("autoplay", "autoplay");
        } else {
          tag.removeAttr("autoplay");
        }
        if (data.loop) {
          return tag.attr("loop", "loop");
        } else {
          return tag.removeAttr("loop");
        }
      }

      destroyIframe() {
        return this.view.find("#view_frame").remove();
      }

      destroyImage() {
        return this.view.find("#view_image").remove();
      }

      destroyVideo() {
        return this.view.find("#view_video").remove();
      }

      destroyPlayer() {
        var ref;
        if ((ref = this.player) != null) {
          ref.destroy();
        }
        this.player = null;
        return clearInterval(this.broadcastStateInterval);
      }

      broadcastState(ev = (ref = this.player) != null ? ref.getPlayerState() : void 0) {
        var packet, ref1, ref2, ref3, ref4, state;
        state = (function() {
          switch (ev != null ? ev.data : void 0) {
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
          istate: ev != null ? ev.data : void 0,
          seek: (ref1 = this.player) != null ? ref1.getCurrentTime() : void 0,
          playtime: (ref2 = this.player) != null ? ref2.getDuration() : void 0,
          loaded_fraction: player.getVideoLoadedFraction(),
          url: (ref3 = player.getVideoUrl()) != null ? (ref4 = ref3.match(/([A-Za-z0-9_\-]{11})/)) != null ? ref4[0] : void 0 : void 0
        };
        return this.connection.send("!packet:" + JSON.stringify(packet));
      }

      // =================
      // = Control codes =
      // =================
      CMD_server_settings(data) {
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
      }

      CMD_load_video(data) {
        return this.loadVideo(data.ytid, data.cue);
      }

      CMD_ack() {
        return this.enableInput();
      }

      CMD_unsubscribe() {
        this.clients.html("");
        this.destroyPlayer();
        this.destroyIframe();
        this.destroyImage();
        return this.destroyVideo();
      }

      CMD_desired(data) {
        var current_ytid, ref1, ref2;
        if (data.ctype === "frame") {
          return this.openIframe(data);
        }
        if (data.ctype === "image") {
          return this.openImage(data);
        }
        if (data.ctype === "video") {
          return this.openVideo(data);
        }
        if (!this.player) {
          this.loadVideo(data.url, true, data.seek);
          return;
        }
        current_ytid = (ref1 = player.getVideoUrl()) != null ? (ref2 = ref1.match(/([A-Za-z0-9_\-]{11})/)) != null ? ref2[0] : void 0 : void 0;
        if (current_ytid !== data.url) {
          this.debug("Switching video from", current_ytid, "to", data.url);
          this.loadVideo(data.url);
          return;
        }
        if (Math.abs(this.drift * 1000) > this.opts.synced.maxDrift || this.force_resync || data.force) {
          this.force_resync = false;
          this.debug("Seek to correct drift", this.drift);
          this.player.seekTo(data.seek, true);
          return;
        }
        if (this.player.getPlayerState() === 1 && data.state !== "play") {
          this.debug("pausing playback, state:", this.player.getPlayerState());
          this.player.pauseVideo();
          this.player.seekTo(data.seek, true);
          return;
        }
        if (this.player.getPlayerState() !== 1 && data.state === "play") {
          this.debug("starting playback, state:", this.player.getPlayerState());
          this.player.playVideo();
        }
      }

      CMD_video_action(data) {
        var ref1;
        switch (data.action) {
          case "resume":
            return this.player.playVideo();
          case "pause":
            return this.player.pauseVideo();
          case "sync":
            return this.force_resync = true;
          case "destroy":
            if ((ref1 = this.player) != null) {
              ref1.destroy();
            }
            return this.player = null;
          case "seek":
            this.player.seekTo(data.to, true);
            if (data.paused) {
              return this.player.pauseVideo();
            } else {
              return this.player.playVideo();
            }
        }
      }

      CMD_navigate(data) {
        if (data.reload) {
          return window.location.reload();
        } else if (data.location) {
          return window.location.href = data.location;
        }
      }

      CMD_session_index(data) {
        return this.index = data.index;
      }

      CMD_require_username(data) {
        var hparams, p;
        this.enableInput();
        this.status.text("Choose name:");
        // check hash params
        if (data.autofill === false) {
          return;
        }
        hparams = this.getHashParams();
        if (p = hparams.user || hparams.username || hparams.name) {
          return this.connection.send(p);
        }
      }

      CMD_username(data) {
        var ch, cmd, hparams;
        this.name = data.username;
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
      }

      CMD_update_single_subscriber(resp) {
        var data, el, k, ref1, v;
        data = (resp != null ? resp.data : void 0) || {};
        if (data.index == null) {
          return;
        }
        el = this.clients.find(`[data-client-index=${data.index}]`);
        if (!el.length) {
          el = $(`<div data-client-index="${data.index}">\n  <div class="first">\n    <span data-attr="admin-ctn"><i></i></span>\n    <span data-attr="name"></span>\n  </div>\n  <div class="second">\n    <span data-attr="icon-ctn"><i><span data-attr="progress"></span> <span data-attr="timestamp"></span></i></span>\n    <span data-attr="drift-ctn" style="float:right"><i><span data-attr="drift"></span></i></span>\n    <div data-attr="progress-bar"><div data-attr="progress-bar-buffered"></div><div data-attr="progress-bar-position"></div></div>\n  </div>\n</div>`);
          this.clients.append(el);
        }
        for (k in data) {
          v = data[k];
          el.find(`[data-attr=${k}]`).html(v);
        }
        ref1 = data.state;
        for (k in ref1) {
          v = ref1[k];
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
      }

      CMD_subscriber_list(data) {
        var j, len, ref1, results, sub;
        this.clients.html("");
        ref1 = data.subscribers;
        results = [];
        for (j = 0, len = ref1.length; j < len; j++) {
          sub = ref1[j];
          results.push(this.CMD_update_single_subscriber({
            data: sub
          }));
        }
        return results;
      }

    };

    SyncTubeClient.prototype.VIEW_COMPONENTS = ["content", "view", "input", "status", "queue", "playlist", "clients"];

    return SyncTubeClient;

  }).call(this);

  $(function() {
    var client;
    client = new SyncTubeClient({
      debug: true
    });
    return client.start();
  });

}).call(this);

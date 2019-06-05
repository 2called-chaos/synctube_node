// Generated by CoffeeScript 2.3.2
(function() {
  var PlaylistManager, UTIL;

  UTIL = require("./util.js");

  exports.Class = PlaylistManager = class PlaylistManager {
    debug(...a) {
      return this.channel.debug("[PL]", ...a);
    }

    info(...a) {
      return this.channel.info("[PL]", ...a);
    }

    warn(...a) {
      return this.channel.warn("[PL]", ...a);
    }

    error(...a) {
      return this.channel.error("[PL]", ...a);
    }

    constructor(channel, data1 = {}) {
      this.channel = channel;
      this.data = data1;
      this.server = this.channel.server;
      this.set = null;
    }

    sdata(sub = this.set) {
      return this.data[sub];
    }

    onListChange(cb) {
      return this._onListChange = cb;
    }

    load(name, opts = {}) {
      var old;
      old = this.set;
      this.set = name;
      if (!this.data[this.set]) {
        this.debug(`Creating new playlist ${name}`);
        this.data[this.set] = Object.assign({}, {
          index: -1,
          entries: [],
          map: {},
          maxListSize: 100, 
          autoPlayNext: true,
          autoRemove: true,
          shuffle: false, 
          loop: false, 
          loadImageThumbs: true, 
          persisted: true 
        }, opts);
      }
      this.cUpdateList();
      if (this.data[old] && !this.data[old].persisted) {
        this.delete(old);
      }
      if (typeof this._onListChange === "function") {
        this._onListChange(this.set);
      }
      return this.data[this.set];
    }

    rebuildMaps() {
      var data, entry, name, ref, results;
      ref = this.data;
      results = [];
      for (name in ref) {
        data = ref[name];
        delete data["map"];
        data.map = {};
        results.push((function() {
          var j, len, ref1, results1;
          ref1 = data.entries;
          results1 = [];
          for (j = 0, len = ref1.length; j < len; j++) {
            entry = ref1[j];
            results1.push(data.map[entry[1]] = entry);
          }
          return results1;
        })());
      }
      return results;
    }

    delete(name = this.set) {
      if (name === "default") {
        throw "cannot delete default playlist";
      }
      if (name === this.set) {
        this.load("default");
        return delete this.data[name];
      } else {
        delete this.data[name];
        return this.cUpdateList();
      }
    }

    clear(name = this.set) {
      var sdata;
      if (!(sdata = this.data[name])) {
        return;
      }
      sdata.index = -1;
      sdata.entries = [];
      sdata.map = {};
      this.cUpdateList();
      return true;
    }

    cUpdateList(client) {
      var entries, i, j, len, qel, ref;
      entries = [];
      ref = this.data[this.set].entries;
      for (i = j = 0, len = ref.length; j < len; i = ++j) {
        qel = ref[i];
        qel[2].index = i;
        entries.push(qel[2]);
      }
      if (client) {
        return client.sendCode("playlist_update", {
          entries: entries,
          index: this.data[this.set].index
        });
      } else {
        return this.channel.broadcastCode(false, "playlist_update", {
          entries: entries,
          index: this.data[this.set].index
        });
      }
    }

    cUpdateIndex(client) {
      if (client) {
        return client.sendCode("playlist_update", {
          index: this.data[this.set].index
        });
      } else {
        return this.channel.broadcastCode(false, "playlist_update", {
          index: this.data[this.set].index
        });
      }
    }

    cAtStart() {
      return this.data[this.set].index === 0 && !this.cEmpty();
    }

    cAtEnd() {
      return this.data[this.set].index === (this.data[this.set].entries.length - 1);
    }

    cEmpty() {
      return this.data[this.set].entries.length === 0;
    }

    cPlayI(index) {
      index = parseInt(index);
      if (this.data[this.set].entries[index]) {
        this.data[this.set].index = index;
        this.cUpdateIndex();
        return this.channel.live(...this.data[this.set].entries[this.data[this.set].index]);
      } else {
        throw "no such index";
      }
    }

    cNext() {
      if (this.cEmpty()) {
        return false;
      }
      if (this.cAtEnd()) {
        return false;
      }
      if (this.data[this.set].autoRemove && this.data[this.set].entries[this.data[this.set].index]) {
        this.removeItemAtIndex(this.data[this.set].index);
      } else {
        this.data[this.set].index++;
        this.cUpdateIndex();
      }
      return this.channel.live(...this.data[this.set].entries[this.data[this.set].index]);
    }

    cPrev() {}

    removeItemAtIndex(index) {
      var _qel, activeElement, dmap, i, j, len, ref, url, wasActive, wasAtEnd;
      index = parseInt(index);
      wasAtEnd = this.cAtEnd();
      wasActive = index === this.data[this.set].index;
      activeElement = this.data[this.set].entries[this.data[this.set].index];
      url = this.data[this.set].entries[index][1];
      dmap = this.data[this.set].map;
      delete dmap[url];
      this.data[this.set].entries.splice(index, 1);
      ref = this.data[this.set].entries;
      for (i = j = 0, len = ref.length; j < len; i = ++j) {
        _qel = ref[i];
        // index bounds
        _qel[2].index = i;
      }
      if (activeElement) {
        this.data[this.set].index = activeElement[2].index;
      } else {
        this.data[this.set].index = Math.min(this.data[this.set].index, this.data[this.set].entries.length - 1);
      }
      if (this.data[this.set].entries.length === 0) {
        this.data[this.set].index = -1;
      }
      if (wasAtEnd && wasActive) {
        this.data[this.set].index = -1;
        this.channel.setDefaultDesired();
      }
      if (!wasAtEnd && this.data[this.set].index !== -1 && wasActive) {
        this.cPlayI(this.data[this.set].index);
      }
      return this.cUpdateList();
    }

    handlePlay() {
      var ref;
      if (!(((ref = this.channel.desired) != null ? ref.state : void 0) === "ended" || (this.data[this.set].entries.length === 1 && this.data[this.set].index === -1))) {
        return;
      }
      if (this.data[this.set].autoPlayNext) {
        return this.cNext();
      }
    }

    handleEnded() {
      if (this.data[this.set].autoPlayNext) {
        return this.cNext();
      }
    }

    add(ctype, url) {}

    //@data[@set].entries.push([ctype, url, player.getMeta(url)])
    ensurePlaylistQuota(client) {
      if (this.data[this.set].entries.length >= this.data[this.set].maxListSize) {
        if (client != null) {
          client.sendRPCResponse({
            error: `Playlist entry limit of ${this.data[this.set].maxListSize} exceeded!`
          });
        }
        if (client != null) {
          client.sendSystemMessage(`Playlist entry limit of ${this.data[this.set].maxListSize} exceeded!`);
        }
        return true;
      }
      return false;
    }

    intermission(method, ...args) {}

    // @getMeta: (url) ->
    playNext(ctype, url) {
      var _qel, activeElement, i, j, k, len, len1, qel, ref, ref1;
      if (this.ensurePlaylistQuota()) {
        return false;
      }
      if (this.cEmpty()) {
        return this.append(ctype, url);
      }
      activeElement = this.data[this.set].entries[this.data[this.set].index];
      if (qel = this.buildQueueElement(ctype, url)) {
        qel[2].index = this.data[this.set].index + 1;
      } else {
        qel = this.data[this.set].map[url];
        if (qel[2].index === this.data[this.set].index) {
          return;
        }
        this.data[this.set].entries.splice(qel[2].index, 1);
        ref = this.data[this.set].entries;
        for (i = j = 0, len = ref.length; j < len; i = ++j) {
          _qel = ref[i];
          _qel[2].index = i;
        }
      }
      this.data[this.set].entries.splice((activeElement ? activeElement[2].index : this.data[this.set].index) + 1, 0, qel);
      ref1 = this.data[this.set].entries;
      for (i = k = 0, len1 = ref1.length; k < len1; i = ++k) {
        _qel = ref1[i];
        // reset index
        _qel[2].index = i;
      }
      this.data[this.set].index = activeElement ? activeElement[2].index : qel[2].index;
      this.cUpdateList();
      return this.handlePlay();
    }

    append(ctype, url) {
      var _qel, activeElement, i, j, len, qel, ref;
      if (this.ensurePlaylistQuota()) {
        return false;
      }
      activeElement = this.data[this.set].entries[this.data[this.set].index];
      if (qel = this.buildQueueElement(ctype, url)) {
        this.data[this.set].entries.push(qel);
        qel[2].index = this.data[this.set].entries.length - 1;
        this.channel.broadcastCode(false, "playlist_single_entry", qel[2]);
      } else {
        qel = this.data[this.set].map[url];
        this.data[this.set].entries.splice(qel[2].index, 1);
        this.data[this.set].entries.push(qel);
        ref = this.data[this.set].entries;
        for (i = j = 0, len = ref.length; j < len; i = ++j) {
          _qel = ref[i];
          // reset index
          _qel[2].index = i;
        }
        this.data[this.set].index = this.data[this.set].index === -1 ? -1 : activeElement ? activeElement[2].index : qel[2].index;
        this.cUpdateList();
      }
      return this.handlePlay();
    }

    buildQueueElement(ctype, url) {
      var data;
      if (this.data[this.set].map[url]) {
        return false;
      }
      data = [ctype, url];
      data.push({
        ctype: ctype,
        name: `loading ${url}`,
        author: null,
        id: url,
        seconds: 0,
        timestamp: "0:00",
        thumbnail: false
      });
      this.data[this.set].map[url] = data;
      this.fetchMeta(...data);
      return data;
    }

    fetchMeta(ctype, url, data) {
      var e, m;
      try {
        if (data.thumbnail !== false) {
          return;
        }
        switch (ctype) {
          case "Youtube":
            data.name = [url, `https://youtube.com/watch?v=${url}`];
            return UTIL.jsonGetHttps(`https://www.youtube.com/oembed?url=http://www.youtube.com/watch?v=${url}&format=json`, (d) => {
              data.name = [d.title, `https://youtube.com/watch?v=${url}`];
              data.author = [d.author_name, d.author_url];
              data.thumbnail = d.thumbnail_url.replace("hqdefault", "default");
              return this.channel.broadcastCode(false, "playlist_single_entry", data);
            });
          case "HtmlImage":
            data.name = [((m = url.match(/\/([^\/]+)$/)) ? m[1] : url), url];
            data.thumbnail = url;
            data.author = "image";
            return this.channel.broadcastCode(false, "playlist_single_entry", data);
          case "HtmlVideo":
            data.name = [((m = url.match(/\/([^\/]+)$/)) ? m[1] : url), url];
            data.thumbnail = null;
            data.author = "video";
            return this.channel.broadcastCode(false, "playlist_single_entry", data);
          case "HtmlFrame":
            data.name = [url, url];
            data.thumbnail = null;
            data.author = "URL";
            return this.channel.broadcastCode(false, "playlist_single_entry", data);
        }
      } catch (error) {
        e = error;
        this.error(`Failed to load meta information: ${e}`);
        return console.trace(e);
      }
    }

  };

}).call(this);

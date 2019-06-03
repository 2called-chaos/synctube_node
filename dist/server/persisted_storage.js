// Generated by CoffeeScript 2.3.2
(function() {
  var PersistedStorage, fs, path;

  fs = require('fs');

  path = require('path');

  exports.Class = PersistedStorage = class PersistedStorage {
    debug(...a) {
      return this.server.debug("[PStor]", ...a);
    }

    info(...a) {
      return this.server.info("[PStor]", ...a);
    }

    warn(...a) {
      return this.server.warn("[PStor]", ...a);
    }

    error(...a) {
      return this.server.error("[PStor]", ...a);
    }

    constructor(server, key, opts = {}) {
      this.server = server;
      this.key = key;
      this.opts = opts;
      this._beforeSave = [];
      this._onLoad = [];
      this.storage = this.opts.default || {};
      this.file = `${this.server.root}/data/${this.key}.json`;
      if (!(this.opts.hasOwnProperty("fetch") && !this.opts.fetch)) {
        this.sFetch(this.opts.default);
      }
      if (this.opts.assign_to) {
        this.sAssignTo(this.opts.assign_to);
      }
    }

    sAssignTo(into) {
      var k, ref, results, v;
      ref = this.storage;
      results = [];
      for (k in ref) {
        v = ref[k];
        results.push(((k, v) => {
          return into[k] = v;
        })(k, v));
      }
      return results;
    }

    sFetch(defVal = {}) {
      var func, i, j, len, ref, results;
      if (fs.existsSync(this.file)) {
        this.debug(`Fetching ${this.key} from ${this.file}`);
        this.storage = JSON.parse(fs.readFileSync(this.file));
        ref = this._onLoad;
        results = [];
        for (i = j = 0, len = ref.length; j < len; i = ++j) {
          func = ref[i];
          this.debug(`Applying onLoad#${i} function for ${this.key}`);
          results.push(func(this, this.storage));
        }
        return results;
      } else {
        this.debug(`Using default for ${this.key}`);
        return this.storage = defVal || {};
      }
    }

    sSave() {
      var dir, func, i, j, len, ref;
      ref = this._beforeSave;
      for (i = j = 0, len = ref.length; j < len; i = ++j) {
        func = ref[i];
        this.debug(`Applying beforeSave#${i} function for ${this.key}`);
        func(this, this.storage);
      }
      dir = path.dirname(this.file);
      if (!fs.existsSync(dir)) {
        this.debug(`Creating directory structure for ${this.key}: ${dir}`);
        fs.mkdirSync(dir, {
          recursive: true
        });
      }
      this.debug(`Writing ${this.key} to ${this.file}.tmp`);
      fs.writeFileSync(`${this.file}.tmp`, JSON.stringify(this.storage));
      this.debug(`Atomic tmp move ${this.file}`);
      return fs.renameSync(`${this.file}.tmp`, this.file);
    }

    // =============
    // = Accessors =
    // =============
    transaction(cb) {
      if (typeof cb !== "function") {
        return;
      }
      cb(this.storage);
      return this.sSave();
    }

    beforeSave(cb) {
      return this._beforeSave.push(cb);
    }

    onLoad(cb) {
      return this._onLoad.push(cb);
    }

    hasKey(k) {
      return this.storage.hasOwnProperty(k);
    }

    get(k) {
      return this.storage[k];
    }

    fetch(k, d) {
      if (this.hasKey(k)) {
        return this.get(k);
      } else {
        return d;
      }
    }

    set(k, v) {
      var ref;
      this.storage[k] = v;
      return (ref = this.opts.assign_to) != null ? ref[k] = v : void 0;
    }

    rem(k) {
      return delete this.storage[k];
    }

    persist(k, v) {
      this.set(k, v);
      return this.sSave();
    }

    purge(k) {
      this.rem(k);
      return this.sSave();
    }

  };

}).call(this);

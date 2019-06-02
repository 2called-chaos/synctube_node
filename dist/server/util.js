// Generated by CoffeeScript 2.3.2
(function() {
  exports.shellQuote = function(array) {
    return require("shell-quote").quote(array);
  };

  exports.shellSplit = function(str, env, cleaned = true) {
    var _env, j, len, r, ref, x;
    r = [];
    _env = env || {};
    if (cleaned) {
      env || (env = function(k) {
        if (_env[k] != null) {
          return _env[k];
        } else {
          return `\${${k}}`;
        }
      });
    }
    ref = require("shell-quote").parse(str, env || _env);
    for (j = 0, len = ref.length; j < len; j++) {
      x = ref[j];
      if (cleaned && typeof x !== "string") {
        if (x.op != null) {
          r.push(x.op);
        } else if (x.pattern != null) {
          r.push(x.pattern);
        } else {
          console.warn("unrecognized shell quote object", x);
        }
      } else {
        r.push(x);
      }
    }
    return r;
  };

  exports.extractArg = function(args, keys, vlength = 0) {
    var i, j, k, len, spliced;
    spliced = null;
    for (j = 0, len = keys.length; j < len; j++) {
      k = keys[j];
      i = args.indexOf(k);
      if (i > -1) {
        spliced = args.splice(i, 1 + vlength);
        if (vlength) {
          return spliced.slice(1);
        } else {
          return true;
        }
      }
    }
    return false;
  };

  exports.htmlEntities = function(str) {
    return String(str).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  };

  exports.delay = function(ms, func) {
    return setTimeout(func, ms);
  };

  exports.strbool = function(v, rescue) {
    if (["true", "t", "1", "y", "yes", "on"].indexOf(v) > -1) {
      return true;
    }
    if (["false", "f", "0", "n", "no", "off"].indexOf(v) > -1) {
      return false;
    }
    if (rescue != null) {
      return rescue;
    } else {
      throw `Can't convert \`${v}' to boolean, expression invalid!`;
    }
  };

  exports.startsWith = function(str, ...which) {
    var j, len, w;
    if (typeof str !== "string") {
      return false;
    }
    for (j = 0, len = which.length; j < len; j++) {
      w = which[j];
      if (str.slice(0, w.length) === w) {
        return true;
      }
    }
    return false;
  };

  exports.endsWith = function(str, ...which) {
    var j, len, w;
    if (typeof str !== "string") {
      return false;
    }
    for (j = 0, len = which.length; j < len; j++) {
      w = which[j];
      if (str.slice(-w.length) === w) {
        return true;
      }
    }
    return false;
  };

  exports.argsToStr = function(args) {
    var a, j, len, r;
    r = [];
    for (j = 0, len = args.length; j < len; j++) {
      a = args[j];
      r.push(typeof a === "string" ? a : a.pattern);
    }
    return r.join(" ");
  };

  exports.trim = function(str) {
    return String(str).replace(/^\s+|\s+$/g, "");
  };

  exports.isRegExp = function(input) {
    return input && typeof input === "object" && input.constructor === RegExp;
  };

  exports.escapeRegExp = function(str) {
    return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  };

  exports.bytesToHuman = function(bytes) {
    var byteUnits, i;
    bytes = parseInt(bytes);
    i = -1;
    byteUnits = [' KB', ' MB', ' GB', ' TB', 'PB', 'EB', 'ZB', 'YB'];
    while (true) {
      bytes = bytes / 1024;
      i++;
      if (bytes <= 1024) {
        break;
      }
    }
    return Math.max(bytes, 0.1).toFixed(1) + byteUnits[i];
  };

  exports.microToHuman = function(micro) {
    if (micro > 1000000) {
      return `${micro / 1000000} s`;
    } else if (micro > 1000) {
      return `${parseInt(micro / 1000)} ms`;
    } else {
      return `${micro} μs`;
    }
  };

  exports.parseEasyDuration = function(dur) {
    if (exports.endsWith(dur, "w")) {
      return parseInt(dur) * (60 * 60 * 27 * 7);
    }
    if (exports.endsWith(dur, "d")) {
      return parseInt(dur) * (60 * 60 * 24);
    }
    if (exports.endsWith(dur, "h")) {
      return parseInt(dur) * (60 * 60);
    }
    if (exports.endsWith(dur, "m")) {
      return parseInt(dur) * 60;
    }
    if (exports.endsWith(dur, "s")) {
      return parseInt(dur);
    }
    return dur;
  };

  exports.secondsToArray = function(sec) {
    var j, len, r, ref, x;
    r = [];
    ref = [60 * 60, 60];
    for (j = 0, len = ref.length; j < len; j++) {
      x = ref[j];
      if (sec >= x || r.length) {
        r.push(parseInt(sec / x));
        sec %= x;
      }
    }
    // seconds & fraction
    r.push(parseInt(sec));
    sec -= parseInt(sec);
    r.push(parseInt(sec * 1000));
    return r;
  };

  exports.secondsToTimestamp = function(sec, fract = 3) {
    var fraction, i, j, len, r, sa, slice, x;
    sa = exports.secondsToArray(sec).reverse();
    if (sa.length === 2) {
      sa.push(0);
    }
    r = [];
    for (i = j = 0, len = sa.length; j < len; i = ++j) {
      x = sa[i];
      slice = i === 0 ? 3 : 2;
      r.push(i < 2 || sa[i + 1] ? `000${x}`.slice(slice * -1) : x.toString());
    }
    fraction = r.shift();
    if (fract) {
      return r.reverse().join(":") + `.${fraction.slice(-fract)}`;
    } else {
      return r.reverse().join(":");
    }
  };

  exports.videoTimestamp = function(cur, max, fract = 2) {
    return [exports.secondsToTimestamp(cur, fract), exports.secondsToTimestamp(max, fract).replace(/\.[0]+$/, "")].join(" / ");
  };

  exports.timestamp2Seconds = function(ts) {
    var add, i, j, len, parts, seconds, x;
    parts = ts.replace(/\.[0-9]+$/, "").split(":").reverse();
    seconds = 0;
    for (i = j = 0, len = parts.length; j < len; i = ++j) {
      x = parts[i];
      add = i === 0 ? parseInt(x) : parseInt(x) * Math.pow(60, i);
      seconds += (function() {
        if (isNaN(add)) {
          throw "invalidNaN";
        } else {
          return add;
        }
      })();
    }
    return seconds;
  };

  exports.jsonGetHttps = function(url, cb) {
    var body;
    body = "";
    return require("https").get(url, (res) => {
      res.setEncoding("utf8");
      res.on("data", (d) => {
        return body += d;
      });
      return res.on("end", () => {
        return cb(JSON.parse(body));
      });
    });
  };

}).call(this);

// Generated by CoffeeScript 2.3.2
(function() {
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

  exports.secondsToArray = function(sec) {
    var j, len, r, ref, x;
    r = [];
    ref = [60 * 60, 60];
    for (j = 0, len = ref.length; j < len; j++) {
      x = ref[j];
      if (sec >= x) {
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
    return r.reverse().join(":") + `.${fraction.slice(-fract)}`;
  };

  exports.videoTimestamp = function(cur, max, fract = 2) {
    return [exports.secondsToTimestamp(cur, fract), exports.secondsToTimestamp(max, fract).replace(/\.[0]+$/, "")].join(" / ");
  };

}).call(this);

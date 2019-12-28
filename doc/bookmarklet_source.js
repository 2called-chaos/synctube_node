//-----------------------------------------
//--- Single/Playlist (with notification)
//-----------------------------------------
(function (b) {
  n = Notification;
  x = function (a) {
    h = "%wsurl%";
    s = "https://statics.bmonkeys.net/img/rpcico/";
    w = window;
    l = w.location.href;
    w.stwsb = w.stwsb || [];

    const nl = document.querySelectorAll("ytd-playlist-panel-renderer:not(.ytd-miniplayer) a.ytd-playlist-panel-video-renderer");
    const idl = Array.prototype.map.call(nl, n => {
      const m = n.href.match(/([A-Za-z0-9_\-]{11})/);
      if(m){ return m[0] } else { return m }
    }).filter(i=>!!i);

    if (idl.length) {
      if(!confirm("Add "+idl.length+" videos from playlist?")) {
        im = l.match(/([A-Za-z0-9_\-]{11})/);
        if(im && confirm("Do you want to add the current video instead?\\nwatch?v="+im[0])) {
          idl.length = 0;
          idl.push(l)
        } else {
          return
        }
      }
    } else {
      idl.push(l)
    }

    if (w.stwsc) {
      if (w.stwsc.readyState != 1) {
        idl.forEach(ytid => w.stwsb.push(a+ytid));
      } else {
        idl.forEach(ytid => w.stwsc.send(a+ytid));
      }
    } else {
      w.stwsb.push("rpc_client");
      idl.forEach(ytid => w.stwsb.push(a+ytid));
      w.stwsc = new WebSocket(h);
      w.stwsc.onmessage = function(m){
        j = JSON.parse(m.data);
        if(j.type == "rpc_response") {
          new n("SyncTube", { body: j.data.message, icon: s + j.data.type + ".png" })
        }
      };
      w.stwsc.onopen = function(){
        while (w.stwsb.length) { w.stwsc.send(w.stwsb.shift()) }
      };
      w.stwsc.onerror = function(){
        alert("stwscError: failed to connect to " + h);
        console.error(arguments[0])
      };
      w.stwsc.onclose = function(){ w.stwsc = null }
    }
  };

  if (n.permission === "granted" || n.permission === "denied") {
    x(b)
  } else {
    n.requestPermission().then(function(result) { x(b) })
  }
})("/rpc -k %key% -c %channel% play ")


//------------------------------------------
//--- Single/Playlist (without notification)
//------------------------------------------

(function (a) {
  h = "%wsurl%";
  w = window;
  l = w.location.href;
  w.stwsb = w.stwsb || [];

  const nl = document.querySelectorAll("ytd-playlist-panel-renderer:not(.ytd-miniplayer) a.ytd-playlist-panel-video-renderer");
  const idl = Array.prototype.map.call(nl, n => {
    const m = n.href.match(/([A-Za-z0-9_\-]{11})/);
    if(m){ return m[0] } else { return m }
  }).filter(i=>!!i);

  if (idl.length) {
    if(!confirm("Add "+idl.length+" videos from playlist?")) {
      im = l.match(/([A-Za-z0-9_\-]{11})/);
      if(im && confirm("Do you want to add the current video instead?\\nwatch?v="+im[0])) {
        idl.length = 0;
        idl.push(l)
      } else {
        return
      }
    }
  } else {
    idl.push(l)
  }

  if (w.stwsc) {
    if (w.stwsc.readyState != 1) {
      idl.forEach(ytid => w.stwsb.push(a+ytid));
    } else {
      idl.forEach(ytid => w.stwsc.send(a+ytid));
    }
  } else {
    w.stwsb.push("rpc_client");
    idl.forEach(ytid => w.stwsb.push(a+ytid));
    w.stwsc = new WebSocket(h);
    w.stwsc.onopen = function(){
      while (w.stwsb.length) { w.stwsc.send(w.stwsb.shift()) }
    };
    w.stwsc.onerror = function(){
      alert("stwscError: failed to connect to " + h);
      console.error(arguments[0])
    };
    w.stwsc.onclose = function(){ w.stwsc = null }
  }
})("/rpc -k %key% -c %channel% play ")

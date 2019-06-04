(function (b) {
  n = Notification;
  x = function (a) {
    h = "%wsurl%";
    s = "https://statics.bmonkeys.net/img/rpcico/";
    w = window;
    w.stwsb = w.stwsb || [];
    if (w.stwsc) {
      if (w.stwsc.readyState != 1) {
        w.stwsb.push(a)
      } else {
        w.stwsc.send(a)
      }
    } else {
      w.stwsb.push("rpc_client");
      w.stwsb.push(a);
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
})("/rpc -k %key% -c %channel% play " + window.location)



//-----------------------------------------

(function (a) {
  h = "%wsurl%";
  w = window;
  w.stwsb = w.stwsb || [];
  if (w.stwsc) {
    if (w.stwsc.readyState != 1) {
      w.stwsb.push(a)
    } else {
      w.stwsc.send(a)
    }
  } else {
    w.stwsb.push("rpc_client");
    w.stwsb.push(a);
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
})("/rpc -k %key% -c %channel% play " + window.location)

SyncTubeServer = require("./server/core.js")

server = new SyncTubeServer.Class
  debug: true
  port: 3000
server.listen()

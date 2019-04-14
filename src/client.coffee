# ./client/*.coffee will be inserted here by "npm run build" or "npm run dev"

$ ->
  client = new SyncTubeClient
    debug: true
    clipboardPoll:
      autostartIfGranted: false
  client.welcome => client.start()

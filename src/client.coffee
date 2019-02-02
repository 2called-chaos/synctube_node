# ./client/*.coffee will be inserted here by "npm run build" or "npm run dev"

$ ->
  client = new SyncTubeClient
    debug: true
  client.welcome => client.start()

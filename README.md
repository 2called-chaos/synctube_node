# SyncTube (Node)

## WiP: indev (unstable and everything is suspect to sudden change)

SyncTube (Node) is a simple node.js server (and web client) to watch YouTube videos (and more) together.<br>
This is my first node experience. The project is written in CoffeeScript, the dist folder contains up2date JS

---

## Help
If you need help or have problems [open an issue](https://github.com/2called-chaos/synctube_node/issues/new).<br>
Feel free to leave some feedback or request features as well, just dump your thoughts into the issues.


## Features/Facts

  * Easy setup
  * Server
    * unlimited named channels with optional control password and text chat
    * unlimited people in control (every admin can pause/resume/seek/change video)
    * although many are in control only the host (single admin) serves as "clock", transitions automatically
    * databaseless (nothing is persisted yet), future playlist features may utilize SQLite or JSON text files

  * Client
    * (I hope) [appealing default layout](https://i.imgur.com/lXSnNQq.png) (dark theme, responsive) served by node server, better one for large screens coming
    * Easily bookmark your settings with URL hash (e.g. `.../#user=myname&control=mychannel&maxWidth=10`)
    * detailed sync information (e.g. client drift from host)
    * technically works via chat commands but can be abstracted into UI

  * Supported sources
    * YouTube (full-sync)
    * HTML video (mp4/webp, full-sync)
    * Images (status-sync)
    * URLs/Frames (no-sync except init, quite useless due to Same-Origin Policy)

  * Many more planned, check further down below


## Requirements

  * Node (sorry no idea about versions, I only know 4.2.6 doesn't work)
  * npm (sorry no idea about versions)


## Installation (via npm)

  * coming soon when I figured out how to do it properly


## Installation (via git)

  * Go somewhere you want to install the server to (note: it might persists data into this directory) `cd /home/synctube`
  * `git clone https://github.com/2called-chaos/synctube_node.git`
  * `cd synctube_node`
  * Install dependencies with `npm install --only=prod`
  * Optional: `cp config.example.js config.js` and edit config (generated on first start otherwise)
  * Optional: Use a webserver (like nginx) to tunnel WS and server static assets ([example config](https://github.com/2called-chaos/synctube_node/wiki/Nginx-configuration))
  * Run via `npm start` or `node dist/server.js` (put it in a screen or something, maybe someone can explain npm services to me :D)
  * Visit the IP/port in your browser and enjoy


## Usage

No help yet, these are client commands you can enter into the chat thingy.<br>
Unless otherwise specified all commands are being send to and processed by the server.

    (CLIENT COMMAND) /mw /maxwidth /width [1-12]
      Changes max width of the entire page (bootstrap columns 1-12)

    (CLIENT COMMAND) /s /sync /resync
      Forces seek to desired state on next update, ignoring maxDrift

    (GLOBAL) /clear
      Clears your chat

    (GLOBAL) /join <channel>
      Join a given channel

    (GLOBAL) /dc /disconnect
      Closes your connection to the server

    (GLOBAL) /control [channel] [password]
      If you are in a channel and the channel has no password you can omit the name, otherwise it's mandatory.
      If the channel does not exist it will be created, with the provided password or passwordless if omitted!
      If you ARE in control and `/control <channel> delete`, the channel will be deleted!

    (GLOBAL) /rename
      Allows you to change your display name, no arguments, next message you send will be your name

    (GLOBAL) /tc /togglechat
      Toggle chat & client display

    (GLOBAL) /tpl /togglepl /toggleplaylist
      Toggle playlist

    (CHANNEL) /retry
      Revokes control, leaves and rejoins channel

    (CHANNEL) /leave /quit
      Leave current channel, revoke control if applicable

    (CHANNEL-CONTROL) /p(ause) /r(esume) /t(oggle)
      Pause, resume or toggle playback

    (CHANNEL-CONTROL) /seek [+-]<seconds>
      Seek to given or relative time, seconds may be a timecode like "2:30" or "-10:00"

    (CHANNEL-CONTROL) /pause /resume /toggle
      Pause, resume or toggle playback by forcing it as desired state

    (CHANNEL-CONTROL) /yt /youtube /play [-n --next] <str containing ytid>
      Play given video in current channel

    (CHANNEL(-CONTROL)) /loop [1/0/on/off/yes/no/y/n/true/false]
      Display current loop status (no argument, all users) or enable/disable it (control only)

    (CHANNEL-CONTROL) /video /vid /mp4 /webp <mp4/webp URL>
      Play given video in current channel

    (CHANNEL-CONTROL) /image /img /picture /pic /gif /png /jpg <Image URL>
      Show given image to current channel

    (CHANNEL-CONTROL) /browse /url <URL>
      Warning: doesn't recognize failed loads due to Same-Origin Policy, pretty useless unfortunately
      Show given URL to current channel

    (CHANNEL-CONTROL) /password <password> [bool:revoke=false]
      Change channel control password, optionally revoke all clients (except you)

    (CHANNEL-CONTROL) /copt [opt] [newval]
      List, view or change channel options

    (CHANNEL-CONTROL) /rpckey
      Show you the current RPC key (will change with channel password)

    (CHANNEL-CONTROL) /bookmarklet [-h --help] | [-a --action=youtube] [-n --notifications] [-l --label LABEL]
      Gives you a button you can drag to your bookmarks to add items to the playlist from e.g. YouTube tabs

    (CHANNEL-CONTROL) /host [name-regex]
      Makes you or matching user the new host, both clients are required to be in control

    (CHANNEL-CONTROL) /grant <name-regex>
      Grants control to given user

    (CHANNEL-CONTROL) /revoke [name-regex]
      Revokes control for you or given user

    (CHANNEL-CONTROL) /kick <name-regex> [message]
      Kick client from channel with optional message

    (CHANNEL-CONTROL) /alias /aliases [-l --list] | <name> [-d --delete] [command]
      [Plugin] Add custom aliases with optional arguments (0 = all arguments)
      (e.g. `/alias /kc /kick chaos ${0}` can then be used `/kc [reason]`)

    (CHANNEL-CONTROL) /pl /playlist
      [Plugin] playlist control commands
        /playlist list
          list existing playlists
        /playlist load <name> [-v --volatile]
          load existing or new playlist, volatile destroys the playlist when another is loaded
        /playlist saveas
          not implemented
        /playlist delete <name>
          delete playlist, it's entries and settings
        /playlist clear
          clear current playlist (entries only)
        /playlist opt [opt] [newvalue]
          list, view or change playlist options
        /playlist next
          not implemented
        /playlist prev
          not implemented
        /playlist play [index]
          play entry by index
        /playlist remove [index]
          remove entry by index

    (CHANNEL-INTERNAL) /ready /rdy
      Internal, unused code to signal readyness when switching videos

    (GLOBAL) !packet:{jsondata}
      Internal command to communicate client states

    (GLOBAL) /rpc <-k --key KEY> <-c --channel CHANNEL> <rpc_call>
      Allowed remote access to a limited set of channel control features

    (GLOBAL-DEBUG)
      /system auth <syspw>
        authenticate, required for all other system commands
      /system restart
        end process, restart if daemonized or development
      /system gracefulRestart cancel | <period> [message]
        same as restart but with optional grace period and message
      /system message <message>
        broadcast system message to all connected clients
      /system chmessage <channel> <message>
        broadcast system message to all clients in given channel
      /system chkill <channel>
        kick all clients in given channel and then delete it
      /system status
        show some system information
      /system clients
        show connected clients
      /system banip <ip>
        ban ip
      /system unbanip <ip>
        unban ip
      /system invoke [-t --target <name-regex>] <CTRLcode> <JSON string>
        invoke control code on you or given target
      /system kick <name-regex> [message]
        kick given target from the server with optional message
      /system dump <client|channel> [id/name] | commands
        dump information to system console

    (GLOBAL-DEBUG) /dump client|channel [name or index]
      development: dump specific or all client/channel to server console

    (GLOBAL-DEBUG) /restart
      development: quits the server process which will restart if started with run_dev.sh script

These are recognized parameters that can be used in the URL hash

    user|username|name    Username, otherwise required as first message
    mw|width|maxWidth     (default: 12) max side width (bootstrap columns, 1-12)
    join|channel          Join given channel after name is provided
    control               Join and control given channel after name is provided.
                          Will be created if it doesn't exist (with or without provided password)
    password              Optional control password if control is provided

    Example: localhost:3000#name=foo&control=bar&password=baz&mw=6


## Planned (S: Server, C: Client)

  * UI: altered layout for big screens (multi column)
  * UI: Visual controls for clients (grant/revoke/kick/forceSync)
  * S/C: sync playback speed, implement slowmo seekbacks
  * S/C: sync loop (HtmlVideo: done, YT: manual implementation? also no getter)
  * S/C: (named?) Playlists and proposal queue (non-admins can propose to separate queue, admins can approve or discard)
  * S/C: show who seeked/toggled/added stuff via overlayed notifications (channel setting)
  * S/C: Help command (tricky since client has a few commands)
  * S/C: (system/channel) intermissions
  * S: More sane static asset delivery (I mean it works...)
  * S: Persisted channel settings (maxDrift, packetInterval, ytid-aliases, cueDefault, chatMode, suggestedQuality, readyGracePeriod)
  * S: too many packets/control instruction detection and throttling
  * C: VideoHTML allow source per client to allow syncing of restricted links from e.g. streaming sites
  * C: better detect host/detect control seeks in YT player
  * C: Enhanced control keyboard shortcuts (build into commandbar?) (toggle play, seek, volume, next video, approve first in queue, change speed)
  * C: YouTube search, bookmark/ext? to add from YT side
  * C: experiment with live drift correction by changing playback speed (client setting, channel setting default)
    This will probably work good with HTML Video (mp4/webp player) since it has stepless speed, YT may only have the .25 steps
  * C: register clipboard changes to suggest videos in playlist (we can't detect end/pause card clicks so client has to allow clipboard read and rightlick->copy link)
  * C: search videos
  * C: other players (what are people using these days? vimeo? can you embed netflix? :D)


## Client control codes (for dev)

    ack
    desired
    lost_control
    navigate
    require_username
    server_settings
    session_index
    subscriber_list
    taken_control
    unsubscribe
    update_single_subscriber
    username
    video_action


## Contributing
  Contributions are very welcome! Either report errors, bugs and propose features or directly submit code:

  1. Fork it
  2. Create your feature branch (`git checkout -b my-new-feature`)
  3. Commit your changes (`git commit -am 'Added some feature'`)
  4. Push to the branch (`git push origin my-new-feature`)
  5. Create new Pull Request

  You will need `npm install coffeescript` and `npm run dev` or `npm run build`


## Legal
* © 2019, Sven Pachnit (www.bmonkeys.net)
* synctube_node is licensed under the MIT license.

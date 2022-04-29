# utilities to be used by commands
# gotta keep things tidy.

emojme = require 'emojme'
SlackClient = require('emojme/lib/slack-client')
fs = require 'graceful-fs'
glob = require 'glob'
sharp = require 'sharp'
request = require 'request'
inspect = require('util').inspect

one_day = 1000 * 60 * 60 * 24

emojiList = []

module.exports = (robot) ->
  ensure_no_public_tokens: (request, authJsonString) ->
    if request.message.room[0] == 'C'
      try
        authJson = JSON.parse(authJsonString)
        token = authJson["token"]
        cookie = authJson["cookie"]
        subdomain = authJson["domain"] || authJson["subdomain"] || request.message.user.slack.team_id.replace(/:/g,'').trim()
        slack = new SlackClient(subdomain, cookie)
        if !(token and cookie)
          throw "No Auth"
        slack.request("/chat.delete", {token: token, channel: request.message.room, ts: request.message.id}).then (response) ->
          if response.ok
            request.send("Don't go posting slack auth tokens in public channels ya dummy. I went ahead and deleted it for you this time using your token that you just posted.")
          else
            request.send("Don't go posting slack auth tokens in public channels ya dummy. Delete that or I'm telling mom.")
      catch
        request.send("Don't go posting slack auth tokens in public channels ya dummy. Delete that or I'm telling mom.")

  emojme_download: (request, subdomain, token, cookie, action) ->
    self = this
    downloadPromise = if process.env.LOCAL_EMOJI
      new Promise (resolve) ->
        resolve {subdomain: {emojiList: JSON.parse(fs.readFileSync(process.env.LOCAL_EMOJI, 'utf-8'))}}
    else
      emojme.download(subdomain, token, cookie, {bustCache: true, output: true})

    downloadPromise
      .then (downloadResult) =>
        lastUser = request.message.user.name
        lastUpdate = Date.now()
        emojiList = downloadResult[subdomain].emojiList
        robot.brain.set 'emojme.AuthUser', lastUser
        robot.brain.set 'emojme.LastUpdatedAt', lastUpdate
        robot.brain.set 'emojme.AdminList', emojiList

        request.send("#{request.message.user.name} updated the emoji cache, make sure to thank them!")
        action(emojiList, lastUser, lastUpdate)
      .catch (e) ->
        self.expire_user_auth request.envelope.user.id
        console.log("[ERROR] #{e} #{e.stack}")
        request.send("Looks like something went wrong, is your token correct? Did you provide a Cookie too?")
        throw e

  emojme_favorites: (request, subdomain, token, cookie, action) ->
    self = this
    favoritesPromise = emojme.favorites subdomain, token, cookie, {lite: true}
    favoritesPromise
      .then (favoritesResult) =>
        # TODO: save results to redis for global stats
        action favoritesResult[subdomain].favoritesResult.favoriteEmojiAdminList
      .catch (e) ->
        self.expire_user_auth request.envelope.user.id
        console.log("[ERROR] #{e} #{e.stack}")
        request.send("Looks like something went wrong, is your token correct? Did you provide a Cookie too?")
        throw e

  emojme_alias: (request, subdomain, token, cookie, original, alias, action) ->
    self = this
    aliasPromise = emojme.add subdomain, token, cookie, {name: alias, aliasFor: original, allowCollisions: true}
    aliasPromise
      .then (addResult) =>
        action addResult[subdomain]
      .catch (e) ->
        self.expire_user_auth request.envelope.user.id
        console.log("[ERROR] #{e} #{e.stack}")
        request.send("Looks like something went wrong, is your token correct? Did you provide a Cookie too?")
        throw e

  emojme_add: (request, subdomain, token, emoji_name, url, action) ->
    self = this
    addPromise = emojme.add subdomain, token, {name: emoji_name, src: url, allowCollisions: true}
    addPromise
      .then (addResult) =>
        action addResult[subdomain]
      .catch (e) ->
        self.expire_user_auth request.envelope.user.id
        console.log("[ERROR] #{e} #{e.stack}")
        request.send("Looks like something went wrong, is your token correct?")
        throw e


  do_login: (request, action) ->
    self = this
    user_id = request.envelope.user.id

    auth = self.get_user_auth user_id
    if auth.token64 and auth.cookie64 and auth.subdomain and (Date.now() < auth.expiration)
      self.use_cached_auth request, auth, action
    else
      self.collect_new_auth request, action

  use_cached_auth: (request, auth, action) ->
    self = this
    user_id = request.envelope.user.id
    token = Buffer.from(auth.token64, 'base64').toString('ascii')
    cookie = Buffer.from(auth.cookie64, 'base64').toString('ascii')
    robot.send {room: user_id}, "Cool, we'll just use the auth you have saved. If it doesn't work, I'll ask for a new token.\nCarrying on back at #{self.message_url request}"

    action(auth.subdomain, token, cookie)
      .catch (e) ->
        request.send {room: user_id}, "Bad news, that didn't work out. I'll clear out your saved token and cookie and you can just try again from scratch. Sorry bout that!"

  collect_new_auth: (request, action) ->
    self = this
    user_id = request.envelope.user.id
    team_id = request.envelope.user.slack.team_id || request.message.user.slack.team_id || process.env.SLACK_TEAM_ID
    self.expire_user_auth user_id
    dialog = robot.emojmeConversation.startDialog request, 300000 # I know this isn't 60 seconds it's a joke
    robot.send {room: user_id}, "Hey #{request.envelope.user.name}, in order to do what you've asked I'm gonna need a bit of authentication. Use the <https://chrome.google.com/webstore/detail/emojme-emoji-anywhere/nbnaglaclijdfidbinlcnfdbikpbdkog|Emojme Chrome Extension> to collect an auth blob, or read about how to collect your own <https://github.com/jackellenberger/emojme#finding-a-slack-token|token> and <https://github.com/jackellenberger/emojme#finding-a-slack-cookie|cookie>. What I'm looking for is a json string, something like, `{\"token\":\"xoxc-...\",\"cookie\":\"long-inscrutible-string\"}` Just send that alone as message, please."
    dialog.addChoice /({.*})/i, (authResponse) ->
      subdomain = request.message.user.slack.team_id.replace(/:/g,'').trim()
      authJsonString = authResponse.match[0].trim()

      try
        authJson = JSON.parse(authJsonString)
        token = authJson["token"]
        cookie = authJson["cookie"]
        if subdomain and token and cookie
          robot.send {room: user_id}, "Thanks! Carrying on back at #{self.message_url request}"
        else
          throw "Could not determine subdomain, token, and cookie. Malformed input?"
      catch
        robot.send {room: user_id}, "Bad news, that didn't work out. Maybe try again? Remember, auth now looks like a json blob, and you need both a token _and_ a cookie."

      action(subdomain, token, cookie)
        .then () =>
          robot.send {room: user_id}, "Want to save that auth for a day? If so, just slap me with a `yeah doggo`"
          dialog.addChoice /:?(?:highfive|high_five|high-five|highfive-1590):?|(?:hell )?yeah dog(?:go)?/i, (saveResponse) ->
            self.set_user_auth user_id, subdomain, token, cookie
            robot.send {room: user_id}, "Saved."
        .catch () -> {}
          # handled upstream

  get_user_auth: (user_id) ->
    return {
      token64: (robot.brain.get "emojme.#{user_id}.token"),
      cookie64: (robot.brain.get "emojme.#{user_id}.cookie"),
      expiration: (robot.brain.get "emojme.#{user_id}.expiration"),
      subdomain: (robot.brain.get "emojme.#{user_id}.subdomain"),
    }

  set_user_auth: (user_id, subdomain, token, cookie) ->
    robot.brain.set "emojme.#{user_id}.subdomain", subdomain
    robot.brain.set "emojme.#{user_id}.token", Buffer.from(token).toString('base64')
    robot.brain.set "emojme.#{user_id}.cookie", Buffer.from(cookie).toString('base64')
    robot.brain.set "emojme.#{user_id}.expiration", (Date.now() + one_day)

  expire_user_auth: (user_id) ->
    robot.brain.set "emojme.#{user_id}.subdomain", null
    robot.brain.set "emojme.#{user_id}.token", null
    robot.brain.set "emojme.#{user_id}.cookie", null
    robot.brain.set "emojme.#{user_id}.expiration", null

  require_cache: (request, action) ->
    self = this
    self.readAdminList (emojiList) ->
      if (
        (emojiList) &&
        (lastUser = robot.brain.get 'emojme.AuthUser' ) &&
        (lastRefresh = robot.brain.get 'emojme.LastUpdatedAt' )
      )
        action emojiList, lastUser, lastRefresh
      else
        request.send "The emoji cache has gone missing, would you mind updating it? I've sent you few instructions."
        self.do_login request, (subdomain, token, cookie) ->
          self.emojme_download request, subdomain, token, cookie, (emojiList, lastUser, lastUpdate) ->
            action(emojiList, lastUser, lastUpdate)


  message_url: (request) ->
    team_id = try request.message.user.slack.team_id catch e then "team_id"
    room_id = try request.message.room catch e then "room_id"
    request_id = try request.message.id catch e then "message_id"
    "https://#{team_id}.slack.com/archives/#{room_id}/#{request_id}"

  find_emoji: (request, emojiList, emojiName, action) ->
    if typeof emojiName != 'undefined' && (emoji = emojiList.find((emoji) -> emoji.name == emojiName))
      original_name = emoji.alias_for
      if original_name && (original_emoji = emojiList.find((emoji) -> emoji.name == original_name))
        action(emoji, original_emoji)
      else
        action(emoji)
    else
      request.send("I don't recognize :#{emojiName}:, if it exists, my cache might need a refresh. Call `emojme refresh` to find out how")

  find_author: (request, emojiList, authorName, action) ->
    self = this
    self.find_emoji_by 'user_display_name', authorName, emojiList, (foundEmojiList) ->
      if foundEmojiList && foundEmojiList.length > 0
        action(foundEmojiList)
      else
        self.find_display_name_by_name authorName, (realAuthorName) ->
          if realAuthorName
            self.find_emoji_by 'user_display_name', realAuthorName, emojiList, (foundEmojiList) ->
              if foundEmojiList && foundEmojiList.length > 0
                action(foundEmojiList)
              else
                request.send("Hmm, '#{authorName}', a.k.a '#{realAuthorName}', huh? Never heard of em. Maybe they haven't been contributing emoji?")
          else
            request.send("Hmm, '#{authorName}', huh? Never heard of em. Either they don't exist, they have no emoji, or you're not using their Slack display name.")

  send_emoji_list: (request, emojiList) ->
    if !emojiList or emojiList.length == 0
      request.send "No emoji here, sorry!"
    else if emojiList.length < 25
      request.send(emojiList.map((emoji) -> ":#{emoji.name}:").join(" "))
    else
      try
        request.send("threading :this:")
        index = 0
        while index < emojiList.length
          robot.adapter.client.web.chat.postMessage(
            request.message.user.room,
            emojiList.slice(index, index+100).map((emoji) -> ":#{emoji.name}:").join(" "),
            {thread_ts: request.message.id}
          )
          index += 100
      catch
        request.send("Ahh I can't do it, something's wrong")

  find_emoji_by: (field, value, emojiList, action) ->
    action(emojiList.filter((emoji) -> emoji[field] == value))

  find_display_name_by_name: (name, action) ->
    user = robot.brain.userForName(name.replace(/@/g,''))
    if user
      action(user.real_name)

  find_archive_entry: (emoji_name, action) ->
    emoji_archive = robot.brain.get "emojme.emojiArchive"
    emoji_archive ?= {}
    action(emoji_archive[emoji_name])

  save_archive_entry: (emoji_name, message, action) ->
    emoji_archive = robot.brain.get "emojme.emojiArchive"
    emoji_archive ?= {}
    emoji_archive[emoji_name] = message
    robot.brain.set "emojme.emojiArchive", emoji_archive

  delete_archive_entry: (emoji_name) ->
    emoji_archive = robot.brain.get "emojme.emojiArchive"
    emoji_archive ?= {}
    delete emoji_archive[emoji_name]
    robot.brain.set "emojme.emojiArchive", emoji_archive
  react: (request, reaction) ->
    try
      robot.adapter.client.web.reactions.add(reaction, {
        channel: request.message.user.room,
        timestamp: request.message.id
      })
    catch e
      if robot.adapter.client
        console.log("[WARNING] unable to react to message: #{e} #{e.stack}")
  readAdminList: (action) ->
    self = this
    brainLastUpdated = robot.brain.get "emojme.LastUpdatedAt"
    self.getEmojiListLastUpdate (fileLastUpdated, filename) ->
      if (fileLastUpdated && (!brainLastUpdated || (brainLastUpdated < fileLastUpdated)))
        fs.readFile filename, (err, data) ->
          adminList = JSON.parse(data)
          robot.brain.set "emojme.LastUpdatedAt", fileLastUpdated
          robot.brain.set "emojme.AdminList", adminList
          action adminList
      else if (brainLastUpdated)
        action robot.brain.get "emojme.AdminList"
      else
        action null
  getEmojiListLastUpdate: (action) ->
    glob "build/*adminList.json", (err, files) ->
      if files.length
        action fs.statSync(files[0]).mtime, files[0]
      else
        action null

  doubleEnhance: (url, name, action) ->
    request {url, encoding: null}, (err, res, body) ->
      if err
        console.log("[ERROR] error grabbing url: #{url} #{err.message}")
      type = url.split(".").pop()
      filename = "build/#{name}_#{Date.now()}.#{type}"
      sharp(body).resize(512, 512).toFile filename, (err, info) ->
        if err
          console.log("[ERROR] scaling emoji: #{name} #{err.message}")
        console.log("wrote out #{filename}")
        action filename, fs.createReadStream(filename)

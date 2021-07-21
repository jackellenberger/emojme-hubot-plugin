# Description:
#   A way to interact with emojme functions
#
# Commands:
#   hubot emojme [00] help - print help message
#   hubot emojme [01] refresh (with <subdomain>:<token>) - authenticate and grab list of emoji, enabling all other commands. If subdomain and token are not provided up front they will be asked for. Do not post tokens in public channels.
#   hubot emojme [02] status - print the age of the cache and who last updated it
#   hubot emojme [03] random - give a random emoji
#   hubot emojme [04] N random - give N random emoji
#   hubot emojme [05] random emoji by <user> - give a random emoji made by <user>
#   hubot emojme [06] tell me about :<emoji>: - give the provided emoji's metadata
#   hubot emojme [07] when was :<emoji>: made - give the provided emoji's creation date, if available.
#   hubot emojme [08] enhance :<emoji>: - give the provided emoji's source image at highest availalbe resolution
#   hubot emojme [09] how many emoji has <author> made? - give the provided author's emoji statistics.
#   hubot emojme [10] who made :<emoji>: - give the provided emoji's author.
#   hubot emojme [11] show me the emoji <author> made - give the provided author's emoji
#   hubot emojme [12] who all has made an emoji? - list all emoji authors
#   hubot emojme [13] show me my <10> most used emoji - give the usage counts of the emoji you use to +react most often
#   hubot emojme [14] show me all the new emoji since <some NLP interpretable day> - show all the emoji created since 'yesterday', 'three days ago', 'last week', etc.
#   hubot emojme [15] dump all emoji (with metadata)? - upload a list of emoji names, or emoji metadata if requestek
#   hubot emojme [16] commit this to the record of :<emoji>:: <message> - save an explanation for the given emoji
#   hubot emojme [17] purge the record of :<emoji>: - delete all explanation for the given emoji
#   hubot emojme [18] what does the record state about :<emoji>:? - read the emoji's explanation if it exists
#   hubot emojme [19] what emoji are documented? - give the names of all documented emoji
#   hubot emojme [20] alias :<existing>: to :<new-alias>: - create a new emoji directly from slack sort of
#   hubot emojme [21] forget my login - delete cached user token. If not touched a login expires in 24 hours
#   hubot emojme [22] double enhance :<emoji>: - enhance the emoji to 512x512. gifs only give the first frame. s/o to @kevkid
#   hubot emojme [23] add :<emoji>: url - create a new emoji using the given image, make sure the url ends in the format
#   hubot emojme [24] who's responsible for :<emoji>: - the same as "who made," but sassier
#
# Author:
#   Jack Ellenberger <jellenberger@uchicago.edu>
slack = require 'slack'
Conversation = require 'hubot-conversation'
chrono = require('chrono-node')

Util = require './util'

module.exports = (robot) ->
  util = new Util robot
  robot.emojmeConversation = new Conversation robot

  robot.respond /emojme help/i, (request) ->
    request.send("""
Hey there! emojme is an project made to interface with the dark parts of slack's api: the emoji endpoints.

In order to do anything with it here, you'll need to make sure that hubot knows about your list of emoji, which you can check on with `emojme status`.

If there is no emoji cache or it's out of date, you can fix that with `@hubot emojme refresh`, that'll lead you by the hand to getting a cookie and a token and updating the list of emoji that I know about. There will be a 60 second time window to enter your cookie and token, so get a head start by checking out the docs [on the emojme repo](https://github.com/jackellenberger/emojme#finding-a-slack-token)

Questions, comments, concerns? Ask em either on emojme, or on [this project](https://github.com/jackellenberger/emojme-hubot-plugin), whatever's relevant.
""")


  robot.respond /(emojme|token).*(xoxs-\d{12}-\d{12}-\d{12}-\w{64})/i, (request) ->
    token = request.match[1]
    util.ensure_no_public_tokens request, token

  robot.respond /emojme (?:forget|clear|expire) my (?:login|credentials|creds|auth|password|token)/i, (request) ->
    util.expire_user_auth request.envelope.user.id
    util.react request, "done"

  robot.respond /emojme status/i, (request) ->
    util.require_cache request, (emojiList, lastUser, lastRefresh) ->
      request.send("#{lastUser} last refreshed the emoji list back at #{Date(lastRefresh).toString()} when there were #{emojiList.length} emoji")

  robot.respond /emojme refresh$/i, (request) ->
    util.react request, "stand-by"
    util.do_login request, (subdomain, token, cookie) ->
      util.emojme_download request, subdomain, token, cookie, (emojiList, lastUser, lastUpdate) ->
        util.react request, "done"
        request.send("emoji database refresh complete, found #{emojiList.length} of em. :nice:")

  robot.respond /emojme refresh with (.*)/i, (request) ->
    authJsonString = authResponse.match[1].trim()
    try
      authJson = JSON.parse(authJsonString)
      token = authJson["domain"] || authJson["subdomain"]
      token = authJson["token"]
      cookie = authJson["cookie"]
      if subdomain and token and cookie
        util.emojme_download request, subdomain, token, cookie, (emojiList, lastUser, lastUpdate) ->
        request.send("emoji database refresh complete, found #{emojiList.length} of em. :nice:")
      else
        throw "Could not determine subdomain, token, and cookie. Malformed input?"
    catch
      robot.send {room: user_id}, "Bad news, that didn't work out. Maybe try again? Remember, auth now looks like a json blob, and you need both a token _and_ a cookie."

  robot.respond /emojme (?:what are |show me )?my (\d* )?(?:favorites?|most used)(?: emoji)?\??/i, (request) ->
    count = parseInt (request.match[1] || "10").trim(), 10
    util.react request, "stand-by"
    util.do_login request, (subdomain, token, cookie) ->
      util.emojme_favorites request, subdomain, token, cookie, (favorites) ->
        util.react request, "done"
        favoritesString = favorites.slice(0, count).map (emojiData) ->
          emojiName = Object.keys(emojiData)[0]
          emojiUsage = emojiData[emojiName].usage
          "\n:#{emojiName}: #{emojiUsage} times"
        request.send("#{request.envelope.user.name} has reacted with: #{favoritesString}")

  robot.respond /emojme alias :(.*): (?:to )?:(.*):/i, (request) ->
    original = request.match[1].trim()
    alias = request.match[2].trim()
    util.do_login request, (subdomain, token, cookie) ->
      util.emojme_alias request, subdomain, token, cookie, original, alias, (addResult) ->
        if addResult.errorList.length > 0
          request.send "Bad news, we got some errors just then: #{addResult.errorList.map((e) => e.error)}"
        else if addResult.collisions.length > 0
          request.send "uhhh was that name taken?"
        else if addResult.emojiList.length > 0
          request.send "Successfully added :#{alias}:"

  robot.respond /emojme add :(.*): (.*)/i, (request) ->
    emoji_name = request.match[1].trim()
    url = request.match[2].trim()
    util.do_login request, (subdomain, token) ->
      util.emojme_add request, subdomain, token, emoji_name, url, (response) ->
        console.log(response)
        if response.errorList
          request.send("Ope, ran into something: #{response.errorList[0].error}")
        else
          request.send("check it :#{emoji_name}:")

  robot.respond /(?:emojme )?(?:(\d*) )?random(?: emoji)?(?: by (.*))?/i, (request) ->
    util.require_cache request, (emojiList, lastUser, lastRefresh) ->
      count = request.match[1] || 1
      emojis = []
      if (author = request.match[2])
        util.find_author request, emojiList, author.trim(), (authorsEmoji) ->
          emojis.push(":#{authorsEmoji[Math.floor(Math.random()*authorsEmoji.length)].name}:") for [1..count] if count
      else
        emojis.push(":#{emojiList[Math.floor(Math.random()*emojiList.length)].name}:") for [1..count] if count
      request.send(emojis.join(" "))

  robot.respond /emojme (?:list|dump) all (?:the )?emoji((?: with)? metadata)?/i, (request) ->
    util.require_cache request, (emojiList, lastUser, lastRefresh) ->
      # Give metadata if asked for, otherwise just emoji names
      content = if request.match[1] then emojiList else emojiList.map((emoji) -> emoji.name)
      try
        robot.adapter.client.web.files.upload('adminList.txt', {
          content: JSON.stringify(content, null, 2),
          channels: request.message.room,
          initial_comment: "Here are the emoji as of #{lastRefresh}"
        })
      catch
        request.send("I have like #{emojiList.length} emoji but I'm having a hard time uploading them.")

  robot.respond /emojme show me(?: |all|the|new)+? emoji(?: by (.*))?(?: since (.*))/i, (request) ->
    util.require_cache request, (emojiList, lastUser, lastRefresh) ->
      since = chrono.parseDate(request.match[2]).getTime() / 1000
      if author = request.match[1]
        util.find_author request, emojiList, author.trim(), (authorsEmoji) ->
          emojiList = authorsEmoji
      if since
        emojiList = emojiList.filter((emoji) -> emoji.created > since)

      util.send_emoji_list request, emojiList

  robot.respond /emojme show me (?:all )?the emoji (?:that )?(.*?) (?:has )?made/i, (request) ->
    util.require_cache request, (emojiList, lastUser, lastRefresh) ->
      author = request.match[1]
      util.find_author request, emojiList, author, (authorsEmoji) ->
        util.send_emoji_list request, authorsEmoji

  robot.respond /emojme tell me about :(.*?):/i, (request) ->
    util.require_cache request, (emojiList, lastUser, lastRefresh) ->
      util.find_emoji request, emojiList, request.match[1].replace(/:/g,''), (emoji, _) ->
        util.find_archive_entry emoji.name, (archive_entry) ->
          emoji.archive_entry = archive_entry
        request.send("Ah, :#{emoji.name}:, I know it well...\n```#{JSON.stringify(emoji, null, 2)}```")

  robot.respond /emojme (?:enhance|show me|source)\!? :(.*?):/i, (request) ->
    util.require_cache request, (emojiList, lastUser, lastRefresh) ->
      util.find_emoji request, emojiList, request.match[1].replace(/:/g,''), (emoji, _) ->
        request.send("#{emoji.url}?x=#{Date.now()}")

  robot.respond /emojme double enhance :(.*?):/i, (request) ->
    util.require_cache request, (emojiList, lastUser, lastRefresh) ->
      util.find_emoji request, emojiList, request.match[1].replace(/:/g,''), (emoji, _) ->
        util.react request, "stand-by"
        util.doubleEnhance emoji.url, emoji.name, (filename, enhanced_image_file_stream) ->
          opts = {
            title: "#{emoji.name} ENHANCE!!1!",
            file: enhanced_image_file_stream,
            channels: request.message.room
          }
          robot.adapter.client.web.files.upload(filename, opts)

  robot.respond /emojme (?:who made|who(?:\'s| is) responsible for) (?:the )?:(.*?):(?: emoji)?\??/i, (request) ->
    util.require_cache request, (emojiList, lastUser, lastRefresh) ->
      util.find_emoji request, emojiList, request.match[1].replace(/:/g,''), (emoji, original) ->
        message = "That would be #{emoji.user_display_name}"
        if original
          message += ", but #{original.user_display_name} made the original, `:#{original.name}:`"
        request.send(message)

  robot.respond /emojme when was :(.*?): (?:made|created)\??/i, (request) ->
    util.require_cache request, (emojiList, lastUser, lastRefresh) ->
      util.find_emoji request, emojiList, request.match[1].replace(/:/g,''), (emoji, original) ->
        message = "I don't know, ask #{emoji.user_display_name}!"
        if timestamp = (emoji.created * 1000)
          message = ":#{emoji.name}: was made by #{emoji.user_display_name} back on #{new Date(timestamp).toString()}"
          if original && original_timestamp = (original.timestamp * 1000)

            message += ", but #{original.user_display_name} made the original `#{original.name}` on #{new Date(original_timestamp).toString()}"
        request.send(message)

  robot.respond /emojme how many emoji has (.*?) made\??/i, (request) ->
    util.require_cache request, (emojiList, lastUser, lastRefresh) ->
      author = request.match[1].trim()
      util.find_author request, emojiList, author, (authorsEmoji) ->
        total = authorsEmoji.length
        originals = authorsEmoji.filter((emoji) -> emoji.is_alias == 0).length
        request.send("Looks like #{author} has #{total} emoji, #{originals} originals and #{total - originals} aliases")

  robot.respond /emojme who (?:all )?has (made|contributed|created|submitted) (?:an )?emoji\??/i, (request) ->
    util.require_cache request, (emojiList, lastUser, lastRefresh) ->
      authors = Array.from(new Set(emojiList.map((emoji) => emoji.user_display_name))).sort()
      request.send(authors.join(", "))

  robot.respond /emojme commit this to the record (?:of|for) :(.*?):\s?: (.*)/i, (request) ->
    emoji_name = request.match[1].replace(/:/g, '')
    message = request.match[2].replace(/“|"|”/g, '')
    util.find_archive_entry emoji_name, (existing_entry) ->
      if existing_entry
        request.send("Overwriting previous interpretation of :#{emoji_name}:: #{existing_entry}")
    util.save_archive_entry emoji_name, message
    util.react request, "gavel"

  robot.respond /emojme (?:delete|purge|clear|clean) the record (?:of|for) :(.*?):/i, (request) ->
    emoji_name = request.match[1].replace(/:/g, '')
    util.find_archive_entry emoji_name, (existing_entry) ->
      if existing_entry
        request.send("Deleting previous interpretation of :#{emoji_name}:: #{existing_entry}")
    delete_archive_entry emoji_name

  robot.respond /emojme what does the (?:record|archive) (?:state|say) (?:about|for|of) :(.*?):\??/i, (request) ->
    emoji_name = request.match[1].replace(/:/g, '')
    util.find_archive_entry emoji_name, (existing_entry) ->
      if existing_entry
        request.send("\"#{existing_entry}\"")
      else
        request.send("Nothing! https://i.kym-cdn.com/photos/images/original/000/721/333/5d1.gif")

  robot.respond /emojme (?:which|what|how many) emoji are documented\??/i, (request) ->
    emoji_archive = robot.brain.get "emojme.emojiArchive"
    emoji_archive ?= {}
    names = Object.keys(emoji_archive)
    emoji = if names.length == 0 then ":shrug:" else names.map((name) => ":#{name}: ")
    request.send("Looks like we got explanations for #{names.length} emoji, including #{emoji}")
    if names.length < 10
      request.send("Jimmy Wales says if we all wrote one emoji explanation we'd have a lot more explanations than this\nhttps://i.kym-cdn.com/entries/icons/original/000/004/510/Jimmeh.jpg")

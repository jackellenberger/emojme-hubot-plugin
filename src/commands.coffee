# Description:
#   A way to interact with emojme functions
#
# Commands:
#   hubot emojme help - print help message
#   hubot emojme status - print the age of the cache and who last updated it
#   hubot emojme refresh <subdomain>:<token> - authenticate and grab list of emoji, enabling all other commands. If subdomain and token are not provided up front they will be asked for.
#   hubot emojme random - give a random emoji
#   hubot emojme N random - give N random emoji
#   hubot emojme random emoji by <user> - give a random emoji made by <user>
#   hubot emojme dump all emoji (with metadata)? - upload a list of emoji names, or emoji metadata if requested
#   hubot emojme tell me about :<emoji>: - give the provided emoji's metadata
#   hubot emojme enhance :<emoji>: - give the provided emoji's source image at highest availalbe resolution
#   hubot emojme who made :<emoji>: - give the provided emoji's author.
#   hubot emojme when was :<emoji>: made - give the provided emoji's creation date, if available.
#   hubot emojme how many emoji has <author> made? - give the provided author's emoji statistics.
#   hubot emojme show me the emoji <author> made - give the provided author's emoji
#   hubot emojme who all has made an emoji? - list all emoji authors
#   hubot emojme commit this to the record of :<emoji>:: <message> - save an explanation for the given emoji
#   hubot emojme purge the record of :<emoji>: - delete all explanation for the given emoji
#   hubot emojme what does the record state about :<emoji>:? - read the emoji's explanation if it exists
#   hubot emojme what emoji are documented? - give the names of all documented emoji
#
# Author:
#   Jack Ellenberger <jellenberger@uchicago.edu>
slack = require 'slack'
Conversation = require 'hubot-conversation'

Util = require './utils'

module.exports = (robot) ->
  util = new Util robot
  robot.emojmeConversation = new Conversation robot

  robot.respond /emojme help/i, (request) ->
    context.send("""
Hey there! emojme is an project made to interface with the dark parts of slack's api: the emoji endpoints.

In order to do anything with it here, you'll need to make sure that hubot knows about your list of emoji, which you can check on with `emojme status`.

If there is no emoji cache or it's out of date, you can fix that with `@hubot emojme refresh`, that'll lead you by the hand to getting a user token and updating the list of emoji that I know about. There will be a 60 second time window to enter your token, so get a head start by checking out the docs [on the emojme repo](https://github.com/jackellenberger/emojme#finding-a-slack-token)

Questions, comments, concerns? Ask em either on emojme, or on [this project](https://github.com/jackellenberger/emojme-hubot-plugin), whatever's relevant.
""")


  robot.respond /emojme status/i, (request) ->
    util.require_cache request, (emojiList, lastUser, lastRefresh) ->
      request.send("#{lastUser} last refreshed the emoji list back at #{lastRefresh} when there were #{emojiList.length} emoji")

  robot.respond /emojme refresh/i, (request) ->
    util.do_login request, request, (subdomain, token) ->
      util.emojme_download request, request, subdomain, token, (emojiList, lastUser, lastUpdate) ->
        request.send("emoji database refresh complete, found #{emojiList.length} of em. :nice:")

  robot.respond /emojme refresh (.*:)?(xoxs-.*)/i, (request) ->
    subdomain = (request.match[1] || request.message.user.slack.team_id).replace(/:/g,'').trim()
    token = (request.match[2] || null).trim()
    util.emojme_download request, request, subdomain, token, (emojiList, lastUser, lastUpdate) ->
      request.send("emoji database refresh complete, found #{emojiList.length} of em. :nice:")

  robot.respond /emojme (?:(\d*) )?random(?: emoji)?(?: by (.*))?/i, (request) ->
    util.require_cache request, (emojiList, lastUser, lastRefresh) ->
      count = request.match[1] || 1
      emojis = []
      if (author = request.match[2])
        util.find_author request, emojiList, author.trim(), (authorsEmoji) ->
          emojis.push(":#{authorsEmoji[Math.floor(Math.random()*authorsEmoji.length)].name}:") for [1..count] if count
      else
        emojis.push(":#{emojiList[Math.floor(Math.random()*emojiList.length)].name}:") for [1..count] if count
      request.send(emojis.join(" "))

  robot.respond /(?:emojme )?(?:list|dump) all (?:the )?emoji((?: with)? metadata)?/i, (request) ->
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

  robot.respond /(?:emojme )?show me (?:all )?the emoji (?:that )?(.*?) (?:has )?made/i, (request) ->
    util.require_cache request, (emojiList, lastUser, lastRefresh) ->
      author = request.match[1]
      util.find_author request, emojiList, author, (authorsEmoji) ->
        if authorsEmoji.length < 25
          request.send(authorsEmoji.map((emoji) -> ":#{emoji.name}:").join(" "))
        else
          try
            request.send("#{author} has like #{authorsEmoji.length} emoji, I'm gonna thread this")
            index = 0
            while index < authorsEmoji.length
              robot.adapter.client.web.chat.postMessage(
                request.message.user.room,
                authorsEmoji.slice(index, index+100).map((emoji) -> ":#{emoji.name}:").join(" "),
                {thread_ts: request.message.id}
              )
              index += 100
          catch
            request.send("Ahh I can't do it, something's wrong")

  robot.respond /(?:emojme )?tell me about :(.*?):/i, (request) ->
    util.require_cache request, (emojiList, lastUser, lastRefresh) ->
      util.find_emoji request, emojiList, request.match[1].replace(/:/g,''), (emoji, _) ->
        util.find_archive_entry emoji.name, (archive_entry) ->
          emoji.archive_entry = archive_entry
        request.send("Ah, :#{emoji.name}:, I know it well...\n```#{JSON.stringify(emoji, null, 2)}```")

  robot.respond /(?:emojme )?(?:enhance|show me|source)\!? :(.*?):/i, (request) ->
    util.require_cache request, (emojiList, lastUser, lastRefresh) ->
      util.find_emoji request, emojiList, request.match[1].replace(/:/g,''), (emoji, _) ->
        request.send("#{emoji.url}")

  robot.respond /(?:emojme )?who made (?:the )?:(.*?):(?: emoji)?\??/i, (request) ->
    util.require_cache request, (emojiList, lastUser, lastRefresh) ->
      util.find_emoji request, emojiList, request.match[1].replace(/:/g,''), (emoji, original) ->
        message = "That would be #{emoji.user_display_name}"
        if original
          message += ", but #{original.user_display_name} made the original, `:#{original.name}:`"
        request.send(message)

  robot.respond /(?:emojme )?when was :(.*?): (?:made|created)\??/i, (request) ->
    util.require_cache request, (emojiList, lastUser, lastRefresh) ->
      util.find_emoji request, emojiList, request.match[1].replace(/:/g,''), (emoji, original) ->
        message = "I don't know, ask #{emoji.user_display_name}!"
        if timestamp = (emoji.created * 1000)
          message = ":#{emoji.name}: was made by #{emoji.user_display_name} back on #{new Date(timestamp).toString()}"
          if original && original_timestamp = (original.timestamp * 1000)

            message += ", but #{original.user_display_name} made the original `#{original.name}` on #{new Date(original_timestamp).toString()}"
        request.send(message)

  robot.respond /(?:emojme )?how many emoji has (.*?) made\??/i, (request) ->
    util.require_cache request, (emojiList, lastUser, lastRefresh) ->
      author = request.match[1].trim()
      util.find_author request, emojiList, author, (authorsEmoji) ->
        total = authorsEmoji.length
        originals = authorsEmoji.filter((emoji) -> emoji.is_alias == 0).length
        request.send("Looks like #{author} has #{total} emoji, #{originals} originals and #{total - originals} aliases")

  robot.respond /(?:emojme )?who (?:all )?has (made|contributed|created|submitted) (?:an )?emoji\??/i, (request) ->
    util.require_cache request, (emojiList, lastUser, lastRefresh) ->
      authors = Array.from(new Set(emojiList.map((emoji) => emoji.user_display_name))).sort()
      request.send(authors.join(", "))

  robot.respond /(?:emojme )?commit this to the record (?:of|for) :(.*?):\s?: (.*)/i, (request) ->
    emoji_name = request.match[1].replace(/:/g, '')
    message = request.match[2].replace(/“|"|”/g, '')
    util.find_archive_entry emoji_name, (existing_entry) ->
      if existing_entry
        request.send("Overwriting previous interpretation of :#{emoji_name}:: #{existing_entry}")
    util.save_archive_entry emoji_name, message
    robot.adapter.client.web.reactions.add("gavel", {
      channel: request.message.user.room,
      timestamp: request.message.id
    })

  robot.respond /(?:emojme )?(?:delete|purge|clear|clean) the record (?:of|for) :(.*?):/i, (request) ->
    emoji_name = request.match[1].replace(/:/g, '')
    util.find_archive_entry emoji_name, (existing_entry) ->
      if existing_entry
        request.send("Deleting previous interpretation of :#{emoji_name}:: #{existing_entry}")
    delete_archive_entry emoji_name

  robot.respond /(?:emojme )?what does the (?:record|archive) (?:state|say) (?:about|for|of) :(.*?):\??/i, (request) ->
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

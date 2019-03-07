# Description:
#   A way to interact with emojme functions
#
# Commands:
#   hubot emojme how do - a little explainer on how to use emojme
#   hubot emojme status - print the age of the cache and who last updated it
#   hubot emojme refresh with my super secret user token that i will not post in any public channels: <token> - authenticate with user token if given
#   hubot emojme emoji me - give a random emoji
#   hubot emojme dump app emoji (with metadata)? - upload a list of emoji names, or emoji metadata if requested
#   hubot emojme tell me about :<emoji>: - give the provided emoji's metadata
#   hubot emojme who made :<emoji>: - give the provided emoji's author.
#   hubot emojme how many emoji has <author> made? - give the provided author's emoji statistics.
#   hubot emojme show me the emoji <author> made - give the provided author's emoji
#   hubot emojme commit this to the record of :<emoji>:: <message> - save an explanation for the given emoji
#   hubot emojme purge the record of :<emoji>: - delete all explanation for the given emoji
#   hubot emojme what does the record state about :<emoji>:? - read the emoji's explanation if it exists
#   hubot emojme what emoji are documented? - give the names of all documented emoji
#
# Author:
#   Jack Ellenberger <jellenberger@uchicago.edu>
emojme = require 'emojme'
slack = require 'slack'

module.exports = (robot) ->
  robot.respond /emojme how do/i, (context) ->
    context.send("""
Hey! [emojme](https://github.com/jackellenberger/emojme) is a project to mess with slack emoji.

In order to do anything with it here, you'll need to make sure that hubot knows about your emoji, which you can check on with `emojme status`.

If there is no emoji cache or it's out of date, create a DM with hubot and write the following command: ```
  emojme refresh with my super secret user token that i will not post in any public channels: <YOUR TOKEN>
```

<YOUR TOKEN> can be got from several places, and may update unexpectedly. [Find out how to find your token here](https://github.com/jackellenberger/emojme#finding-a-slack-token)
""")

  robot.respond /emojme status/i, (context) ->
    require_cache context, (emojiList, lastUser, lastRefresh) ->
      context.send("#{lastUser} last refreshed the emoji list back at #{lastRefresh} when there were #{emojiList.length} emoji")

  robot.respond /emojme refresh (.* )?with my super secret user token that i will not post in any public channels: ([0-9A-z-_]*)/i, (context) ->
    slack_instance = (context.match[1] || context.message.user.slack.team_id).trim()
    token = context.match[2].trim()
    if context.message.room[0] != 'D' # delete that message, keep tokens out of public chat
      slack.chat.delete({token: token, channel: context.message.room, ts: context.message.id})
      context.send("Don't go posting auth tokens in public channels ya dummy. Delete that or I'm telling mom.")
      return
    else # log in with the provided token
      context.send("Updating emoji database, this may take a few moments...")
      emojme.download(slack_instance, token, {})
        .then (adminList) =>
          robot.brain.set 'emojme.AuthUser', context.message.user.name
          robot.brain.set 'emojme.LastUpdatedAt', Date(Date.now()).toString()
          robot.brain.set 'emojme.AdminList', adminList[Object.keys(adminList)[0]].emojiList
          context.send("emoji database refresh complete. Probably oughta clean that token up tho.")
          slack.chat.delete({token: token, channel: context.message.room, ts: context.message.id})
            .catch (e) ->
              console.log(e)
              console.log("Unable to delete #{context.message.id} in channel #{context.message.room}")
        .catch (e) ->
          console.log(e)
          context.send("looks like something went wrong, is your token correct?")

  robot.respond /emojme (emoji me|(random( emoji)?))/i, (context) ->
    require_cache context, (emojiList, lastUser, lastRefresh) ->
      context.send(":#{emojiList[Math.floor(Math.random()*emojiList.length)].name}:")

  robot.respond /(?:emojme )?(?:list|dump) all (?:the )?emoji((?: with)? metadata)?/i, (context) ->
    require_cache context, (emojiList, lastUser, lastRefresh) ->
      # Give metadata if asked for, otherwise just emoji names
      content = JSON.stringify(context.match[1] ? emojiList : emojiList.map((emoji) -> emoji.name), null, 2)
      try
        robot.adapter.client.web.files.upload('adminList.txt', {
          content,
          channels: context.message.room,
          initial_comment: "Here are the emoji as of #{lastRefresh}"
        })
      catch
        context.send("I have like #{adminList.length} emoji but I'm having a hard time uploading them.")

  robot.respond /(?:emojme )?tell me about :(.*?):/i, (context) ->
    require_cache context, (emojiList, lastUser, lastRefresh) ->
      find_emoji context, emojiList, context.match[1].replace(/:/g,''), (emoji, _) ->
        find_archive_entry emoji.name, (archive_entry) ->
          emoji.archive_entry = archive_entry
        context.send("Ah, :#{emoji.name}:, I know it well...\n```#{JSON.stringify(emoji, null, 2)}```")

  robot.respond /(?:emojme )?who made (?:the )?:(.*?):(?: emoji)?\??/i, (context) ->
    require_cache context, (emojiList, lastUser, lastRefresh) ->
      find_emoji context, emojiList, context.match[1].replace(/:/g,''), (emoji, original) ->
        message = "That would be #{emoji.user_display_name}"
        if original
          message += ", but #{original.user_display_name} made the original, `:#{original.name}:`"
        context.send(message)

  robot.respond /(?:emojme )?how many emoji has (.*?) made\??/i, (context) ->
    require_cache context, (emojiList, lastUser, lastRefresh) ->
      author = context.match[1].trim()
      find_author context, emojiList, author, (authorsEmoji) ->
        total = authorsEmoji.length
        originals = authorsEmoji.filter((emoji) -> emoji.is_alias == 0).length
        context.send("Looks like #{author} has #{total} emoji, #{originals} originals and #{total - originals} aliases")

  robot.respond /(?:emojme )?show me (?:all )?the emoji (?:that )?(.*?) (?:has )?made/i, (context) ->
    require_cache context, (emojiList, lastUser, lastRefresh) ->
      author = context.match[1]
      find_author context, emojiList, author, (authorsEmoji) ->
        if authorsEmoji.length < 25
          context.send(authorsEmoji.map((emoji) -> ":#{emoji.name}:").join(" "))
        else
          try
            context.send("#{author} has like #{authorsEmoji.length} emoji, I'm gonna thread this")
            index = 0
            while index < authorsEmoji.length
              robot.adapter.client.web.chat.postMessage(
                context.message.user.room,
                authorsEmoji.slice(index, index+100).map((emoji) -> ":#{emoji.name}:").join(" "),
                {thread_ts: context.message.id}
              )
              index += 100
          catch
            context.send("Ahh I can't do it, something's wrong")

  robot.respond /(?:emojme )?commit this to the record (?:of|for) :(.*?):\s?: (.*?)/i, (context) ->
    emoji_name = context.match[1].replace(/:/g, '')
    message = context.match[2].replace(/“|"|”/g, '')
    find_archive_entry emoji_name, (existing_entry) ->
      if existing_entry
        context.send("Overwriting previous interpretation of :#{emoji_name}:: #{existing_entry}")
    save_archive_entry emoji_name, message
    robot.adapter.client.web.reactions.add("gavel", {
      channel: context.message.user.room,
      timestamp: context.message.id
    })

  robot.respond /(?:emojme )?(?:delete|purge|clear|clean) the record (?:of|for) :(.*?):/i, (context) ->
    emoji_name = context.match[1].replace(/:/g, '')
    find_archive_entry emoji_name, (existing_entry) ->
      if existing_entry
        context.send("Deleting previous interpretation of :#{emoji_name}:: #{existing_entry}")
    delete_archive_entry emoji_name, message

  robot.respond /(?:emojme )?what does the (?:record|archive) (?:state|say) (?:about|for|of) :(.*?):\??/i, (context) ->
    emoji_name = context.match[1].replace(/:/g, '')
    find_archive_entry emoji_name, (existing_entry) ->
      if existing_entry
        context.send("\"#{existing_entry}\"")
      else
        context.send("Nothing! https://i.kym-cdn.com/photos/images/original/000/721/333/5d1.gif")

  robot.respond /emojme (?:which|what|how many) emoji are documented\??/i, (context) ->
    emoji_archive = robot.brain.get "emojme.emojiArchive"
    emoji_archive ?= {}
    names = Object.keys(emoji_archive)
    emoji = if names.length == 0 then ":shrug:" else names.map((name) => ":#{name}: ")
    context.send("Looks like we got explanations for #{names.length} emoji #{emoji}")
    if names.length < 10
      context.send("Jimmy Wales says if we all wrote one emoji explanation we'd have a lot more explanations than this\nhttps://i.kym-cdn.com/entries/icons/original/000/004/510/Jimmeh.jpg")

  # Helpers
  require_cache = (context, action) ->
    if (
      (emojiList = robot.brain.get 'emojme.AdminList' ) &&
      (lastUser = robot.brain.get 'emojme.AuthUser' ) &&
      (lastRefresh = robot.brain.get 'emojme.LastUpdatedAt' )
    )
      action(emojiList, lastUser, lastRefresh)
    else
      context.send("Looks like there's no emoji cache, you'll have to refresh it. Ask me `emojme how do` for more info.")

  find_emoji = (context, emojiList, emojiName, action) ->
    if typeof emojiName != 'undefined' && (emoji = emojiList.find((emoji) -> emoji.name == emojiName))
      original_name = emoji.alias_for
      if original_name && (original_emoji = emojiList.find((emoji) -> emoji.name == original_name))
        action(emoji, original_emoji)
      else
        action(emoji)
    else
      context.send("I don't recognize :#{emojiName}:, if it exists, my cache might need a refresh. Call `emojme how do` to find out how")

  find_author = (context, emojiList, authorName, action) ->
    if authorsEmoji = emojiList.filter((emoji) -> emoji.user_display_name == authorName)
      if authorsEmoji.length > 0
        action(authorsEmoji)
      else
        context.send("Okay I know #{authorName}, we all know em, they're good people, but they don't have any emoji. No excuse for that.")
    else
      context.send("""
I don't know \"#{authorName}\", is that still their name on Slack?
If they have a new display name, maybe refresh the cache? Call `emojme how do` to find out how.
""")

  find_archive_entry = (emoji_name, action) ->
    emoji_archive = robot.brain.get "emojme.emojiArchive"
    emoji_archive ?= {}
    action(emoji_archive[emoji_name])

  save_archive_entry = (emoji_name, message, action) ->
    emoji_archive = robot.brain.get "emojme.emojiArchive"
    emoji_archive ?= {}
    emoji_archive[emoji_name] = message
    robot.brain.set "emojme.emojiArchive", emoji_archive

  delete_archive_entry = (emoji_name, message, action) ->
    emoji_archive = robot.brain.get "emojme.emojiArchive"
    emoji_archive ?= {}
    delete emoji_archive[emoji_name]
    robot.brain.set "emojme.emojiArchive", emoji_archive


  # hubot emojme :gavel: <emoji> <link to message> - save the provided message to emoji's record
  # # Requires find_message, which isn't workable with a bot token
  # robot.respond /emojme :gavel: (.*) https:\/\/(?:.*).slack.com\/archives\/(.*)\/p([0-9]{16})/i, (context) ->
  #   emoji_name = context.match[1].replace(/:/g, '')
  #   channel = context.match[2]
  #   timestamp = context.match[3]
  #   find_message context, channel, timestamp, (message) ->
  #     context.send("Got it, saving #{emoji_name} to the archive with \"#{message.text}\"")
  #     # TODO: actually save this
  #     robot.adapter.client.web.reactions.add("gavel", {
  #       channel,
  #       timestamp
  #     })

  # # Not currently possible with bot tokens :(
  # find_message = (context, channel, ts, action) ->
  #   robot.adapter.client.web.channels.history(channel, {
  #     count: 1,
  #     inclusive: true,
  #     latest: ts
  #   })
  #     .then (result, err) =>
  #       action(result.messages[0])
  #     .catch (e) ->
  #       console.log(JSON.stringify(e, null, 2))
  #       context.send("Unable to find that message. Maybe try specifying that info nugget explicity?")

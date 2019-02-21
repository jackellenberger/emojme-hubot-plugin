# Description:
#   A way to interact with emojme functions
#
# Commands:
#   hubot emojme how do - a little explainer on how to use emojme
#   hubot emojme status - print the age of the cache and who last updated it
#   hubot emojme refresh with my super secret user token that i will not post in any public channels: <token> - authenticate with user token if given
#   hubot emojme list emoji (metadata)? - upload a list of emoji names, or emoji metadata if requested
#   hubot emojme who made <emoji> - give the provided emoji's author.
#   hubot emojme tell me about <emoji> - give the provided emoji's metadata
#   hubot emojme how many emoji has <author> made? - give the provided author's emoji statistics.
#   hubot emojme show me the emoji <author> made - give the provided author's emoji
#
# Author:
#   Jack Ellenberger <jellenberger@uchicago.edu>
slack = require 'slack'
emojme = require 'emojme'

module.exports = (robot) ->
  robot.respond /emojme how do/, (context) ->
    context.send("""
Hey! [emojme](https://github.com/jackellenberger/emojme) is a project to mess with slack emoji.
In order to do anything with it here, you'll need to make sure that hubot knows about your emoji, which you can check on with `emojme status`.
If there is no emoji cache or it's out of date, create a DM with hubot and write the following command: ```
  emojme refresh with my super secret user token that i will not post in any public channels: <YOUR TOKEN>
```
<YOUR TOKEN> can be got from several places, and may update unexpectedly. [Find out how to find your token here](https://github.com/jackellenberger/emojme#finding-a-slack-token)
""")

  robot.respond /emojme status/, (context) ->
    require_cache context, (emojiList, lastUser, lastRefresh) ->
      context.send("#{lastUser} last refreshed the emoji list back at #{lastRefresh} when there were #{emojiList.length} emoji")

  robot.respond /emojme refresh (.*)with my super secret user token that i will not post in any public channels: (.*)/, (context) ->
    slack_instance = context.match[1] || context.message.user.slack.team_id
    token = context.match[2]
    if context.message.room[0] != 'D' # delete that message, keep tokens out of public chat
      slack.chat.delete({token: token, channel: context.message.room, ts: context.message.id})
      context.send("Don't go posting auth tokens in public channels ya dummy")
      return
    else # log in with the provided token
      context.send("Updating emoji database, this may take a few moments...")
      emojme.download(slack_instance, token, {})
        .then (adminList) =>
          robot.brain.set 'emojmeAuthUser', context.message.user.name
          robot.brain.set 'emojmeLastUpdatedAt', Date(Date.now()).toString()
          robot.brain.set 'emojmeAuthToken', token
          robot.brain.set 'emojmeAdminList', adminList[Object.keys(adminList)[0]].emojiList
          context.send("emoji database refresh complete.")
        .catch (e) ->
          console.log(e)
          context.send("looks like something went wrong, is your token correct?")

  robot.respond /emojme list emoji\s*(metadata)?/, (context) ->
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

  robot.respond /emojme who made (.*)/, (context) ->
    require_cache context, (emojiList, lastUser, lastRefresh) ->
      find_emoji context, emojiList, context.match[1].replace(/:/g,''), (emoji) ->
        context.send("That would be #{emoji.user_display_name}")

  robot.respond /emojme tell me about (.*)/, (context) ->
    require_cache context, (emojiList, lastUser, lastRefresh) ->
      find_emoji context, emojiList, context.match[1].replace(/:/g,''), (emoji) ->
        context.send("Ah, :#{emoji.name}:, I know it well...\n```#{JSON.stringify(emoji, null, 2)}```")

  robot.respond /emojme how many emoji has (.*) made?/, (context) ->
    require_cache context, (emojiList, lastUser, lastRefresh) ->
      author = context.match[1]
      find_author context, emojiList, author, (authorsEmoji) ->
        total = authorsEmoji.length
        originals = authorsEmoji.filter((emoji) -> emoji.is_alias == 0).length
        context.send("Looks like #{author} has #{total} emoji, #{originals} originals and #{total - originals} aliases")

  robot.respond /emojme show me the emoji (.*) made/, (context) ->
    require_cache context, (emojiList, lastUser, lastRefresh) ->
      author = context.match[1]
      find_author context, emojiList, author, (authorsEmoji) ->
        if authorsEmoji.length > 25
          context.send(authorsEmoji.map((emoji) -> ":#{emoji.name}:").join(" "))
        else
          try
            response = robot.adapter.client.web.chat.postMessage(
              context.message.user.room,
              context.send("#{author} has like #{authorsEmoji.length} emoji, I'm gonna thread this")
            )
            index = 0
            while index < authorsEmoji.length
              robot.adapter.client.web.chat.postMessage(
                context.message.user.room,
                authorsEmoji.slice(index, index+100).map((emoji) -> ":#{emoji.name}:").join(" "),
                {thread_ts: response.message.id}
              )
              index += 100
          catch
            context.send("Ahh I can't do it, something's wrong")

  # Helpers
  require_cache = (context, action) ->
    if (
      (emojiList = robot.brain.get 'emojmeAdminList' ) &&
      (lastUser = robot.brain.get 'emojmeAuthUser' ) &&
      (lastRefresh = robot.brain.get 'emojmeLastUpdatedAt' )
    )
      action(emojiList, lastUser, lastRefresh)
    else
      context.send("Looks like there's no emoji cache, you'll have to refresh it. Ask me `emojme how do` for more info.")

  find_emoji = (context, emojiList, emojiName, action) ->
    if typeof emojiName != 'undefined' && (emoji = emojiList.find((emoji) -> emoji.name == emojiName))
      action(emoji)
    else
      context.send("I don't recognize :#{emojiName}:, if it exists, my cache might need a refresh. Call `emojme how do` to find out how")

  find_author = (context, emojiList, authorName, action) ->
    if authorsEmoji = emojiList.filter((emoji) -> emoji.user_display_name == authorName)
      action(authorsEmoji)
    else
      context.send("""
I don't know \"#{authorName}\", is that still their name on Slack?
If they have a new display name,
""")



# Description:
#   An old way to interact with emojme functions
#
# Commands:
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

  robot.respond /emojme refresh (.* )?with my super secret user token that i will not post in any public channels: ([0-9A-z-_]*)/i, (context) ->
    slack_instance = (context.match[1] || context.message.user.slack.team_id).trim()
    token = context.match[2].trim()
    if context.message.room[0] == 'C' # delete that message, keep tokens out of public chat
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

  # robot.respond /emojme (?:show me|what is|what are) my (?:(\d*) )?(?:favorite|most used) emoji\??)/i, (request) ->

  # hubot emojme :gavel: <emoji> <link to message> - save the provided message to emoji's record
  # # Requires find_message, which isn't workable with a bot token
  # robot.respond /emojme :gavel: (.*) https:\/\/(?:.*).slack.com\/archives\/(.*)\/p([0-9]{16})/i, (request) ->
  #   emoji_name = request.match[1].replace(/:/g, '')
  #   channel = request.match[2]
  #   timestamp = request.match[3]
  #   find_message request, channel, timestamp, (message) ->
  #     request.send("Got it, saving #{emoji_name} to the archive with \"#{message.text}\"")
  #     # TODO: actually save this
  #     robot.adapter.client.web.reactions.add("gavel", {
  #       channel,
  #       timestamp
  #     })

  # # Not currently possible with bot tokens :(
  # find_message = (request, channel, ts, action) ->
  #   robot.adapter.client.web.channels.history(channel, {
  #     count: 1,
  #     inclusive: true,
  #     latest: ts
  #   })
  #     .then (result, err) =>
  #       action(result.messages[0])
  #     .catch (e) ->
  #       console.log(JSON.stringify(e, null, 2))
  #       request.send("Unable to find that message. Maybe try specifying that info nugget explicity?")

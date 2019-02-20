# Description:
#   A way to interact with emojme functions
#
# Commands:
#   hubot emojme (authenticate|log in|refresh) <user token?> - authenticate with user token if given, otherwise print who is logged in and how long they have been logged for.
#   hubot emojme list emoji (metadata)? - upload a list of emoji names, or emoji metadata if requested
#   hubot emojme who made <emoji> - give the provided emoji's author.
#   hubot emojme tell me about <emoji> - give the provided emoji's metadata
#   hubot emojme how many emoji has <author> made? - give the provided author's emoji statistics.
#
# Author:
#   Jack Ellenberger <jellenberger@uchicago.edu>
slack = require 'slack'
emojme = require 'emojme'

module.exports = (robot) ->
  robot.respond /emojme (?:authenticate|log in|refresh)\s*(.*)?/, (context) ->
    token = context.match[1]
    isPrivate = context.message.user.name == context.message.room
    if token
      if !isPrivate # delete that message, keep tokens out of public chat
        slack.chat.delete({token: token, channel: context.message.room, ts: context.message.id})
        context.send("Don't go posting auth tokens in public channels now, ya hear?")
        return
      else # log in with the provided token
        context.send("Updating emoji database, this may take a few moments...")
        downloadOptions = {output: true}
        emojme.download(process.env.HUBOT_SLACK_TEAM, token, downloadOptions)
          .then (adminList) =>
            robot.brain.set 'emojmeAuthUser', context.message.user.name
            robot.brain.set 'emojmeLastUpdatedAt', Date(Date.now()).toString()
            robot.brain.set 'emojmeAuthToken', token
            robot.brain.set 'emojmeAdminList', adminList[process.env.HUBOT_SLACK_TEAM].emojiList
            context.send("emoji database refresh complete.")
          .catch (e) ->
            console.log(e)
            context.send("looks like something went wrong, is your token correct?")
    else
      context.send("#{robot.brain.get('emojmeAuthUser')} last refreshed the emoji list back at #{robot.brain.get('emojmeLastUpdatedAt')}")


  robot.respond /emojme list emoji\s*(metadata)?/, (context) ->
    if adminList = robot.brain.get 'emojmeAdminList'
      if context.match[1]
        content = JSON.stringify(adminList, null, 2)
      else
        content = JSON.stringify(adminList.map((emoji) -> emoji.name), null, 2)

      opts = {
        content,
        channels: context.message.room,
        initial_comment: "Here are the emoji as of #{robot.brain.get('emojmeLastUpdatedAt')}"
      }
      try
        robot.adapter.client.web.files.upload('adminList.txt', opts)
      catch
        context.send("I have like #{adminList.length} emoji but I'm having a hard time uploading them.")
    else
      context.send("Looks like we don't have anything cached, try re authenticating with emojme refresh <token> in a DM with me")


  robot.respond /emojme who made (.*)/, (context) ->
    if (adminList = robot.brain.get 'emojmeAdminList') && (emojiName = context.match[1])
      if emoji = adminList.find((emoji) -> emoji.name == emojiName)
        context.send("That would be one #{emoji.user_display_name}")
      else
        context.send("I don't know about that emoji, is it real? If it's just new, try re authenticating with emojme refresh <token> in a DM with me")
    else
      context.send("Looks like we don't have anything cached, try re authenticating with emojme refresh <token> in a DM with me")

  robot.respond /emojme tell me about (.*)/, (context) ->
    if (adminList = robot.brain.get 'emojmeAdminList') && (emojiName = context.match[1])
      if emoji = adminList.find((emoji) -> emoji.name == emojiName)
        context.send("Ah, :#{emoji.name}:, I know it well...\n```#{JSON.stringify(emoji, null, 2)}```")
      else
        context.send("I don't know about that emoji, is it real? If it's just new, try re authenticating with emojme refresh <token> in a DM with me")
    else
      context.send("Looks like we don't have anything cached, try re authenticating with emojme refresh <token> in a DM with me")


  robot.respond /emojme how many emoji has (.*) made?/, (context) ->
    if (adminList = robot.brain.get 'emojmeAdminList') && (author = context.match[1])
      if emojiList = adminList.filter((emoji) -> emoji.user_display_name == author)
        originals = emojiList.filter((emoji) -> emoji.is_alias == 0).length
        total = emojiList.length
        context.send("Looks like #{author} has #{total} emoji, #{originals} originals and #{total - originals} aliases")
      else
        context.send("I don't know about that author, are they real? If they have a new display name, try re authenticating with emojme refresh <token> in a DM with me")
    else
      context.send("Looks like we don't have anything cached, try re authenticating with emojme refresh <token> in a DM with me")

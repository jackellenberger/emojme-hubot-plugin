# Description:
#   A way to interact with emojme functions
#
# Commands:
#   hubot emojme (authenticate|log in|refresh) <user token?> - authenticate with user token if given, otherwise print who is logged in and how long they have been logged for.
#   hubot emojme who made <emoji> - give the provided emoji's author.
#   hubot emojme how many emoji has <author> made? - give the provided author's emoji statistics.
#   hubot emojme top <n?> authors - give the top n emoji authors. default n = 10.
#
# Author:
#   Jack Ellenberger <jellenberger@uchicago.edu>
slack = require 'slack'
emojme = require 'emojme'

module.exports = (robot) ->
  robot.respond /emojme (?:authenticate|log in|refresh)\s*(.*)/, (context) ->
    token = context.match[1]
    isPrivate = context.message.user.name == context.message.room
    if token
      if !isPrivate # delete that message, keep tokens out of public chat
        slack.chat.delete({token: token, channel: context.message.room, ts: context.message.id})
        return context.send("Don't go posting auth tokens in public channels now, ya hear?")
      else # log in with the provided token
        context.send("Logging you in")
        # TODO Save token, username, timestamp to brain
        # TODO download adminlist to brain
    else
      # TODO user, timestamp = brain.getEmojmeAuth
      context.send("#{user} last refreshed the emoji list back at #{timestamp}")

  robot.respond /emojme who made (.*)/, (emojiName) ->
    console.log(emojiName)

  robot.respond /emojme how many emoji has (.*) made?/, (author) ->
    console.log(author)

  robot.respond /emojme top ([0-9]*) authors/, (topN) ->
    console.log(topN)

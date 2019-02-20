# Description:
#   A way to interact with emojme functions
#
# Commands:
#   hubot emojme authenticat(e|ion) <user token?> - authenticate with user token if given, otherwise print who is logged in and how long they have been logged for.
#   hubot emojme who made <emoji> - give the provided emoji's author.
#   hubot emojme how many emoji has <author> made? - give the provided author's emoji statistics.
#   hubot emojme top <n?> authors - give the top n emoji authors. default n = 10.
#
# Author:
#   Jack Ellenberger <jellenberger@uchicago.edu>

module.exports = (robot) ->
  robot.respond /emojme ping/, () ->
    console.log("pong")

  robot.respond /emojme authenticat(?:e|ion)\s*(.*)/, (maybeToken) ->
    console.log(maybeToken)

  robot.respond /emojme who made (.*)/, (emojiName) ->
    console.log(emojiName)

  robot.respond /emojme how many emoji has (.*) made?/, (author) ->
    console.log(author)

  robot.respond /emojme top ([0-9]*) authors/, (topN) ->
    console.log(topN)

Helper = require('hubot-test-helper')
helper = new Helper('../src')

expect = require('chai').expect
co = require('co')

room = null

context 'hubot', ->
  beforeEach ->
    room = helper.createRoom({httpd: false})
  afterEach ->
    room.destroy()

  describe 'how do', ->
    beforeEach ->
      return co () ->
        yield room.user.say('alice', '@hubot emojme how do')

    it 'returns instructions', ->
      expect(room.messages[0][0]).to.eql('alice')
      expect(room.messages[1][0]).to.eql('hubot')
      expect(room.messages[1][1]).to.contain('Hey!')

  describe 'status', ->
    context 'there is no emoji cache', ->
      beforeEach ->
        return co () ->
          yield room.user.say('alice', '@hubot emojme status')

      it 'states there is no emoji cache', ->
        expect(room.messages[1][1]).to.contain(
          'Looks like there\'s no emoji cache'
        )

    context 'there is an emoji cache', ->
      beforeEach ->
        return co () ->
          room.robot.brain.data._private = {
            'emojme.AdminList': [{name: 'emoji-1'}],
            'emojme.AuthUser': 'tester',
            'emojme.LastUpdatedAt': '12:00'
          }
          yield room.user.say('alice', '@hubot emojme status')

      it 'returns a message including the name, timestamp, and emojicount', ->
        expect(room.messages[1][1]).not.to.contain(
          'Looks like there\'s no emoji cache'
        )

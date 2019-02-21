# emojme-hubot-plugin

A hubot script to call [emojme](https://github.com/jackellenberger/emojme) plugins from slack

## Commands

* hubot emojme how do
    * print how to use emojme and how to get a user token
    * ```
Hey! [emojme](https://github.com/jackellenberger/emojme) is a project to mess with slack emoji.
In order to do anything with it here, you'll need to make sure that hubot knows about your emoji, which you can check on with `emojme status`.
If there is no emoji cache or it's out of date, create a DM with hubot and write the following command:
  `emojme refresh with my super secret user token that i will not post in any public channels: <YOUR TOKEN>`
      ```

<YOUR TOKEN> can be got from several places, and may update unexpectedly. [Find out how to find your token here](https://github.com/jackellenberger/emojme#finding-a-slack-token)
* hubot emojme status
    * print the age of the cache and who last updated it
    * `<user> last refreshed the emoji list back at <date> when there were <emoji count> emoji`

* hubot refresh with my super secret user token that i will not post in any public channels <token>
    * authenticate with user token if given (only works in private DMs)
    * `Updating emoji database, this may take a few moments...` ... `emoji database refresh complete`

* hubot emojme list emoji (metadata)?
    * upload a list of emoji names, or emoji metadata if requested
    * `here are all emoji as of <date>` `file attachment`

* hubot emojme who made <emoji>
    * give the provided emoji's author.
    * `That would be <author>`

* hubot emojme tell me about <emoji>
    * give the provided emoji's metadata
    * `Ah, :<emoji>:, i know it well` `{ emoji metadata }`

* hubot emojme how many emoji has <author> made?
    * give the provided author's emoji statistics.
    * `looks like <author> has <total> emoji, <original> originals, and <aliases> aliases`

* hubot emojme show me the emoji <author> made
    * give the provided author's emoji, either in a message (if count < 25) or in a thread (if count > 25)
    * `:emoji1: :emoji2: ...`

## Installation

In hubot project repo, run:

`npm install emojme-hubot-plugin --save`

Then add **emojme-hubot-plugin** to your `external-scripts.json`:

```json
[
  "emojme-hubot-plugin"
]
```

# Testing

```sh
nvm use 10 && npm install
npm link
cd ../your-hubot-core
npm link emojme-hubot-plugin
./bin/hubot-test # or whatever your startup command is
```

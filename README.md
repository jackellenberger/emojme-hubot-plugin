# emojme-hubot-plugin

A hubot script to call [emojme](https://github.com/jackellenberger/emojme) plugins from slack

## Commands

* hubot emojme [00] help - print help message
  * ```
    Hey there! emojme is an project made to interface with the dark parts of slack's api: the emoji endpoints.

    In order to do anything with it here, you'll need to make sure that hubot knows about your list of emoji, which you can check on with `emojme status`.

    If there is no emoji cache or it's out of date, you can fix that with `@hubot emojme refresh`, that'll lead you by the hand to getting a user token and updating the list of emoji that I know about. There will be a 60 second time window to enter your token, so get a head start by checking out the docs [on the emojme repo](https://github.com/jackellenberger/emojme#finding-a-slack-token)

    Questions, comments, concerns? Ask em either on emojme, or on [this project](https://github.com/jackellenberger/emojme-hubot-plugin), whatever's relevant.
    ```
* hubot emojme [01] refresh (with <subdomain>:<token>) - authenticate and grab list of emoji, enabling all other commands. If subdomain and token are not provided up front they will be asked for. Do not post tokens in public channels.

* hubot emojme [02] status - print the age of the cache and who last updated it

* hubot emojme [03] random - give a random emoji

* hubot emojme [04] N random - give N random emoji

* hubot emojme [05] random emoji by <user> - give a random emoji made by <user>

* hubot emojme [06] tell me about :<emoji>: - give the provided emoji's metadata

* hubot emojme [07] when was :<emoji>: made - give the provided emoji's creation date, if available.

* hubot emojme [08] enhance :<emoji>: - give the provided emoji's source image at highest availalbe resolution

* hubot emojme [09] how many emoji has <author> made? - give the provided author's emoji statistics.

* hubot emojme [10] who made :<emoji>: - give the provided emoji's author.

* hubot emojme [11] show me the emoji <author> made - give the provided author's emoji

* hubot emojme [12] who all has made an emoji? - list all emoji authors

* hubot emojme [13] show me my <10> most used emoji - give the usage counts of the emoji you use to +react most often

* hubot emojme [14] show me all the new emoji since <some NLP interpretable day> - show all the emoji created since 'yesterday', 'three days ago', 'last week', etc.

* hubot emojme [15] dump all emoji (with metadata)? - upload a list of emoji names, or emoji metadata if requestek

* hubot emojme [16] commit this to the record of :<emoji>:: <message> - save an explanation for the given emoji

* hubot emojme [17] purge the record of :<emoji>: - delete all explanation for the given emoji

* hubot emojme [18] what does the record state about :<emoji>:? - read the emoji's explanation if it exists

* hubot emojme [19] what emoji are documented? - give the names of all documented emoji

* hubot emojme [20] alias :<existing>: to :<new-alias>: - create a new emoji directly from slack sort of

* hubot emojme [21] forget my login - delete cached user token. If not touched a login expires in 24 hours

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

# emojme-hubot-plugin

A hubot script to call [emojme](https://github.com/jackellenberger/emojme) plugins from slack

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

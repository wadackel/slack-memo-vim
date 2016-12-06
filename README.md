slack-memo.vim
==============

Simple memo manager with Vim using Slack.


## Screenshots

![Screenshot](https://raw.githubusercontent.com/tsuyoshiwada/slack-memo-vim/images/screenshot.gif)


## Usage

Post a memo on Slack.

```vim
:SlackMemoPost
```

List memos on Slack.

```vim
:SlackMemoList
```

List memos on Slack with CtrlP.

```vim
:SlackMemoCtrlP
```


### Keymaps in the memo list

The following keymaps are available in the buffer of the memo list. It does not work with CtrlP.

| key            | description             |
|:---------------|:------------------------|
| `Enter` or `o` | Open memo on cursor.    |
| `Esc` or `q`   | Close memo list window. |
| `d`            | Delete memo on cursor.  |
| `y`            | Yank memo on cursor.    |
| `r`            | Update list window.     |

You can udpate it by saving memo opened in buffer.


## Install

It's easy to install using plugin manager.  
Depending on your plugin manager, please add the following to `.vimrc`.

### Install with [dein](https://github.com/Shougo/dein.vim)

```vim
call dein#add('tsuyoshiwada/slack-memo-vim', {'depends': 'mattn/webapi-vim'})
```

### Install with [NeoBundle](https://github.com/Shougo/neobundle.vim)

```vim
NeoBundle 'tsuyoshiwada/slack-memo-vim', {'depends': 'mattn/webapi-vim'}
```



## Requirements

* `curl` command.
* [mattn/webapi-vim](https://github.com/mattn/webapi-vim).



## Setup

You need a token to use [Slack Web API](https://api.slack.com/web).  
Please set your token on `g:slack_memo_token`. and set channel Id in `g:slack_memo_channel`.

```vim
let g:slack_memo_token = '<YOUR_TOKEN>'
let g:slack_memo_channel = '<YOUR_MEMO_CHANNEL_ID>'
```

If you do not know the Id right away, you can easily check with the [channel.list](https://api.slack.com/methods/channels.list/test) tester.

Setup is complete!



## Tips

### Example keymap

You can post / list easily with the following keymap.

```vim
nnoremap smp :SlackMemoPost<CR>
nnoremap sml :SlackMemoList<CR>
```

### GFM TODO list

Support GFM TODO list. Posting following memo will be displayed with emoji on Slack.

```markdown
* [x] Done1
* [x] Done2
* [ ] TODO...
```



## Contributing

### Reporting issue

* [Welcome issue!](https://github.com/tsuyoshiwada/slack-memo-vim/issues)

### Contributing to code

* Fork it.
* Commit your changes and give your commit message.
* Push to your fork on GitHub.
* Open a Pull Request.


## Credit

* [Slack](https://slack.com/).
* Inspired by [gist-vim](https://github.com/mattn/gist-vim).



## License

See the [LICENSE](https://raw.githubusercontent.com/tsuyoshiwada/slack-memo-vim/master/LICENSE).



## TODO

* [x] Support [CtrlP](https://github.com/ctrlpvim/ctrlp.vim).
* [ ] Support vertical split list window.
* [ ] List more than 1000 memos.


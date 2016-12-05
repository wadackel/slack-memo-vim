"=============================================================================
" File: slack-memo.vim
" Version: 0.0.2
" Author: tsuyoshiwada
" WebPage: http://github.com/tsuyoshiwada/slack-memo-vim
" License: BSD

if &compatible || (exists('g:loaded_slackmemo_vim') && g:loaded_slackmemo_vim)
  finish
endif
let g:loaded_slackmemo_vim = 1

command! -nargs=0 SlackMemoPost :call slackmemo#post()
command! -nargs=0 SlackMemoList :call slackmemo#list()

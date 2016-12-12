"=============================================================================
" File: slack-memo.vim
" Version: 0.2.0
" Author: tsuyoshiwada
" WebPage: http://github.com/tsuyoshiwada/slack-memo-vim
" License: BSD

if &compatible || (exists('g:loaded_slackmemo_vim') && g:loaded_slackmemo_vim)
  finish
endif
let g:loaded_slackmemo_vim = 1

command! -nargs=0 SlackMemoPost :call slackmemo#post()
command! -nargs=0 SlackMemoList :call slackmemo#list('default')
command! -nargs=0 SlackMemoCtrlP :call slackmemo#list('CtrlP')
command! -nargs=* SlackMemoSearch :call slackmemo#search('default', <f-args>)

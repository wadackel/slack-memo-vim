"=============================================================================
" File: slack-memo.vim
" Version: 0.1.2
" Author: tsuyoshiwada
" WebPage: http://github.com/tsuyoshiwada/slack-memo-vim
" License: BSD

if exists('g:loaded_ctrlp_slackmemo') && g:loaded_ctrlp_slackmemo
  finish
endif
let g:loaded_ctrlp_slackmemo = 1


let s:slackmemo_var = {
      \ 'init': 'ctrlp#slackmemo#init()',
      \ 'accept': 'ctrlp#slackmemo#accept',
      \ 'exit': 'ctrlp#slackmemo#exit()',
      \ 'lname': 'slackmemo',
      \ 'sname': 'slackmemo',
      \ 'type': 'path',
      \ 'sort': 0
      \ }

if exists('g:ctrlp_ext_vars') && !empty(g:ctrlp_ext_vars)
  let g:ctrlp_ext_vars = add(g:ctrlp_ext_vars, s:slackmemo_var)
else
  let g:ctrlp_ext_vars = [s:slackmemo_var]
endif


function! s:format_memo(memo) abort
  let ts = a:memo.ts
  let datetime = strftime("%Y-%m-%d", substitute(ts, '^\(\d\+\)\.\d\+$', '\1', 'g'))
  let title = split(a:memo.text, '\n')[0]
  let title = substitute(title, '  ', ' ', 'g')
  return printf('[%s](%s): %s', ts, datetime, title)
endfunction


function! ctrlp#slackmemo#init()
  let res = slackmemo#fetch()
  if !res.ok
    return ""
  endif

  let s:list = res.messages
  let s:messages = map(deepcopy(s:list), 's:format_memo(v:val)')
  return s:messages
endfunction


function! ctrlp#slackmemo#accept(mode, str)
  let ts = matchlist(filter(deepcopy(s:messages), 'v:val ==# a:str')[0], '^\[\(\d\+\.\d\+\)\]')[1]
  let memo = filter(deepcopy(s:list), 'slackmemo#compareMemoWithTS(v:val, "'.slackmemo#escapeTS(ts).'", 0)')[0]

  call ctrlp#exit()
  redraw!
  call slackmemo#open(memo)
endfunction


function! ctrlp#slackmemo#exit()
  if exists('s:list')
    unlet! s:list
  endif

  if exists('s:messages')
    unlet! s:messages
  endif
endfunction


let s:id = g:ctrlp_builtins + len(g:ctrlp_ext_vars)
function! ctrlp#slackmemo#id()
  return s:id
endfunction

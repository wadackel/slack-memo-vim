"=============================================================================
" File: slack-memo.vim
" Version: 0.2.1
" Author: tsuyoshiwada
" WebPage: http://github.com/tsuyoshiwada/slack-memo-vim
" License: BSD

let s:save_cpo = &cpoptions
set cpoptions&vim


if !executable('curl')
  echohl ErrorMsg | echomsg 'SlackMemo: require ''curl'' command' | echohl None
  finish
endif


if globpath(&rtp, 'autoload/webapi/http.vim') ==# ''
  echohl ErrorMsg | echomsg 'SlackMemo: require ''webapi'', install https://github.com/mattn/webapi-vim' | echohl None
  finish
else
  call webapi#json#true()
endif


if !exists('g:slack_memo_token')
  echohl ErrorMsg | echomsg 'SlackMemo: You have not configured a token. Read '':help slack-memo-setup''.' | echohl None
  finish
endif


if !exists('g:slack_memo_channel')
  echohl ErrorMsg | echomsg 'SlackMemo: You have not configured a channel id. Read '':help slack-memo-setup''.' | echohl None
  finish
endif


function! s:setGlobalOptDefault(opt, val)
  if !exists('g:' . a:opt)
    let g:{a:opt} = a:val
  endif
endfunction

call s:setGlobalOptDefault('slack_memo_bot_username', 'Vim (bot)')
call s:setGlobalOptDefault('slack_memo_bot_icon_url', '')
call s:setGlobalOptDefault('slack_memo_bot_icon_emoji', '')
call s:setGlobalOptDefault('slack_memo_list_count', 1000)


let s:bufprefix = 'slackmemo' . (has('unix') ? ':' : '_')
let s:listbufname = s:bufprefix.'-list'
let s:slackapi = 'https://slack.com/api'


" Utilities
function! s:format_memo(memo) abort
  let ts = a:memo.ts
  let datetime = strftime("%Y-%m-%d %H:%M:%S", substitute(ts, '^\(\d\+\)\.\d\+$', '\1', 'g'))
  let title = split(a:memo.text, '\n')[0]
  let title = substitute(title, '  ', ' ', 'g')
  return printf('memo: %s [%s]  %s', ts, datetime, title)
endfunction


function! slackmemo#compareMemoWithTS(memo, ts, cond)
  return a:cond == 0 ? a:memo.ts == a:ts : a:memo.ts != a:ts
endfunction


function! s:decode_memo_text(text)
  let text = a:text
  let text = join(map(split(text, "\n"), 's:encode_memo_line(v:val)'), "\n")
  return text
endfunction

function! s:encode_memo_line(line)
  let line = a:line

  " GFM - Checkbox
  if match(line, '[\*\-] \[ \]') > -1
    let line = substitute(line, '\([\*\-]\) \[ \]', '\1 :white_large_square: ', '')
  elseif match(line, '[\*\-] \[x\]') > -1
    let line = substitute(line, '\([\*\-]\) \[x\]', '\1 :ballot_box_with_check: ', '')
  endif

  return line
endfunction


function! s:decode_memo_line(line)
  let line = a:line

  " GFM - Checkbox
  if match(line, '[\*\-] :white_large_square: ') > -1
    let line = substitute(line, '\([\*\-]\) :white_large_square: ', '\1 [ ]', '')
  elseif match(line, '[\*\-] :ballot_box_with_check: ') > -1
    let line = substitute(line, '\([\*\-]\) :ballot_box_with_check: ', '\1 [x]', '')
  endif

  " URL
  if match(line, '<https\?:\/\/\S\+>') > -1
    let line = substitute(line, '<\(https\?:\/\/\S\+\)>', '\1', 'g')
  endif

  return line
endfunction


" SlackMemo
function! slackmemo#escapeTS(ts)
  return substitute(a:ts, '\.', '\\.', 'g')
endfunction


function! slackmemo#decodeMemo(memo)
  let text = webapi#html#decodeEntityReference(a:memo.text)
  let text = join(map(split(text, "\n"), 's:decode_memo_line(v:val)'), "\n")
  let a:memo.text = text
  return a:memo
endfunction


function! slackmemo#fetch() abort
  let res = webapi#http#get(s:slackapi . '/conversations.history', {
        \ 'token': g:slack_memo_token,
        \ 'channel': g:slack_memo_channel,
        \ 'count': g:slack_memo_list_count
        \ })
  let res = webapi#json#decode(res.content)

  if res.ok
    let messages = map(copy(res.messages), 'slackmemo#decodeMemo(v:val)')
    let messages = filter(res.messages, '!empty(v:val.text)')
    let res.messages = messages
  endif

  return res
endfunction


function! slackmemo#list(mode) abort
  redraw | echon 'Listing slack memo... '

  let res = slackmemo#fetch()

  if !res.ok
    redraw | echon 'Bad request...'
    return
  endif

  if a:mode == "CtrlP"
    if globpath(&rtp, 'autoload/ctrlp.vim') ==# ''
        echohl ErrorMsg | echomsg 'SlackMemo: require ''CtrlP'', install https://github.com/ctrlpvim/ctrlp.vim' | echohl None
      return
    endif
    call ctrlp#init(ctrlp#slackmemo#id())

  else
    call s:SlackMemoListOpen()
    let oldpos = getpos('.')
    let b:messages = res.messages
    call s:SlackMemoListRender()
    call cursor(oldpos[1], oldpos[2])
  endif
endfunction


function! slackmemo#search(mode, ...) abort
  let query = join(a:000, ' ')
  let res = slackmemo#chnnel_name()

  if !res.ok
    redraw | echon 'Invalid channel id...'
    return
  endif

  let res = slackmemo#search_messages(res.channel.name, query)
  call s:SlackMemoListOpen()
  let oldpos = getpos('.')
  let b:messages = slackmemo#matches2memos(res.messages.matches)
  call s:SlackMemoListRender()
  call cursor(oldpos[1], oldpos[2])
endfunction


function! slackmemo#search_messages(channel_name, query) abort
  let query = 'in:' . a:channel_name . ' ' . a:query

  let res = webapi#http#get(s:slackapi . '/search.messages', {
        \ 'token': g:slack_memo_token,
        \ 'query': query,
        \ 'count': g:slack_memo_list_count
        \ })
  let res = webapi#json#decode(res.content)

  if res.ok
    let matches = map(copy(res.messages.matches), 'slackmemo#decodeMemo(v:val)')
    let messages = filter(res.messages.matches, '!empty(v:val.text)')
    let res.messages.matches = matches
  endif

  return res
endfunction


function! slackmemo#chnnel_name()
  let res = webapi#http#get(s:slackapi . '/conversations.info', {
        \ 'token': g:slack_memo_token,
        \ 'channel': g:slack_memo_channel
        \ })
  let res = webapi#json#decode(res.content)

  return res
endfunction


function! slackmemo#matches2memos(matches) abort
  let messages = []
  for m in a:matches
    let message = {
        \ 'type': m.type,
        \ 'ts':   m.ts,
        \ 'user': m.user,
        \ 'text': m.text
        \ }
    call add(messages, message)
  endfor
  return messages
endfunction


function! slackmemo#post() abort
  let text =  join(getline(0, '$'), "\n")

  if text == ''
    redraw | echon 'Post failed, current buffer is empty!'
    return
  endif

  redraw | echon 'Posting memo... '

  let res = webapi#http#post(s:slackapi . '/chat.postMessage', {
        \ 'token': g:slack_memo_token,
        \ 'channel': g:slack_memo_channel,
        \ 'text': s:decode_memo_text(text),
        \ 'username': g:slack_memo_bot_username,
        \ 'icon_url': g:slack_memo_bot_icon_url,
        \ 'icon_emoji': g:slack_memo_bot_icon_emoji
        \ })
  let res = webapi#json#decode(res.content)

  if !res.ok
    redraw | echon 'Post failed...'
    return
  endif

  let b:slackmemo = {
        \ 'ts': res.ts
        \ }

  silent exec 'noautocmd file' s:bufprefix.b:slackmemo.ts.'.md'
  call s:SlackMemoCurrentBufferToEditable()
  call s:SlackMemoAppend(res.message)

  redraw | echon 'Done !!'
endfunction


function! slackmemo#open(memo)
  let bufname = s:bufprefix . a:memo.ts . '.md'
  let winnum = bufwinnr(bufnr(bufname))

  if winnum != -1
    if winnum != bufwinnr('%')
      exe winnum 'wincmd w'
    endif
    setlocal modifiable
  else
    for bufnr in range(1, bufnr('$'))
      if bufname == bufname(bufnr)
        silent exe 'bw!' bufnr
      endif
    endfor

    exec 'silent noautocmd rightbelow new'
    bw!

    setlocal noswapfile
    silent exec 'noautocmd file' bufname
  endif

  filetype detect
  silent %d _

  call setline(1, split(a:memo.text, "\n"))
  call s:SlackMemoCurrentBufferToEditable()
endfunction


function! s:SlackMemoListWinnr()
  return bufwinnr(bufnr(s:listbufname))
endfunction


function! s:SlackMemoListOpen()
  let winnum = s:SlackMemoListWinnr()
  if winnum != -1
    if winnum != bufwinnr('%')
      exe winnum 'wincmd w'
    endif
  else
    exec 'silent noautocmd split' s:listbufname
  endif
endfunction


function! s:SlackMemoListClose()
  let winnum = bufwinnr(bufnr(s:listbufname))
  if winnum != -1
    if winnum != bufwinnr('%')
      exe winnum 'wincmd w'
      bw!
    endif
  endif
endfunction


function! s:SlackMemoListRender()
  if exists('b:messages')
    let messages = deepcopy(b:messages)
  else
    let messages = []
  endif

  setlocal modifiable
  silent %d _

  let lines = map(messages, 's:format_memo(v:val)')
  call setline(1, split(join(lines, "\n"), "\n"))
  sort! n /\%2c/

  syntax match SpecialKey /^memo: /he=e-1
  syntax match Title /^memo: \S\+/hs=s+5 contains=ALL
  syntax match Type /\[\d\{4}-\d\{2}-\d\{2} \d\{2}:\d\{2}:\d\{2}\]/ contains=ALL

  setlocal buftype=nofile bufhidden=hide noswapfile
  setlocal cursorline
  setlocal nomodified
  setlocal nomodifiable
  nohlsearch

  nnoremap <silent> <buffer> <cr> :call <SID>SlackMemoListAction(0)<cr>
  nnoremap <silent> <buffer> o :call <SID>SlackMemoListAction(0)<cr>
  nnoremap <silent> <buffer> <nowait> d :call <SID>SlackMemoListAction(1)<cr>
  nnoremap <silent> <buffer> <nowait> y :call <SID>SlackMemoListAction(2)<cr>
  nnoremap <silent> <buffer> <nowait> r :call <SID>SlackMemoListAction(3)<cr>
  nnoremap <silent> <buffer> <esc> :bw<cr>
  nnoremap <silent> <buffer> q :bw<cr>

  redraw | echo ''
endfunction


function! s:SlackMemoAppend(memo)
  let winnum = s:SlackMemoListWinnr()
  if winnum < 0
    return
  endif

  let currentwinnum = bufwinnr(bufnr(bufname('%')))

  call s:SlackMemoListOpen()
  let view = winsaveview()
  let b:messages = getbufvar('%', 'messages')
  call add(b:messages, a:memo)
  setlocal modifiable
  call append(0, s:format_memo(a:memo))
  setlocal nomodifiable
  call winrestview(view)

  exe currentwinnum 'wincmd w'
endfunction


function! s:SlackMemoCurrentBufferToEditable()
  setlocal buftype=acwrite bufhidden=hide noswapfile
  setlocal nomodified
  doau StdinReadPost,BufRead,BufReadPost

  augroup SlackMemoWrite
    autocmd! BufWriteCmd <buffer> call s:SlackMemoWrite(expand("<amatch>"))
  augroup END
endfunction


function! s:SlackMemoListAction(mode)
  let line = getline('.')
  let ts = matchstr(line, '^memo:\s*\zs\(\d\+\.\d\+\)\ze\.*')

  if a:mode == 0
    call s:SlackMemoOpen(ts)
    call s:SlackMemoListClose()

  elseif a:mode == 1
    if confirm('Really force delete memo?', "&Yes\n&No", 2) == 1
      call s:SlackMemoDelete(ts)
    endif

  elseif a:mode == 2
    let memo = s:GetSlackMemoByTS(ts)
    let @" = memo.text
    let @* = memo.text
    redraw | echon 'Yanked!'

  elseif a:mode == 3
    call slackmemo#list("default")
  endif
endfunction


function! s:GetSlackMemoByTS(ts)
  if !exists('b:messages')
    return 0
  endif

  let messages = deepcopy(b:messages)
  let messages = filter(messages, 'slackmemo#compareMemoWithTS(v:val, "'.slackmemo#escapeTS(a:ts).'", 0)')
  return len(messages) > -1 ? messages[0] : 0
endfunction


function! s:SlackMemoOpen(ts)
  let memo = s:GetSlackMemoByTS(a:ts)
  call slackmemo#open(memo)
endfunction


function! s:SlackMemoWrite(fname) abort
  let text =  join(getline(0, '$'), "\n")
  let bufname = bufname('%')
  let bufnamemx = '^' . s:bufprefix .'\(\d\+\.\d\+\)\.md$'
  let ts = ''

  if bufname =~# bufnamemx
    let ts = matchlist(bufname, bufnamemx)[1]
  elseif exists('b:slackmemo') && has_key(b:slackmemo, 'ts')
    let ts = b:slackmemo['ts']
  endif

  if ts != ''
    call s:SlackMemoUpdate(ts, text)
  endif
endfunction


function! s:SlackMemoUpdate(ts, text)
  redraw | echon 'Updating memo...'

  let res = webapi#http#post(s:slackapi . '/chat.update', {
        \ 'token': g:slack_memo_token,
        \ 'channel': g:slack_memo_channel,
        \ 'ts': a:ts,
        \ 'text': s:decode_memo_text(a:text)
        \ })
  let res = webapi#json#decode(res.content)

  if !res.ok
    redraw
    echomsg 'Bad request...'
    return
  endif

  let winnum = s:SlackMemoListWinnr()
  if winnum > -1
    let currentwinnum = bufwinnr(bufnr(bufname('%')))

    call s:SlackMemoListOpen()
    let line = s:format_memo(res)
    let view = winsaveview()
    setlocal modifiable
    normal! gg
    if search('memo: '.a:ts)
      call setline('.', line)
    endif
    setlocal nomodifiable
    call winrestview(view)

    exe currentwinnum 'wincmd w'
  endif

  setlocal nomodified
  redraw | echon 'Updated!'
endfunction


function! s:SlackMemoDelete(ts) abort
  redraw | echon 'Deleting memo...'

  let res = webapi#http#post(s:slackapi . '/chat.delete', {
        \ 'token': g:slack_memo_token,
        \ 'channel': g:slack_memo_channel,
        \ 'ts': a:ts
        \ })
  let res = webapi#json#decode(res.content)

  if !res.ok
    redraw
    echomsg 'Bad request...'
    return
  endif

  let view = winsaveview()
  setlocal modifiable
  normal! gg
  if search('memo: '.a:ts)
    exe ':normal! dd'
  endif
  setlocal nomodifiable
  call winrestview(view)

  if exists('b:slackmemo')
    unlet b:slackmemo
  endif

  redraw | echon 'Deleted!!'
endfunction




let &cpo = s:save_cpo
unlet s:save_cpo

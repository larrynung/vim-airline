" MIT License. Copyright (c) 2013-2018 Bailey Ling et al.
" vim: et ts=2 sts=2 sw=2

scriptencoding utf-8

if &cp || v:version < 702 || (exists('g:loaded_airline') && g:loaded_airline)
  finish
endif
let g:loaded_airline = 1

let s:airline_initialized = 0
function! s:init()
  if s:airline_initialized
    return
  endif
  let s:airline_initialized = 1

  call airline#extensions#load()
  call airline#init#sections()

  let s:theme_in_vimrc = exists('g:airline_theme')
  if s:theme_in_vimrc
    try
      let palette = g:airline#themes#{g:airline_theme}#palette
    catch
      echom 'Could not resolve airline theme "' . g:airline_theme . '". Themes have been migrated to github.com/vim-airline/vim-airline-themes.'
      let g:airline_theme = 'dark'
    endtry
    silent call airline#switch_theme(g:airline_theme)
  else
    let g:airline_theme = 'dark'
    silent call s:on_colorscheme_changed()
  endif

  call airline#util#doautocmd('AirlineAfterInit')
endfunction

let s:active_winnr = -1
function! s:on_window_changed()
  let s:active_winnr = winnr()

  if pumvisible() && (!&previewwindow || g:airline_exclude_preview)
    return
  endif
  " Handle each window only once, since we might come here several times for
  " different autocommands.
  let l:key = [bufnr('%'), s:active_winnr, winnr('$'), tabpagenr(), &ft]
  if get(g:, 'airline_last_window_changed', []) == l:key
        \ && &stl is# '%!airline#statusline('.s:active_winnr.')'
        \ && &ft !~? 'gitcommit'
    " fugitive is special, it changes names and filetypes several times,
    " make sure the caching does not get into its way
    return
  endif
  let g:airline_last_window_changed = l:key
  call s:init()
  call airline#update_statusline()
endfunction

function! s:on_colorscheme_changed()
  call s:init()
  unlet! g:airline#highlighter#normal_fg_hi
  call airline#highlighter#reset_hlcache()
  let g:airline_gui_mode = airline#init#gui_mode()
  if !s:theme_in_vimrc
    call airline#switch_matching_theme()
  endif

  " couldn't find a match, or theme was defined, just refresh
  call airline#load_theme()
endfunction

function! airline#cmdwinenter(...)
  call airline#extensions#apply_left_override('Command Line', '')
endfunction

function! s:airline_toggle()
  if exists("#airline")
    augroup airline
      au!
    augroup END
    augroup! airline

    if exists("s:stl")
      let &stl = s:stl
    endif
    call airline#highlighter#reset_hlcache()

    call airline#util#doautocmd('AirlineToggledOff')
  else
    let s:stl = &statusline
    augroup airline
      autocmd!

      autocmd CmdwinEnter *
            \ call airline#add_statusline_func('airline#cmdwinenter')
            \ | call <sid>on_window_changed()
      autocmd CmdwinLeave * call airline#remove_statusline_func('airline#cmdwinenter')

      autocmd GUIEnter,ColorScheme * call <sid>on_colorscheme_changed()
      if exists("##OptionSet")
        " Make sure that g_airline_gui_mode is refreshed
        autocmd OptionSet termguicolors call <sid>on_colorscheme_changed()
      endif
      if exists("##TerminalOpen")
        autocmd TerminalOpen * call <sid>on_colorscheme_changed()
      endif
      " Set all statuslines to inactive
      autocmd FocusLost * call airline#update_statusline_inactive(range(1, winnr('$')))
      " Refresh airline for :syntax off
      autocmd SourcePre */syntax/syntax.vim
            \ call airline#extensions#tabline#buffers#invalidate()
      autocmd VimEnter,WinEnter,BufWinEnter,FileType,BufUnload *
            \ call <sid>on_window_changed()
      if exists('##CompleteDone')
        autocmd CompleteDone * call <sid>on_window_changed()
      endif
      " non-trivial number of external plugins use eventignore=all, so we need to account for that
      autocmd CursorMoved *
            \   if winnr() != s:active_winnr
            \ |   call <sid>on_window_changed()
            \ | endif

      autocmd VimResized,FocusGained * unlet! w:airline_lastmode | :call <sid>airline_refresh()
      autocmd TabEnter * :unlet! w:airline_lastmode | let w:airline_active=1
      autocmd BufWritePost */autoload/airline/themes/*.vim
            \ exec 'source '.split(globpath(&rtp, 'autoload/airline/themes/'.g:airline_theme.'.vim', 1), "\n")[0]
            \ | call airline#load_theme()
    augroup END

    if &laststatus < 2
      set laststatus=2
    endif
    if s:airline_initialized
      call s:on_window_changed()
    endif

    call airline#util#doautocmd('AirlineToggledOn')
  endif
endfunction

function! s:get_airline_themes(a, l, p)
  let files = split(globpath(&rtp, 'autoload/airline/themes/'.a:a.'*'), "\n")
  return map(files, 'fnamemodify(v:val, ":t:r")')
endfunction

function! s:airline_theme(...)
  if a:0
    call airline#switch_theme(a:1)
  else
    echo g:airline_theme
  endif
endfunction

function! s:airline_refresh()
  if !exists("#airline")
    " disabled
    return
  endif
  call airline#util#doautocmd('AirlineBeforeRefresh')
  call airline#highlighter#reset_hlcache()
  call airline#load_theme()
  call airline#update_statusline()
endfunction

command! -bar -nargs=? -complete=customlist,<sid>get_airline_themes AirlineTheme call <sid>airline_theme(<f-args>)
command! -bar AirlineToggleWhitespace call airline#extensions#whitespace#toggle()
command! -bar AirlineToggle call s:airline_toggle()
command! -bar AirlineRefresh call s:airline_refresh()

call airline#init#bootstrap()
call s:airline_toggle()

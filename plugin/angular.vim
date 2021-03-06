" angular.vim
" Maintainer:	Kevin Burnett
" Last Change: 2014 April 6


" https://github.com/scrooloose/syntastic/issues/612#issuecomment-19456342
"
" define your own proprietary attributes before this plugin loads, in your
" .vimrc, like so:
" let g:syntastic_html_tidy_ignore_errors   = [' proprietary attribute "myhotcompany-']
" let g:syntastic_html_tidy_blocklevel_tags = ['myCustomTag']
"
" or copy the mechanism used here to ensure you get both your settings and
" the ones defined by the plugin.
if !exists('g:syntastic_html_tidy_ignore_errors')
  let g:syntastic_html_tidy_ignore_errors = []
endif

let g:syntastic_html_tidy_ignore_errors += [
  \   '> proprietary attribute "',
  \   'trimming empty <'
  \ ]

if !exists('g:syntastic_html_tidy_blocklevel_tags')
  let g:syntastic_html_tidy_blocklevel_tags = []
endif

let g:syntastic_html_tidy_blocklevel_tags += [
  \ 'ng-include',
  \ 'ng-form'
  \ ]

if !exists('g:angular_find_ignore')
  let g:angular_find_ignore = []
endif

let g:angular_find_ignore += [
  \ 'coverage/',
  \ 'build/',
  \ 'dist/',
  \ 'test/',
  \ '.git/'
  \ ]

" Helper
" Find file in or below current directory and edit it.
function! s:Find(...) abort
  let path="."
  let query=a:1

  if a:0 == 2
    let cmd=a:2
  else
    let cmd="open"
  endif


  if !exists("g:angular_find_ignore")
    let ignore = ""
  else
    let ignore = " | egrep -v '".join(g:angular_find_ignore, "|")."'"
  endif

  let l:command="find ".path." -type f -iname '*".query."*'".ignore
  let l:list=system(l:command)
  let l:num=strlen(substitute(l:list, "[^\n]", "", "g"))

  if l:num < 1
    throw "AngularQueryNotFound"
    return
  endif

  if l:num == 1
    exe cmd . " " . substitute(l:list, "\n", "", "g")
  else
    let tmpfile = tempname()
    exe "redir! > " . tmpfile
    silent echon l:list
    redir END
    let old_efm = &efm
    set efm=%f

    if exists(":cgetfile")
      execute "silent! cgetfile " . tmpfile
    else
      execute "silent! cfile " . tmpfile
    endif

    let &efm = old_efm

    " Open the quickfix window below the current window
    botright copen

    call delete(tmpfile)
  endif
endfunction


" Helper
" jacked from abolish.vim (was s:snakecase there). thank you, tim pope.
function! s:dashcase(word) abort
  let word = substitute(a:word,'::','/','g')
  let word = substitute(word,'\(\u\+\)\(\u\l\)','\1_\2','g')
  let word = substitute(word,'\(\l\|\d\)\(\u\)','\1_\2','g')
  let word = substitute(word,'_','-','g')
  let word = tolower(word)
  return word
endfunction

function! s:dashcasewithngtype(word) abort
  let word = substitute(a:word,'::','/','g')
  let word = substitute(word,'\(\u\+\)\(\u\l\)','\1_\2','g')
  let word = substitute(word,'\(\l\|\d\)\(\u\)','\1_\2','g')
  let word = substitute(word,'_\([a-zA-Z]\+\)$','.\1','g')
  let word = substitute(word,'_','-','g')
  let word = tolower(word)
  return word
endfunction

function! s:FindFileBasedOnAngularServiceUnderCursor(cmd) abort
  let l:fileundercursor = expand('<cfile>')

  " Maybe the person actually has the cursor over a file path.
  " do more standard gf stuff in that case
  if filereadable(l:fileundercursor)
    execute "e " . l:fileundercursor
    return
  endif

  " app is the angular 'public root' conventionally.
  " this will help us find things like the template here:
  " $routeProvider.when('/view1', {templateUrl: 'partials/partial1.html', controller: 'MyCtrl1'});
  if filereadable("app/" . l:fileundercursor)
    execute "e " . "app/" . l:fileundercursor
    return
  endif

  let l:wordundercursor = expand('<cword>')
  let l:dashcased = s:dashcase(l:wordundercursor)
  let l:ngdotcased = s:dashcasewithngtype(l:wordundercursor)
  let l:filethatmayexistverbatim = l:wordundercursor . '.js'
  let l:filethatmayexistdashcase = l:dashcased . '.js'
  let l:filethatmayexistngdotcase = l:ngdotcased . '.js'

  let l:queries = [
    \ l:filethatmayexistverbatim,
    \ l:filethatmayexistdashcase,
    \ l:filethatmayexistngdotcase
    \ ]

  for query in l:queries
    try
      call <SID>Find(query, a:cmd)
      break
    catch 'AngularQueryNotFound'
      if (query == l:filethatmayexistngdotcase)
        echo "angular.vim says: '".join(l:queries, ', ')."' not found"
      endif
    endtry
  endfor
endfunction

function! s:SubStr(originalstring, pattern, replacement) abort
  return substitute(a:originalstring, a:pattern, a:replacement, "")
endfunction

function! s:GenerateTestPaths(currentpath, appbasepath, testbasepath) abort
  let l:samefilename = s:SubStr(a:currentpath, a:appbasepath, a:testbasepath)
  let l:withcamelcasedspecsuffix = s:SubStr(s:SubStr(a:currentpath, a:appbasepath, a:testbasepath), ".js", "Spec.js")
  let l:withdotspecsuffix = s:SubStr(s:SubStr(a:currentpath, a:appbasepath, a:testbasepath), ".js", ".spec.js")
  let l:withcoffeescriptdotspecsuffix = s:SubStr(s:SubStr(a:currentpath, a:appbasepath, a:testbasepath), ".js.coffee", ".spec.js.coffee")
  let l:withcoffeescriptcamelcasedspecsuffix = s:SubStr(s:SubStr(a:currentpath, a:appbasepath, a:testbasepath), ".js.coffee", "Spec.js.coffee")
  return [l:withdotspecsuffix, l:withcamelcasedspecsuffix, l:withcoffeescriptdotspecsuffix, l:withcoffeescriptcamelcasedspecsuffix, l:samefilename]
endfunction

function! s:GenerateSrcPaths(currentpath, appbasepath, testbasepath) abort
  return [s:SubStr(s:SubStr(a:currentpath, a:testbasepath, a:appbasepath), "Spec.js", ".js"),
        \ s:SubStr(s:SubStr(a:currentpath, a:testbasepath, a:appbasepath), ".spec.js", ".js"),
        \ s:SubStr(s:SubStr(a:currentpath, a:testbasepath, a:appbasepath), ".spec.js.coffee", ".js.coffee")]
endfunction

function! s:AngularAlternate(cmd) abort
  let l:currentpath = expand('%')
  let l:possiblepathsforalternatefile = []

  for possiblenewpath in [s:SubStr(l:currentpath, ".js", "_test.js"), s:SubStr(l:currentpath, "_test.js", ".js")]
    if possiblenewpath != l:currentpath
      let l:possiblepathsforalternatefile = l:possiblepathsforalternatefile + [possiblenewpath]
    endif
  endfor

  " handle a test subdirectory just above the leaf node
  let l:possiblenewpath = s:SubStr(l:currentpath, "/test/", "/")
  if possiblenewpath != l:currentpath
    let l:possiblepathsforalternatefile = l:possiblepathsforalternatefile + [s:SubStr(possiblenewpath, '.spec.js', '.js')]
  else
    let l:lastslashindex = strridx(l:currentpath, '/')
    let l:possibletestpath = strpart(l:currentpath, 0, l:lastslashindex) . '/test' . s:SubStr(strpart(l:currentpath, l:lastslashindex), '.js', '.spec.js')
    let l:possiblepathsforalternatefile = l:possiblepathsforalternatefile + [l:possibletestpath]
  endif

  if exists('g:angular_source_directory')
    if type(g:angular_source_directory) == type([])
      let l:possiblesrcpaths = g:angular_source_directory
    else
      let l:possiblesrcpaths = [g:angular_source_directory]
    endif
  else
    let l:possiblesrcpaths = ['app/src', 'app/js', 'app/scripts', 'public/js', 'frontend/src']
  endif

  if exists('g:angular_test_directory')
    if type(g:angular_test_directory) == type([])
      let l:possibletestpaths = g:angular_test_directory
    else
      let l:possibletestpaths = [g:angular_test_directory]
    endif
  else
    let l:possibletestpaths = ['test/unit', 'test/spec', 'test/karma/unit', 'tests/frontend']
  endif

  for srcpath in l:possiblesrcpaths
    if l:currentpath =~ srcpath
      for testpath in l:possibletestpaths
        let l:possiblepathsforalternatefile = l:possiblepathsforalternatefile + s:GenerateTestPaths(l:currentpath, srcpath, testpath)
      endfor
    endif
  endfor

  for testpath in l:possibletestpaths
    if l:currentpath =~ testpath
      for srcpath in l:possiblesrcpaths
        let l:possiblepathsforalternatefile = l:possiblepathsforalternatefile + s:GenerateSrcPaths(l:currentpath, srcpath, testpath)
      endfor
    endif
  endfor

  for path in l:possiblepathsforalternatefile
    if filereadable(path)
      return a:cmd . ' ' . fnameescape(path)
    endif
  endfor

  return 'echoerr '.string("angular.vim says: Couldn't find alternate file")
endfunction


" Helper
" goes to end of line first ($) so it doesn't go the previous
" function if your cursor is sitting right on top of the pattern
function! s:SearchUpForPattern(pattern) abort
  execute 'silent normal! ' . '$?' . a:pattern . "\r"
endfunction

function! s:FirstLetterOf(sourcestring) abort
  return strpart(a:sourcestring, 0, 1)
endfunction

function! s:AngularRunSpecOrBlock(jasminekeyword) abort
  " save cursor position so we can go back
  let b:angular_pos = getpos('.')

  cal s:SearchUpForPattern(a:jasminekeyword . '(')

  let l:wordundercursor = expand('<cword>')
  let l:jasmine1 = exists('g:angular_jasmine_version') && g:angular_jasmine_version == 1
  if l:jasmine1
    let l:additionalletter = s:FirstLetterOf(a:jasminekeyword)
  else
    let l:additionalletter = 'f'
  end

  if l:wordundercursor == a:jasminekeyword
    " if there was a spec (anywhere in the file) highlighted with "iit" before, revert it to "it"
    let l:positionofspectorun = getpos('.')

    " this can move the cursor, hence setting the cursor back
    if l:jasmine1
      %s/ddescribe(/describe(/ge
      %s/iit(/it(/ge
    else
      %s/fdescribe(/describe(/ge
      %s/fit(/it(/ge
    end

    " move cursor back to the spec we want to run
    call setpos('.', l:positionofspectorun)

    " either change the current spec to "iit" or
    " the current block to "ddescribe"
    execute 'silent normal! cw' . l:additionalletter . a:jasminekeyword
  elseif l:wordundercursor == l:additionalletter . a:jasminekeyword
    " either delete the first i in "iit" or
    " the first d in "ddescribe"
    execute 'silent normal! hx'
  endif

  update " write the file if modified

  " Reset cursor to previous position.
  call setpos('.', b:angular_pos)
endfunction

function! s:AngularRunSpecBlock() abort
  cal s:AngularRunSpecOrBlock('describe')
endfunction

function! s:AngularRunSpec() abort
  cal s:AngularRunSpecOrBlock('it')
endfunction


nnoremap <silent> <Plug>AngularGfJump :<C-U>exe <SID>FindFileBasedOnAngularServiceUnderCursor('open')<CR>
nnoremap <silent> <Plug>AngularGfSplit :<C-U>exe <SID>FindFileBasedOnAngularServiceUnderCursor('split')<CR>
nnoremap <silent> <Plug>AngularGfTabjump :<C-U>exe <SID>FindFileBasedOnAngularServiceUnderCursor('tabedit')<CR>

au BufNewFile,BufRead *.coffee set filetype=coffee

augroup angular_gf
  autocmd!
  autocmd FileType javascript,coffee,html command! -buffer AngularGoToFile :call s:FindFileBasedOnAngularServiceUnderCursor('open')
  autocmd FileType javascript,coffee,html nmap <buffer> gf          <Plug>AngularGfJump
  autocmd FileType javascript,coffee,html nmap <buffer> <C-W>f      <Plug>AngularGfSplit
  autocmd FileType javascript,coffee,html nmap <buffer> <C-W><C-F>  <Plug>AngularGfSplit
  autocmd FileType javascript,coffee,html nmap <buffer> <C-W>gf     <Plug>AngularGfTabjump
augroup END

if !exists('g:angular_skip_alternate_mappings')
  augroup angular_alternate
    autocmd!
    autocmd FileType javascript,coffee command! -buffer -bar -bang AA :exe s:AngularAlternate('edit<bang>')
    autocmd FileType javascript,coffee command! -buffer -bar AAS :exe s:AngularAlternate('split')
    autocmd FileType javascript,coffee command! -buffer -bar AAV :exe s:AngularAlternate('vsplit')
    autocmd FileType javascript,coffee command! -buffer -bar AAT :exe s:AngularAlternate('tabedit')
  augroup END
endif

augroup angular_run_spec
  autocmd!
  autocmd FileType javascript,coffee command! -buffer AngularRunSpec :call s:AngularRunSpec()
  autocmd FileType javascript,coffee command! -buffer AngularRunSpecBlock :call s:AngularRunSpecBlock()
  autocmd FileType javascript,coffee nnoremap <silent><buffer> <Leader>rs  :AngularRunSpec<CR>
  autocmd FileType javascript,coffee nnoremap <silent><buffer> <Leader>rb  :AngularRunSpecBlock<CR>
augroup END

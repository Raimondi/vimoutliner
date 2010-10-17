if v:version < 700
	echom 'VimOutliner: vo_tags.vim requires Vim 7.0 or later.'
	finish
endif

if !exists('g:vo_tagfile')
	if glob('$HOME/.vimoutliner') != ''
		let g:vo_tagfile = expand('$HOME/.vimoutliner/vo_tags.tag')
	else
		let g:vo_tagfile = expand("<sfile>:p:h:h").'/vimoutliner/vo_tags.tag'
	endif
endif

" command! -bar -buffer VOUpdateTags call <SID>MakeTags(expand('%'))

" Handle missing tags or tags file.
noremap <buffer> <Plug>VO_OpenTag :call <SID>OpenTag()<CR>
if !hasmapto('<Plug>VO_OpenTag')
	"map <unique> <buffer> <C-]> <Plug>VO_OpenTag
	map <buffer> <C-]> <Plug>VO_OpenTag
	"map <unique> <buffer> <C-K> <Plug>VO_OpenTag
	map <buffer> <C-K> <Plug>VO_OpenTag
endif

" Ask for a file name if one is not found.
noremap <buffer> <Plug>VO_CreateTag :call <SID>CreateTag()<CR>
if !hasmapto('<Plug>VO_CreateTag')
	map <unique> <buffer> <localleader>l <Plug>VO_CreateTag
endif
inoremap <buffer> <Plug>VO_CreateTagI <C-O>:call <SID>CreateTag()<CR>
if !hasmapto('<Plug>VO_CreateTagI')
	imap <unique> <buffer> <localleader>l <Plug>VO_CreateTagI
endif

if exists('s:loaded')
	finish
else
	let s:loaded = 1
endif

" s:OpenTag() {{{1
" Handle missing tags or tags file.
function s:OpenTag()

	" Check if file path exists.
	let file = substitute(getline(line('.') + 1), '^\s*\(\S.\{-}\)\s*$','\1','')
	let file = fnamemodify(file,':p')
	let baseDir = fnamemodify(file,':h')
	let dirconfirm = 0
	if glob(baseDir) == ''
		if exists('*confirm')
			let dirconfirm = confirm('The linked file "'.file.'" and one or more directories do not exist, do you want to create them now?', "&Yes\n&No", '2', 'Question')
		else
			let dirconfirm = 1
		endif
		if dirconfirm == 1
			" Create dir(s):
			if exists('*mkdir')
				call mkdir(baseDir,'p')
			elseif executable('mkdir')
				call system('`which mkdir` -p '.baseDir)
			else
				" What to do here? inform the user of something?
				return
			endif
		endif
	endif
	if glob(file) == ''
		if exists('*confirm') && dirconfirm == 0
			let confirm = confirm('The linked file "'.file.'" does not exist, do you want to create it now?', "&Yes\n&No", '2', 'Question')
		else
			let confirm = 1
		endif
		if confirm == 1
			call writefile([], file)
		endif
	endif

	try
		let retry = 0
		exec "normal! \<C-]>"
	catch /E429\|E426\|E433/
		" Use a given outline as the root of the tag building or the current file.
		if !exists('g:vo_root_outline')
			let g:vo_root_outline = expand('%:p')
		endif

		" Build tags file if it or the tag doesn't exist.
		call s:MakeTags(g:vo_root_outline)
		let retry = 1
		redraw
	catch /E349/
		" Prevent reporting that the error ocurred inside this function.
		echoh ErrorMsg
		echom substitute(v:exception,'^Vim(.\{-}):','','')
		echoh None
	endtry
	if !retry
		return ''
	endif
	try
		exec "normal! \<C-]>"
	catch /E429\|E426\|E433/
		" Prevent reporting that the error ocurred inside this function.
		echoh ErrorMsg
		echom substitute(v:exception,'^Vim(.\{-}):','','')
		echoh None
	endtry
	return ''
endfunction
" }}}1
" s:CreateTag() {{{1
" Create an interoutline link with the current keyword under the cursor.
function s:CreateTag()
	let line = getline('.')
	if line =~# '^\s*\w\+$' &&
				\ ( line('.') == line('$') ||
				\ indent('.') >= indent(line('.') + 1 ) ||
				\ match(getline(line('.') + 1), '^\s*.\+\.otl\s*$') == -1)
		call setline(line('.'), substitute(line, '^\(\s*\)\(_tag_\)\?\(\S\+\)$','\1_tag_\3', ''))
		call inputsave()
		let input = input('Linked outline: ', '', 'file')
		call inputrestore()
		if input == ''
			return ''
		endif
		let path = substitute(input, '^\s*\(.\{-1,}\)\s*$', '\1', '')
		"if path !~ '\.otl$'
			"let path = path.'.otl'
		"endif
		call append(line('.'), path)
		let linenr = line('.')
		let indent = indent(linenr)
		normal! j
		while indent >= indent(linenr + 1)
			normal! >>
		endwhile
		normal! k$
	else
		echom 'That does not seem to be a proper tag.'
		return ''
	endif
endfunction
" }}}1
" s:MakeTags(file) {{{1
" Create tags file
function! s:MakeTags(file)
	echom 'Creating tags file at: '.g:vo_tagfile
	let file = s:DeriveAbsoluteFileName(getcwd().'/', expand(a:file))
	let g:processedFiles = []
	call delete(g:vo_tagfile)
	let g:alltags = []
	call add(g:processedFiles, file)
	call s:ProcessOutline(file)
	call sort(filter(g:alltags, 'count(g:alltags, v:val) == 1'))
	call writefile(g:alltags, g:vo_tagfile)
	unlet g:processedFiles
	unlet g:alltags
	redraw
	echom 'Tags file created.'
endfunction
"}}}1
" s:ProcessOutline(file) {{{1
" Look for tags in all linked files
function! s:ProcessOutline(file)
	let file = simplify(fnamemodify(expand(a:file),':p'))
	let baseDir = fnamemodify(file, ':p:h')
	if glob(file) == ''
		return ''
	endif
	echom 'Processing file "'.file.'"...'
	let tags = s:GetTagsFromFile(file)
	for tag in tags
		let taglist = split(tag, "\t")
		let tagkey  = taglist[0]
		let tagpath = expand(taglist[1])
		if tagpath !~ '^/'
			let tagpath = s:DeriveAbsoluteFileName(baseDir, tagpath)
		endif
		call add(g:alltags, tagkey."\t".tagpath."\t:1")
		if index(g:processedFiles, tagpath) == -1
			call add(g:processedFiles, tagpath)
			call s:ProcessOutline(tagpath)
		endif
	endfor
endfunction
" }}}1
" s:GetTagsFromFile(path) {{{1
" Extract tags
function! s:GetTagsFromFile(path)
	" Don't readfile() a loaded buffer if it has unsaved changes.
	if bufloaded(a:path) && getbufvar(a:path, '&modified')
		echo expand('%')
		let pos_save = getpos('.')
		let reg_save = @a
		let @a = ''
		let search_save = @/
		exec "b ".a:path
		g/./y A
		let lines = split(@a, "\n")
		let @/ = search_save
		let @a = reg_save
		call setpos('.', pos_save)
	else
		try
			let lines = readfile(a:path)
		catch '/E484/'
			echoerr 'Error in vo_maketags.vim, couldn''t read file: ' . a:path
			return []
		endtry
	endif

	call map(lines, 'v:val =~# ''^\s*_tag_\S\+'' ? substitute(v:val, ''^\s*\(_tag_\S\+\).*$'', ''\1'', "")."\t".substitute(get(lines, index(lines, v:val) + 1, ""),''^\s*'',"","") : v:val')
	call filter(lines, 'v:val =~# ''^_tag_\S\+\t\S''')
	return lines
endfunction
" }}}1
" s:DeriveAbsoluteFileName(baseDir, fileName) {{{1
" Guess an absolute path
function! s:DeriveAbsoluteFileName(baseDir, fileName)
	let baseDir = a:baseDir
	if baseDir !~ '/$'
		let baseDir = baseDir . '/'
	endif
	if a:fileName =~ '^/'
		let absFileName = a:fileName
	else
		let absFileName = baseDir . a:fileName
	endif

	let absFileName = substitute(absFileName, '/\./', '/', 'g')
	while absFileName =~ '/\.\./'
		absFileName = substitute(absFileName, '/[^/]*\.\./', '', '')
	endwhile
	return absFileName
endfunction
" }}}1

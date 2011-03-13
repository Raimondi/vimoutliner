" VimOutliner {{{1
"#########################################################################
"# ftplugin/vo_sort.vim: VimOutliner sort plugin
"#
"#   extracted from core vimoutliner to ease leveraging, optionnality
"#   visibility aso...
"#
"#   Copyright (C) 2001,2003 by Steve Litt (slitt@troubleshooters.com)
"#   Copyright (C) 2004 by Noel Henson (noel@noels-lab.com)
"#
"#   This program is free software; you can redistribute it and/or modify
"#   it under the terms of the GNU General Public License as published by
"#   the Free Software Foundation; either version 2 of the License, or
"#   (at your option) any later version.
"#
"#   This program is distributed in the hope that it will be useful,
"#   but WITHOUT ANY WARRANTY; without even the implied warranty of
"#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
"#   GNU General Public License for more details.
"#
"#   You should have received a copy of the GNU General Public License
"#   along with this program; if not, write to the Free Software
"#   Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
"#
"# Steve Litt, slitt@troubleshooters.com, http://www.troubleshooters.com
"#########################################################################
"}}}1
" Functions {{{1
" IsParent(line) {{{2
" Return 1 if this line is a parent
function! s:IsParent(line)
	return (Ind(a:line)+1) == Ind(a:line+1)
endfunction
"}}}2
" FindParent(line) {{{2
" Return line if parent, parent line if not
function! s:FindParent(line)
	let l:parentindent = Ind(a:line)-1
	let l:searchline   = a:line
	while (Ind(l:searchline) != l:parentindent) && (l:searchline > 0)
		let l:searchline -= 1
	endwhile
	return l:searchline
endfunction
"}}}2
" FindLastChild(line) {{{2
" Return the line number of the last decendent of parent line
function! s:FindLastChild(line)
	let l:parentindent = Ind(a:line)
	let l:searchline   = a:line+1
	while Ind(l:searchline) > l:parentindent
		let l:searchline += 1
	endwhile
	return l:searchline-1
endfunction
"}}}2
" MoveHead() {{{2
" Move the heading one heading down
function! s:MoveHead(line)
	let l:fstart = foldclosed(a:line)
	if l:fstart == -1
		let l:execstr = a:line
	else
		let l:execstr = l:fstart . "," . foldclosedend(a:line)
	endif
	exec l:execstr . "del x"

	let l:fstart = foldclosed(a:line)
	if l:fstart == -1
		let l:execstr = a:line
	else
		let l:execstr = foldclosedend(a:line)
	endif
	exec l:execstr . "put x"
endfunction
"}}}2
" NextHead(line) {{{2
" Return line of next heanding
" Used for sorts and reordering of headings
function! s:NextHead(line)
	let l:fend = foldclosedend(a:line)
	if l:fend == -1
		" we are out of the sorted outlines
		if foldlevel(a:line) != foldlevel(a:line+1)
			return -1
		endif
		return a:line+1
	endif
	return l:fend+1
endfunction
"}}}2
" GetHeadContent(line) {{{2
" get the line contents, removing checkboxes, percent if necesssary
let g:reCheckBox = "\\[\[^]\]*\\]"
let g:reCheckBoxContent = "\\[\[^]\]*\\] \\%(\\d*% \\)\\?\\(.*\\)"
let g:reLineContent = "\\s*\\(.*\\)"
function! s:GetHeadContent(line)
	let l:content = getline(a:line)
	if match(l:content,g:reCheckBox) != -1
		return matchlist(l:content,g:reCheckBoxContent)[1]
	endif
	return matchlist(l:content,g:reLineContent)[1]
endfunction
"}}}2
" CompHead(line) {{{2
" Compare this heading and the next
" Return 1: next is greater, 0 next is same, -1 next is less
function! s:CompHead(line)
	let l:nexthead = s:NextHead(a:line)
	echomsg l:nexthead
	" no more headers in this range, nothing to do
	if nexthead == -1
		return 0
	endif
	let l:thisline=s:GetHeadContent(a:line)
	let l:nextline=s:GetHeadContent(l:nexthead)
	if l:thisline <# l:nextline
		return 1
	elseif l:thisline ># l:nextline
		return -1
	else
		return 0
	endif
endfunction
"}}}2
" Sort1Line(line) {{{2
" Compare this heading and the next and swap if out of order
" Dir is 1 for forward, -1 for reverse
" Return a 1 if a change was made 
function! s:Sort1Line(line,dir)
	let l:comphead = s:CompHead(a:line) 
	if (l:comphead == 0)
		return 0
	endif
	if (l:comphead == -a:dir)
		call s:MoveHead(a:line)
		return 1
	endif
	return 0
endfunction
"}}}2
" Sort1Pass(start,end,dir) {{{2
" Compare this heading and the next and swap if out of order
" Dir is 1 for forward, -1 for reverse
" Return the change count
function! s:Sort1Pass(fstart,fend,dir)
	let l:i = a:fstart
	let l:changed = 0
	while l:i < a:fend
		let l:changed += s:Sort1Line(l:i,a:dir)
		let l:i = s:NextHead(l:i)
	endwhile
	return l:changed
endfunction
"}}}2
" SortRange(start,end,dir) {{{2
" Sort this range of headings
" dir: 0 = ascending, 1 = decending 
function! s:SortRange(fstart,fend,dir)
	let l:changed = 1
	while l:changed != 0
		let l:changed = s:Sort1Pass(a:fstart,a:fend,a:dir)
	endwhile
endfunction
"}}}2
" SortChildren(dir) {{{2
" Sort the children of a parent 
" dir: 0 = ascending, 1 = decending 
function! SortChildren(dir)
	let l:oldcursor = line(".")
	let l:fstart = s:FindParent(line("."))
	let l:fend = s:FindLastChild(l:fstart)
	let l:fstart = l:fstart
	if l:fend <= l:fstart + 1
		return
	endif
	call append(line("$"),"Temporary last line for sorting")
	mkview
	exec "set foldlevel=" . foldlevel(l:fstart)
	call s:SortRange(l:fstart + 1,l:fend,a:dir)
	call cursor(line("$"),0)
	del x
	loadview
	call cursor(l:oldcursor,0)
endfunction
"}}}2
"}}}1
" Key Mappings {{{1
" sort a list naturally
map <buffer> <localleader>s :call SortChildren(1)<cr>
" sort a list, but you supply the options
map <buffer> <localleader>S :call SortChildren(-1)<cr>
"}}}1
" vim:set fdm=marker:

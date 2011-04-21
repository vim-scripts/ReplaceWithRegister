" ReplaceWithRegister.vim: Replace text with the contents of a register. 
"
" DEPENDENCIES:
"   - Requires Vim 7.0 or higher. 
"   - repeat.vim (vimscript #2136) autoload script (optional). 
"   - visualrepeat.vim autoload script (optional). 
"
" Copyright: (C) 2008-2011 by Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'. 
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS 
"   1.10.012	18-Mar-2011	The operator-pending mapping now also handles
"				'nomodifiable' and 'readonly' buffers without
"				function errors. Add checking and probing inside
"				s:ReplaceWithRegisterOperatorExpression(). 
"   1.10.011	17-Mar-2011	Add experimental support for repeating the
"				replacement also in visual mode through
"				visualrepeat.vim. Renamed vmap
"				<Plug>ReplaceWithRegisterOperator to
"				<Plug>ReplaceWithRegisterVisual for that. 
"				A repeat in visual mode will now apply the
"				previous line and operator replacement to the
"				selection text. A repeat in normal mode will
"				apply the previous visual mode replacement at
"				the current cursor position, using the size of
"				the last visual selection. 
"   1.03.010	07-Jan-2011	ENH: Better handling when buffer is
"				'nomodifiable' or 'readonly'. Using the trick of
"				prepending a no-op buffer modification before
"				invoking the functions. Using try...catch inside
"				s:ReplaceWithRegister() would break the needed
"				abort inside the :normal sequence of replacing
"				the selection, then inserting the register. The
"				disastrous result would be erroneous
"				interpretation of <C-O> as a normal mode
"				command! 
"   1.02.009	25-Nov-2009	Replaced the <SID>Count workaround with
"				:map-expr and an intermediate
"				s:ReplaceWithRegisterOperatorExpression. 
"   1.01.008	06-Oct-2009	Do not define "gr" mapping for select mode;
"				printable characters should start insert mode. 
"   1.00.007	05-Jul-2009	Renamed from ingooperators.vim. 
"				Replaced g:register with call to
"				s:SetRegister(). 
"	006	05-Mar-2009	BF: Besides 'autoindent', 'indentexpr' also
"				causes additional indent. Now completely turning
"				off all these things via the 'paste' option. 
"	005	23-Feb-2009	BF: When replacing a complete line over an
"				indented line (with 'Vgr' or 'grr'), the old
"				indent was kept. Now temporarily turning off
"				'autoindent' to avoid that. 
"	004	20-Feb-2009	BF: ReplaceWithRegisterOperator mapping didn't
"				work for "last line" G motion, because v:count1
"				defaulted to line 1. Now checking v:count and
"				mapping to <Nop> if no count was given. 
"	003	01-Feb-2009	Allowing repeating via '.' by avoiding the
"				script error about undefined variable
"				g:register. 
"				Put try...finally around temporary 'selection'
"				setting. 
"				ENH: Now allowing [count] in front of
"				gr{motion} (see :help ingo-opfunc for details)
"				and grr (via repeat.vim). 
"				Now correcting mismatch when replacement is
"				linewise by temporarily removing the trailing
"				newline. 
"	002	15-Aug-2008	Added {Visual}gr and grr mappings. 
"	001	11-Aug-2008	file creation

" Avoid installing twice or when in unsupported Vim version. 
if exists('g:loaded_ReplaceWithRegister') || (v:version < 700)
    finish
endif
let g:loaded_ReplaceWithRegister = 1

function! s:SetRegister()
    let s:register = v:register
endfunction
function! s:ReplaceWithRegister( type )
    " It is important to delete into the black hole register, otherwise, the
    " unnamed register will be clobbered, and this may contain the text we want
    " to paste. 
    let l:replaceOnVisualSelectionCommand = '"_c' . "\<C-R>\<C-O>" . s:register . "\<Esc>"
    " If s:register is removed, repeat via '.' will fail on the above line,
    " because s:register is undefined. 
    "unlet s:register

    if a:type == 'visual'
	" Note: The 'cc' command (and thus also 'c' on a linewise visual
	" selection) preserves the indent of the first line if 'autoindent' is
	" on (cp. :help cc), or if there is an 'indentexpr'. As we want a
	" replacement exactly inside the former visual selection, we temporarily
	" turn off all these things by setting 'paste'. 
	setlocal paste
	try
	    execute 'normal! gv' . l:replaceOnVisualSelectionCommand
	finally
	    setlocal nopaste
	endtry
    else
	" Note: :normal! `[c`] would keep the last moved-over character, as 'c'
	" changes until the mark, but does not include it. The easiest way to get
	" around this is to first establish a visual selection, then change that.
	" However, even here we need to make sure to be "inclusive"! 
	let l:save_selection = &selection
	set selection=inclusive
	try
	    execute 'normal! `[v`]' . l:replaceOnVisualSelectionCommand
	finally
	    let &selection = l:save_selection
	endtry
    endif
endfunction
function! s:ReplaceWithRegisterOperator( type, ... )
    let l:pasteText = getreg(s:register)
    let l:regType = getregtype(s:register)
    if l:regType ==# 'V' && l:pasteText =~# '\n$'
	" Our custom operator is linewise, even in the ReplaceWithRegisterLine
	" variant, in order to be able to replace less than entire lines (i.e.
	" characterwise yanks). 
	" So there's a mismatch when the replacement text is a linewise yank,
	" and the replacement would put an additional newline to the end.
	" To fix that, we temporarily remove the trailing newline character from
	" the register contents and set the register type to characterwise yank. 
	call setreg(s:register, strpart(l:pasteText, 0, len(l:pasteText) - 1), 'v')
    endif
    try
	call s:ReplaceWithRegister(a:type)
    finally
	if l:regType ==# 'V' && l:pasteText =~# '\n$'
	    " Undo the temporary change of the register. 
	    call setreg(s:register, l:pasteText, l:regType)
	endif
    endtry

    if a:0
	silent! call repeat#set(a:1)
	silent! call visualrepeat#set_also("\<Plug>ReplaceWithRegisterVisual")
    else
	silent! call visualrepeat#set("\<Plug>ReplaceWithRegisterVisual")
    endif
endfunction
function! s:ReplaceWithRegisterOperatorExpression( opfunc )
    call s:SetRegister()
    let &opfunc = a:opfunc

    let l:keys = 'g@'
    if ! &l:modifiable || &l:readonly
	" Probe for "Cannot make changes" error and readonly warning via a no-op
	" dummy modification. 
	" In the case of a nomodifiable buffer, Vim will abort the normal mode
	" command chain, discard the g@, and thus not invoke the operatorfunc. 
	let l:keys = "\"=''\<CR>p" . l:keys
    endif
    return l:keys
endfunction

" This mapping repeats naturally, because it just sets global things, and Vim is
" able to repeat the g@ on its own. 
nnoremap <expr> <Plug>ReplaceWithRegisterOperator <SID>ReplaceWithRegisterOperatorExpression('<SID>ReplaceWithRegisterOperator')
" This mapping needs repeat.vim to be repeatable, because it contains of
" multiple steps (visual selection + 'c' command inside
" s:ReplaceWithRegisterOperator). 
nnoremap <silent> <Plug>ReplaceWithRegisterLine     :<C-u>call setline(1, getline(1))<Bar>call <SID>SetRegister()<Bar>execute 'normal! V' . v:count1 . "_\<lt>Esc>"<Bar>call <SID>ReplaceWithRegisterOperator('visual', "\<lt>Plug>ReplaceWithRegisterLine")<CR>
" Repeat not defined in visual mode. 
vnoremap <silent> <SID>ReplaceWithRegisterVisual :<C-u>call setline(1, getline(1))<Bar>call <SID>SetRegister()<Bar>call <SID>ReplaceWithRegisterOperator('visual', "\<lt>Plug>ReplaceWithRegisterVisual")<CR>
vnoremap <silent> <script> <Plug>ReplaceWithRegisterVisual <SID>ReplaceWithRegisterVisual
nnoremap <expr> <SID>Reselect '1v' . (visualmode() !=# 'V' && &selection ==# 'exclusive' ? ' ' : '')
nnoremap <silent> <script> <Plug>ReplaceWithRegisterVisual <SID>Reselect<SID>ReplaceWithRegisterVisual

if ! hasmapto('<Plug>ReplaceWithRegisterOperator', 'n')
    nmap <silent> gr <Plug>ReplaceWithRegisterOperator
endif
if ! hasmapto('<Plug>ReplaceWithRegisterLine', 'n')
    nmap <silent> grr <Plug>ReplaceWithRegisterLine
endif
if ! hasmapto('<Plug>ReplaceWithRegisterVisual', 'x')
    xmap <silent> gr <Plug>ReplaceWithRegisterVisual
endif

" vim: set sts=4 sw=4 noexpandtab ff=unix fdm=syntax :

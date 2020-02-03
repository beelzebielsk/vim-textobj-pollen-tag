" textobj-pollen-tag - Text object for a tag in the pollen language
" Version: 0.2.0
" Author: beelzebielsk <ibrahimadam193@gmail.com>

if exists("g:loaded_textobj_pollen_tag")
    finish
endif
let g:loaded_textobj_pollen_tag = 1

"call textobj#user#plugin('pollen', {
    "\ 'tag' : { 
    "\     'select-a-function' : 'textobj#pollen#PollenTagA',
    "\     'select-i-function' : 'textobj#pollen#PollenTagI',
    "\     'select-a' : 'at',
    "\     'select-i' : 'it',
    "\     }
    "\ })
"call textobj#user#plugin('pollen', {
    "\ 'tag' : { 
    "\     'select-a-function' : 'textobj#pollen#PollenTagA',
    "\     'select-i-function' : 'textobj#pollen#PollenTagI',
    "\     }
    "\ })

" Source for racket identifier syntax:
" <https://docs.racket-lang.org/guide/symbols.html>

let s:racket_id_pat = '[^()\[\]{}",`'';#|\\◊ ]'
let s:tag_pat = '◊' . s:racket_id_pat . '\+'
let s:square_brace_start = s:tag_pat . '\['

" source:
" <https://stackoverflow.com/questions/23323747/vim-vimscript-get-exact-character-under-the-cursor>
function! s:get_char_at(line, column)
    return nr2char(strgetchar(getline(a:line)[a:column - 1:], 0))
endfunction

function! s:get_cur_char()
    return s:get_char_at(line('.'), col('.'))
    " return nr2char(strgetchar(getline('.')[col('.') - 1:], 0))
endfunction

" Arguments: A getpos() location
" Returns: A modified getpos() location which points to the location
" one space before posn. If at the start of a line, moves to the end
" of the prior line. If it cannot move backwards by one (ie is at file
" start), then it returns the same location given to it.
function! s:move_back_one(posn)
    let l:lineno = a:posn[1]
    let l:colno = a:posn[2]

    if l:lineno == 1 && l:colno == 1 " If at document start
        return a:posn
    elseif l:colno == 1 && l:lineno != 1 " If at line start
        let l:prev_line_end = col([l:lineno - 1, '$'])
        let l:one_back = copy(a:posn)
        let l:one_back[1] -= 1
        let l:one_back[2] = l:prev_line_end
        return l:one_back
    endif

    let l:one_back = copy(a:posn)
    let l:one_back[2] -= 1
    return l:one_back
endfunction

" Arguments: A getpos() location
" Returns: A modified getpos() location which points to the location
" one space after posn. If at the end of a line, moves to the start of
" the next line. If it cannot move ahead by one (ie is at file
" end), then it returns the same location given to it.
function! s:move_forward_one(posn)
    let l:last_line = line('$')
    let l:lineno = a:posn[1]
    let l:colno = a:posn[2]
    " l:EOL for the line from a:posn
    let l:EOL = s:searchpos_to_search([l:lineno, col([l:lineno, '$'])], getpos('.'))
    let l:EOF = s:searchpos_to_search([l:last_line, col([l:last_line, '$'])], getpos('.'))
    if a:posn == l:EOF
        return a:posn
    endif

    let l:forward = copy(a:posn)

    if a:posn == l:EOL
        let l:forward[1] += 1
        let l:forward[2] = 1
    else
        let l:forward[2] += 1
    endif
    return l:forward
endfunction

" Arguments:
" - spos_loc: A location as returned by searchpos
" - s_loc: A location as returned by search
" Returns:
" Translated spos_loc to s_loc form using the extra parameters from
" s_loc.
function! s:searchpos_to_search(spos_loc, s_loc)
    let l:result = copy(a:s_loc)
    let l:result[1] = a:spos_loc[0]
    let l:result[2] = a:spos_loc[1]
    return l:result
endfunction

" You're on a tag if there's an unbroken string of ◊ followed by
" racket identifier chars up to the current posn on the cursor
" Arguments: None
" Returns:
" - if you're on a tag, then returns [line, col] at the start of the tag
" - Otherwise returns 0.
function! s:on_tag()
    let l:cur_pos = getpos('.')
    " You're either on the lozenge...
    if s:get_cur_char() ==# '◊'
        return l:cur_pos
    endif
    " Or you're on the id: this means there should be an unbroken
    " series of racket identifier chars between current position and
    " lozenge.
    let l:lozenge_pos = searchpos('◊', 'bcn', line('.'))
    " If there's no lozenge on this line, there's no way you're on a
    " tag.
    if l:lozenge_pos == [0, 0]
        return 0
    endif
    let l:lozenge_col = l:lozenge_pos[1]
    let l:cur_col = l:cur_pos[2]
    let l:bw_tag_here = strpart(getline('.'), l:lozenge_col - 1, l:cur_col - l:lozenge_col + 1)
    if l:bw_tag_here =~ '^' . s:tag_pat . '$'
        return s:searchpos_to_search(l:lozenge_pos, l:cur_pos)
    endif
    " Or you're on neither. You're not on a tag.
    return 0
endfunction

" Finds if there is a tag on the current line.
" Returns:
" - If there is a tag on the current line, returns the [line, col] of
"   the " start of the tag which is closest to the cursor (backwards
"   direction)
" - Otherwise, return 0.
function! s:tag_on_cur_line()
    let l:cur_pos = getpos('.')
    let l:tag_pos = searchpos(s:tag_pat, 'bcn', line('.'))
    if l:tag_pos == [0, 0]
        return 0
    else
        return s:searchpos_to_search(l:tag_pos, l:cur_pos)
    endif
endfunction

" Assumes that the pollen tag stuff is all on one line. The body in
" the braces may be on many lines.
" Will ignore possibility of being in square braces today.
function! textobj#pollen#PollenTagA()
    " A tag consists of 
    "   '◊' identifier square-brace-group? brace-group
    " You're either:
    "- on the ◊. Test if current char is '◊'.
    "- on the identifier. Test if there's a '◊' prior w/o whitespace.
    "  Just racket id chars.
    "- on or in the square-brace-group if it exists.
    "   - the square brace group should contain just racket
    "   expressions or keyword arguments. There should be no nested []
    "   in the square brace group. In particular, even if we're not in
    "   a square brace group, that should mean we find searchpair([])
    "   turns up false
    "- on or in the brace-group
    "The head should be the '◊' char belonging to the containing tag,
    "and the tail should be the end of the brace-group.
    " NOTE: It is assumed that, if there is a brace group, it is on
    " the same line as the tag. This implies that there are no line
    " breaks in a square brace group, if there is a square brace
    " group.
    
    let l:start_pos = getpos('.')
    let l:has_square_brace = v:false
    let l:has_brace = v:false
    let l:tag_pos = s:on_tag()
    " If we're on the tag...
    if type(l:tag_pos) == v:t_list
        let l:head_pos = l:tag_pos
        if search('{', 'Wn', line('.')) > 0
            normal! f{%
            let l:tail_pos = getpos('.')
        else
            normal! f[%
            let l:tail_pos = getpos('.')
        endif
        return ['v', l:head_pos, l:tail_pos]
    endif

    " If we're in the square-brace-group
    if searchpair(s:square_brace_start, '', '\]', 'bc') > 0
        let l:head_pos = getpos('.')
        if search('{', 'Wn', line('.')) > 0
            normal! f{%
            let l:tail_pos = getpos('.')
        else
            normal! f[%
            let l:tail_pos = getpos('.')
        endif
        return ['v', l:head_pos, l:tail_pos]
    endif

    while searchpair('{', '', '}', 'b') > 0
        let l:open_brack_pos = getpos('.')
        " echo "l:open_brack_pos" l:open_brack_pos
        let l:prev_tag_on_line_pos = s:tag_on_cur_line()
        if type(l:prev_tag_on_line_pos) == v:t_list
            let l:has_brace = v:true
            let l:head_pos = l:prev_tag_on_line_pos
            normal! %
            let l:tail_pos = getpos('.')
            return ['v', l:head_pos, l:tail_pos]
        endif
    endwhile

    return 0
endfunction

" The I refers only to the inside of the brace group, if it has one. I
" will assume the presence of a brace group.
function! textobj#pollen#PollenTagI()
    let l:cur_pos = getpos('.')
    let l:outer_bounds = textobj#pollen#PollenTagA()
    " If there isn't a tag here...
    if type(l:outer_bounds) == v:t_number
        return l:outer_bounds
    endif
    call setpos('.', l:outer_bounds[1])
    let l:last_char = s:get_char_at(l:outer_bounds[2][1], l:outer_bounds[2][2])

    if l:last_char ==# '}'
        normal! f{
    else
        normal! f[
    endif

    let l:start_brace = getpos('.')
    let l:end_brace = l:outer_bounds[2]

    " Move the positions inward, inside of the braces.
    let l:start_brace = s:move_forward_one(l:start_brace)
    let l:end_brace = s:move_back_one(l:end_brace)

    return ['v', l:start_brace, l:end_brace]
endfunction

" You can't do this here and expect it to work right. What this does
" is, when you open a pollen file it registers this autocmd---it
" doesn't run the actual command. Consider everything in this file to
" be within an "autocmd FileType pollen".
"       autocmd FileType pollen inoremap <buffer> <c-l> <c-k>LZ

" TODO
" - The tag functions only recognize tags whose "{" is on the same
"   line as the tag itself (if it has brackets). Change it so that the
"   square brackets can always have newlines in them. You can allow
"   the "{" to come right after the square brackets if they're
"   present. If there are no square brackets, you're free to assume
"   "{" is on the same line as the tag.
"
" Notes:
" - .vim/plugin: Gets run once on vim startup. All of 'em.
" - .vim/after: Gets run once on vim startup, after everything in
"   .vim/plugin gets run.
" - The text object functions go in autoload and have the autoload
"   names on them.

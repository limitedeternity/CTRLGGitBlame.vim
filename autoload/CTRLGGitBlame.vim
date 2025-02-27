" CTRLGGitBlame - Append git blame information to the output of <C-g>
" Maintainer:   Andreas Louv <andreas@louv.dk>
" Date:         01 Apr 2022

function! CTRLGGitBlame#print(cmd) abort
  let status = execute("norm! " . a:cmd)
  let status = substitute(status, '^\_s*', '', '')
  let status = status . ' ' . s:render_blame()

  echo status
endfunction

function! s:render_blame() abort
  let blame = s:blame_line(expand('%'), line('.'))
  if blame['sha'] == 'fatal:'
    return ''
  endif

  if blame['sha'] == '0000000000000000000000000000000000000000'
    return 'Not Committed Yet'
  endif

  " abcdef00 (Author Name 4 hours ago) summary
  let short_sha = s:get_short_sha(expand('%'), blame['sha'])
  let relative_time = s:get_relative_time(blame['committer-time'], blame['committer-tz'])

  let @c = short_sha
  return printf('%s (%s %s) %s', short_sha, blame['author'], relative_time, blame['summary'])
endfunction

function! s:blame_line(file, line) abort
  let blame = {}

  let blame_cmd = printf('git -C %s blyat -L%d,%d -p %s',
        \ fnamemodify(a:file, ':p:h:S'),
        \ a:line,
        \ a:line,
        \ fnamemodify(a:file, ':p:S')
        \ )
  let lines = systemlist(blame_cmd)
  let blame['sha'] = split(lines[0], ' ')[0]
  for line in lines[1:]
    let parts = split(line, ' ')
    if parts[0] !~ '^\s*$'
      let blame[parts[0]] = join(parts[1:], ' ')
    endif
  endfor

  return blame
endfunction

function! s:get_short_sha(file, ref)
    let cmd = printf('git -C %s rev-parse --short %s',
          \ fnamemodify(a:file, ':p:h:S'),
          \ shellescape(a:ref)
          \ )
    let short_sha = systemlist(cmd)[0]
    return short_sha
endfunction

function! s:get_relative_time(time, tz) abort
  let localtime = localtime()
  let tz_time = s:parse_tz(a:tz)
  let tz_local = s:parse_tz(strftime('%z', localtime))

  let diff = (localtime+tz_local) - (a:time+tz_time)

  let minsec = 60
  let housec = minsec * 60
  let daysec = housec * 24
  let monsec = daysec * 30
  let yeasec = daysec * 365

  if diff < minsec
    return (diff) . ' seconds ago'
  endif

  if diff < housec
    return (diff/minsec) . ' minutes ago'
  endif

  if diff < daysec
    return (diff/housec) . ' hours ago'
  endif

  if diff < monsec
    return (diff/daysec) . ' days ago'
  endif

  if diff < yeasec
    return (diff/monsec) . ' months ago'
  endif

  if diff % yeasec < monsec
    return (diff/yeasec) . ' years ago'
  endif

  return (diff/yeasec) . ' years, ' . ((diff%yeasec)/monsec) .' months ago'
endfunction

function! s:parse_tz(tz) abort
  let [_, pm, hours, minutes; _] = matchlist(a:tz, '\([-+]\)\(\d\d\)\(\d\d\)')
  return hours * 60 + minutes * 1 * (pm == "+" ? 1 : -1)
endfunction

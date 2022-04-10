function! s:build_base_url(remote_url) abort
  for [domain, info] in items(g:gina#command#browse#translation_patterns)
    for pattern in info[0]
      let pattern = substitute(pattern, '\C' . '%domain', domain, 'g')
      if a:remote_url =~# pattern
        let repl = 'https://\1/\2/\3'
        return substitute(a:remote_url, '\C' . pattern, repl, 'g')
      endif
    endfor
  endfor
  return ''
endfunction

function! s:get_default_branch() abort
    let l:refs = split(system('git symbolic-ref refs/remotes/origin/HEAD'), '/')
    return trim(l:refs[len(l:refs)-1])
endfunction

function! s:echo_err_message(message) abort
  echohl Error
  echo a:message
  echohl None
endfunction

function! s:get_pr_url_with_github_commit(commit_hash) abort
  let l:message = system(printf("git log --oneline -n 1 --format=%%s %s", a:commit_hash))
  if len(l:message) == 0
    call s:echo_err_message('can not find PR commit')
    return
  endif
  let l:message = trim(split(l:message, '\n')[0])

  let l:match = matchstrpos(l:message, '(#\d\+)$')
  let l:pr = ''
  if l:match[1] != -1
    let l:pr = l:match[0][2:len(l:match[0])-2]
  else
    let l:main_branch = s:get_default_branch()
    let l:message = system(printf('git log --merges --oneline --reverse --ancestry-path --format=%%s %s...%s | head -n 1', a:commit_hash, l:main_branch))
    let l:match = matchstrpos(l:message, '^Merge pull request #\d\+')
    echomsg l:message
    if l:match[1] == -1
      call s:echo_err_message('can not find PR commit')
      return
    endif

    let l:pr = l:match[0][len('Merge pull request #'):]
  endif
  let l:remote_url = trim(system('git remote get-url origin'))
  let l:url = s:build_base_url(l:remote_url)
  if l:url == ''
    call s:echo_err_message('can not find origin url')
    return
  endif

  return printf('%s/pull/%s', l:url, l:pr)
endfunction

function! s:get_pr_url_with_gh_cli(commit_hash)
  let l:query =<< END
query($owner: String!, $name: String!, $commitHash: String!) {
  repository(owner: $owner, name: $name) {
    object(expression: $commitHash) {
      ... on Commit {
        associatedPullRequests(first:1) {
          edges {
            node {
              url
            }
          }
        }
      }
    }
  }
}
END
  let l:response = system("gh api graphql -F owner='{owner}' -F name='{repo}' -F commitHash='" . a:commit_hash . "' -f query='" . join(l:query, "\n") . "'")
  let l:response_json = json_decode(l:response)
  if has_key(l:response_json, 'errors')
    echoerr l:response_json['errors'][0]['message']
    return ''
  endif
  let l:url = json_decode(l:response)['data']['repository']['object']['associatedPullRequests']['edges'][0]['node']['url']
  return l:url
endfunction

function! gina_openpr#openpr() abort
  let l:info = gina#action#candidates()
  if type(l:info) != 3
    call s:echo_err_message('You should run this command after :Gina blame')
    return
  endif

  let l:info = get(l:info, 0, {'rev': ''})
  let l:commit_hash = get(l:info, 'rev', '')
  if len(l:commit_hash) == 0
    call s:echo_err_message('can not find commit_hash')
    return
  endif

  let l:remote_url = trim(system('git remote get-url origin'))
  let l:base_url = s:build_base_url(l:remote_url)
  if l:base_url == ''
    call s:echo_err_message('can not find origin url')
    return
  endif

  if l:base_url[0:len("https://github.com")-1] ==# "https://github.com"
    if executable("gh")
      call gina#util#open(s:get_pr_url_with_gh_cli(l:commit_hash))
      return
    endif
    call gina#util#open(s:get_pr_url_with_github_commit(l:commit_hash))
  endif
endfunction

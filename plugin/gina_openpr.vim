if exists('g:loaded_gina_openpr')
  finish
endif
let g:loaded_gina_openpr = 1

command! -nargs=0 GinaOpenPr call gina_openpr#openpr()

Sys.setlocale('LC_CTYPE','Korean_Korea.utf8')
roxygen2::roxygenise('verification/package-smoke/jjstat',roclets=c('rd','namespace'))
# Run from either the integration directory or the parent standalone directory.
root <- if (dir.exists('jjstat_integration/R')) normalizePath('jjstat_integration') else normalizePath('.')
modules <- file.path(root,'R',c('ai_clients.R','ai_control.R','ai_settings.R','ai_chat.R','ai_providers.R','ai_windows.R','ai_web.R'))
stopifnot(all(file.exists(modules)))
text <- unlist(lapply(modules,readLines,encoding='UTF-8',warn=FALSE))
writeLines(enc2utf8(text),file.path(dirname(root),'ai_clients.R'),useBytes=TRUE)
cat('Updated standalone ai_clients.R from integration modules\n')

for(file in list.files('R',pattern='[.]R$',full.names=TRUE)) source(file,encoding='UTF-8')
for(provider in c('ollama','lmstudio','lemonade','aistudio')) stopifnot(identical(formals(get(provider))$stream,TRUE),identical(formals(get(provider))$viewer,TRUE))
stopifnot(is.function(ai_stop))
cat('PASS: public Viewer, stream defaults and stop function\n')

library(jjstat)
stopifnot(identical(formals(lmstudio)$viewer, TRUE), identical(formals(lemonade)$viewer, TRUE))
assets <- jjstat:::.ai_math_dir()
stopifnot(file.exists(file.path(assets,'katex.min.js')),file.exists(file.path(assets,'fonts')))
for(provider in c('ollama','lmstudio','aistudio','lemonade')) {
  stopifnot(is.function(getExportedValue('jjstat',provider)),is.function(getExportedValue('jjstat',paste0(provider,'_setting'))))
}
lemonade_setting(port=18000,model='test-model',open=FALSE)
stopifnot(identical(ai_settings('lemonade')$base_url,'http://127.0.0.1:18000/api/v1'))
cat('PASS: installed package exports, Viewer defaults, asset paths and settings\n')
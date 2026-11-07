Sys.setlocale('LC_CTYPE','Korean_Korea.utf8')
source('ai_clients.R',encoding='UTF-8')
print(tcltk::tkinsert)
print(getS3method('as.character','tclVar',optional=TRUE))
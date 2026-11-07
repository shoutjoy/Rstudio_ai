Sys.setlocale('LC_CTYPE','Korean_Korea.utf8')
source('ai_clients.R',encoding='UTF-8')
top<-lmstudio_window(data.frame(group=c('A','B'),mean=c(3.2,2.8)),model='google/gemma-4-e4b',base_url='http://127.0.0.1:5678',
 prompt='표를 포함하여 두 행의 값을 한국어 세 문장으로 간단히 요약해줘.',max_tokens=512L,auto_continue=FALSE,timeout=60L)
tcltk::tkwm.title(top,'JJSTAT Visual Live Test')
cat('VISUAL_WINDOW_READY\n')
while(as.integer(tcltk::tclvalue(tcltk::tcl('winfo','exists',top)))==1L){tcltk::tcl('update');Sys.sleep(0.02)}
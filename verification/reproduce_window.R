Sys.setlocale('LC_CTYPE','Korean_Korea.utf8')
source('ai_clients.R',encoding='UTF-8')
f<-tempfile(fileext='.js')
writeLines("const s=require('http').createServer((req,res)=>{req.resume();req.on('end',()=>{res.writeHead(200,{'Content-Type':'text/event-stream'});res.write('data: '+JSON.stringify({choices:[{delta:{content:'WINDOW_STREAM_OK'}}]})+'\\n\\n');setTimeout(()=>res.end('data: [DONE]\\n\\n'),300)})});s.listen(0,'127.0.0.1',()=>console.log(s.address().port));",f)
p<-processx::process$new('node',f,stdout='|',stderr='|')
tryCatch({
 port<-character();for(i in 1:100){p$poll_io(100);port<-p$read_output_lines();if(length(port))break}
 lmstudio_setting(base_url=paste0('http://127.0.0.1:',port),model='mock',open=FALSE)
 top<-lmstudio_window(data.frame(value=c(1,2)),prompt='window question')
 tree<-function(w){kids<-as.character(tcltk::tcl('winfo','children',w));c(w,unlist(lapply(kids,tree)))}
 widgets<-tree(top$ID);cls<-vapply(widgets,function(w)tcltk::tclvalue(tcltk::tcl('winfo','class',w)),character(1))
 button<-widgets[cls=='Button'];text<-widgets[cls=='Text']
 tcltk::tcl(button,'invoke')
 print(tcltk::tclvalue(tcltk::tcl(text,'get','1.0','end')))
 tcltk::tkdestroy(top)
},finally={if(p$is_alive())p$kill();unlink(f)})
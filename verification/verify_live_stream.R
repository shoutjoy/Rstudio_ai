Sys.setlocale('LC_CTYPE','Korean_Korea.utf8')
source('ai_clients.R',encoding='UTF-8')
start<-proc.time()[['elapsed']];first_body<-NULL;reasoning_at<-NULL
view<-list(push=function(x)NULL,status=function(x){if(is.null(reasoning_at)&&grepl('추론 중',x,fixed=TRUE))reasoning_at<<-proc.time()[['elapsed']]-start})
error<-NULL
answer<-tryCatch(.ai_send_once('lmstudio',prompt='Reply with OK only.',model='google/gemma-4-12b-qat',
 base_url='http://127.0.0.1:5678',stream=TRUE,viewer=FALSE,.view=view,echo=FALSE,progress=FALSE,
 max_tokens=128L,timeout=60L,retries=0L,on_chunk=function(x){if(is.null(first_body))first_body<<-proc.time()[['elapsed']]-start}),
 error=function(e){error<<-conditionMessage(e);NULL})
cat('Live LM Studio stream: reasoning stage seconds =',reasoning_at,'; first body seconds =',first_body,
 '; elapsed =',proc.time()[['elapsed']]-start,'; answer received =',!is.null(answer),'\n')
if(!is.null(error))cat('Result:',error,'\n')
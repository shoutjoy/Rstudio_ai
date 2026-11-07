
# A tiny local stop endpoint serviced by the existing nonblocking receive loop.
# It never reads/writes user files and accepts only a per-viewer random URL token.
.ai_control <- function() {
  listener <- NULL
  first <- 35000L + as.integer((as.numeric(Sys.time())*1000+Sys.getpid()) %% 20000)
  for(port in first+0:30) {
    listener <- tryCatch(serverSocket(port),error=function(e) NULL)
    if(!is.null(listener)) break
  }
  if(is.null(listener)) stop('Cannot open the local response-stop endpoint.')
  token <- paste0(basename(tempfile()),basename(tempfile()))
  path <- paste0('/stop/',token)
  stopped <- FALSE; closed <- FALSE; clients <- list()
  close_client <- function(client) try(close(client$con),silent=TRUE)
  poll <- function() {
    if(closed) return(invisible(NULL))
    for(i in seq_len(4L)) {
      if(!socketSelect(list(listener),timeout=0)) break
      con <- socketAccept(listener,blocking=FALSE,open='r+b',timeout=0.01)
      if(length(clients)>=8L) {try(close(con),silent=TRUE);next}
      clients[[length(clients)+1L]] <<- list(con=con,data=raw(),opened=proc.time()[['elapsed']])
    }
    keep <- list()
    for(client in clients) {
      if(proc.time()[['elapsed']]-client$opened>2) {close_client(client);next}
      if(socketSelect(list(client$con),timeout=0)) {
        bytes <- tryCatch(readBin(client$con,'raw',4096L),error=function(e) raw())
        client$data <- c(client$data,bytes)
        text <- tryCatch(rawToChar(client$data),error=function(e) NULL)
        if(is.null(text)) {close_client(client);next}
        if(length(client$data)>8192L) {close_client(client);next}
        if(grepl('\r\n\r\n',text,fixed=TRUE)) {
          line <- strsplit(text,'\r\n',fixed=TRUE)[[1L]][[1L]]
          valid <- identical(line,paste0('POST ',path,' HTTP/1.1')) || identical(line,paste0('POST ',path,' HTTP/1.0'))
          if(valid) stopped <<- TRUE
          body <- if(valid) '{"stopped":true}' else '{"error":"not found"}'
          response <- paste0('HTTP/1.1 ',if(valid) '200 OK' else '404 Not Found',
            '\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\nCache-Control: no-store',
            '\r\nConnection: close\r\nContent-Length: ',nchar(body,type='bytes'),'\r\n\r\n',body)
          try(writeBin(charToRaw(response),client$con),silent=TRUE)
          close_client(client);next
        }
      }
      keep[[length(keep)+1L]] <- client
    }
    clients <<- keep
    invisible(NULL)
  }
  shutdown <- function() {
    if(!closed) {closed <<- TRUE;for(client in clients)close_client(client);try(close(listener),silent=TRUE)}
    invisible(NULL)
  }
  list(url=paste0('http://127.0.0.1:',port,path),poll=poll,stopped=function()stopped,
       close=shutdown,is_open=function()!closed)
}
#' Stop the active AI response while retaining received text
#' @details The Viewer stop button and RStudio Esc/Stop are available during a call.
#' This function is useful in callbacks or a Tcl/Tk control; it cannot run from a busy console.
#' @return Whether an active request was marked for cancellation, invisibly.
#' @export
ai_stop <- function() {
  state <- .ai_state()
  if(!isTRUE(state$busy)) return(invisible(FALSE))
  state$cancel_requested <- TRUE
  invisible(TRUE)
}

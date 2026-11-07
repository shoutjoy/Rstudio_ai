# R AI clients | Ollama + LM Studio + Google AI Studio (Gemini)
# Recommended packages: install.packages(c('jsonlite','processx','commonmark','rstudioapi','later'))
# Standalone script: source('ai_clients.R', encoding='UTF-8')

.ai_require <- function() {
  for (p in c('jsonlite', 'processx')) {
    if (!requireNamespace(p, quietly = TRUE))
      stop('\ud328\ud0a4\uc9c0\uac00 \ud544\uc694\ud569\ub2c8\ub2e4: install.packages("', p, '")', call. = FALSE)
  }
}

.ai_curl <- function() {
  bin <- Sys.which(if (.Platform$OS.type == 'windows') 'curl.exe' else 'curl')
  if (!nzchar(bin)) stop('curl \uc2e4\ud589 \ud30c\uc77c\uc744 PATH\uc5d0\uc11c \ucc3e\uc9c0 \ubabb\ud588\uc2b5\ub2c8\ub2e4.', call. = FALSE)
  unname(bin)
}

.ai_text <- function(x, max_rows = 100L, max_chars = 30000L) {
  if (is.null(x)) return(NULL)
  if (is.data.frame(x)) {
    n <- nrow(x)
    small <- utils::head(x, as.integer(max_rows))
    v <- paste(utils::capture.output(utils::write.table(
      small, file = '', sep = '\t', row.names = FALSE,
      col.names = TRUE, quote = FALSE, na = 'NA'
    )), collapse = '\n')
    if (n > nrow(small)) v <- paste0(v, '\n[\uc804\uccb4 ', n, '\ud589 \uc911 ', nrow(small), '\ud589\ub9cc \uc804\uc1a1\ub428]')
  } else if (is.character(x) && length(x) == 1L) {
    v <- x
  } else if (is.matrix(x)) {
    v <- paste(utils::capture.output(print(x)), collapse = '\n')
  } else {
    v <- paste(utils::capture.output(print(x)), collapse = '\n')
  }
  if (nchar(v, type = 'chars') > max_chars)
    v <- paste0(substr(v, 1L, max_chars), '\n[\uc785\ub825 \uae38\uc774 \uc81c\ud55c\uc73c\ub85c \uc77c\ubd80 \uc0dd\ub7b5\ub428]')
  v
}

.ai_system <- paste(
  '\ub2f9\uc2e0\uc740 \ud55c\uad6d\uc5b4\ub85c \ub2f5\ud558\ub294 \ud1b5\uacc4\ud559 \ubc0f \ud559\uc220 \uc5f0\uad6c \uc870\uad50\uc774\ub2e4.',
  '\uc81c\uacf5\ub41c \ucd9c\ub825 \uacb0\uacfc\ub97c \uadfc\uac70\ub85c \ud574\uc11d\ud558\uace0, \ub370\uc774\ud130\uc5d0 \uc5c6\ub294 \uc218\uce58\ub098 \uac80\uc815 \uacb0\uacfc\ub97c \ub9cc\ub4e4\uc5b4\ub0b4\uc9c0 \uc54a\ub294\ub2e4.',
  'p=0.00\uc740 \ubc18\uc62c\ub9bc \uac12\uc774\ubbc0\ub85c p=0\uc774\ub77c\uace0 \ub2e8\uc815\ud558\uc9c0 \uc54a\ub294\ub2e4.',
  '\uc6d0\uc790\ub8cc\uac00 \uc5c6\uc73c\uba74 \ud6a8\uacfc\ud06c\uae30, \uc2e0\ub8b0\uad6c\uac04, \uac00\uc815\uac80\uc815 \uacb0\uacfc\ub97c \uc784\uc758\ub85c \uacc4\uc0b0\ud558\uc9c0 \uc54a\ub294\ub2e4.',
  '\ub450 \uc9d1\ub2e8\ubcc4 \ud589\uc5d0 \ub3d9\uc77c\ud55c \uac80\uc815 \ud1b5\uacc4\ub7c9\uc774 \ubc18\ubcf5\ub418\uba74 \ud55c \uac1c\uc758 \uac80\uc815\uc73c\ub85c \ud574\uc11d\ud55c\ub2e4.',
  't \uac12 \ubd80\ud638\uc758 \ubc29\ud5a5\uc740 \uc9d1\ub2e8 \uc21c\uc11c\uac00 \uba85\ud655\ud558\uc9c0 \uc54a\uc73c\uba74 \ub2e8\uc815\ud558\uc9c0 \uc54a\ub294\ub2e4.',
  '\ucd94\ub860\uc758 \ud55c\uacc4\uc640 \ubcf4\uace0 \uac00\ub2a5\ud55c \uacb0\uacfc\ub97c \uad6c\ubd84\ud55c\ub2e4.'
)

.ai_prompt <- function(data, prompt, max_rows, max_chars) {
  if (is.null(prompt) && is.character(data) && length(data) == 1L) {
    prompt <- data
    data <- NULL
  }
  if (!is.character(prompt) || length(prompt) != 1L || is.na(prompt) ||
      !nzchar(trimws(prompt))) {
    stop("\uc9c8\ubb38\uc744 \uc785\ub825\ud558\uc2ed\uc2dc\uc624. \uc608: lmstudio('\uc548\ub155\ud558\uc138\uc694') \ub610\ub294 df %>% lmstudio('\ud574\uc11d\ud574\uc918')", call. = FALSE)
  }
  dt <- .ai_text(data, max_rows, max_chars)
  user <- if (is.null(dt)) prompt else
    paste0('[\uc694\uccad]\n', prompt, '\n\n[\ubd84\uc11d \ub370\uc774\ud130]\n', dt)
  list(user = user, raw_prompt = prompt)
}

# Resolve assets when sourced, so changing the working directory remains safe.
.ai_math_assets <- local({
  files <- vapply(sys.frames(), function(f) {
    if (is.null(f$ofile)) '' else as.character(f$ofile)[1L]
  }, character(1))
  files <- files[nzchar(files)]
  base <- if (length(files)) dirname(normalizePath(utils::tail(files, 1L),
    winslash = '/', mustWork = FALSE)) else getwd()
  file.path(base, 'assets', 'katex')
})

.ai_math_dir <- function() {
  env <- environment(.ai_math_dir)
  if (isNamespace(env))
    return(system.file('assets', 'katex', package = getNamespaceName(env), mustWork = TRUE))
  if (dir.exists(.ai_math_assets)) return(.ai_math_assets)
  normalizePath(file.path(.ai_math_assets, '..', '..', '..', 'inst', 'assets', 'katex'),
                winslash = '/', mustWork = TRUE)
}

.ai_html_escape <- function(x) {
  for (pair in list(c('&', '&amp;'), c('<', '&lt;'), c('>', '&gt;'),
                    c('"', '&quot;'), c("'", '&#39;')))
    x <- gsub(pair[1L], pair[2L], x, fixed = TRUE)
  x
}

# Accept paired ** delimiters regardless of adjacent Korean text or punctuation.
# Code fences/spans, indented code, HTML tags and escaped stars retain their source.
.ai_relaxed_bold <- function(x) {
  protected <- "(?m:^[ ]{0,3}(?<fence>`{3,}|~{3,})[^\\n]*\\n[\\s\\S]*?^[ ]{0,3}\\k<fence>[~`]*[ \\t]*(?:\\n|$))|(?m:^[ ]{0,3}(?:`{3,}|~{3,})[^\\n]*(?:\\n[\\s\\S]*)?\\z)|(?m:^(?: {4}|\\t)[^\\n]*(?:\\n|$))|(?<ticks>`+)[^`]*?(?:`(?!\\k<ticks>)[^`]*)*?\\k<ticks>(?!`)|<[^>\\n]+>|\\\\."
  pattern <- paste0("(?:",protected,")(*SKIP)(*F)|(?<![\\\\*])\\*\\*(?!\\*)[^\\r\\n]+?\\*\\*(?!\\*)")
  matches <- gregexpr(pattern,x,perl=TRUE)[[1L]]
  if(matches[1L]<0L)return(list(text=x,replacements=character()))
  sizes <- attr(matches,'match.length');parts <- character();cursor <- 1L;replacements <- character()
  marker <- 'AISTRONGPLACEHOLDER';while(grepl(marker,x,fixed=TRUE))marker<-paste0(marker,'X')
  for(i in seq_along(matches)) {
    start <- matches[i];end <- start+sizes[i]-1L
    if(start>cursor)parts<-c(parts,substr(x,cursor,start-1L))
    inside <- substr(x,start+2L,end-2L)
    if(nzchar(trimws(inside))) {
      id<-paste0(marker,length(replacements)+1L,'END')
      rendered<-commonmark::markdown_html(inside,extensions='strikethrough')
      rendered<-sub('^<p>','',rendered);rendered<-sub('</p>\\n$','',rendered)
      replacements[id]<-paste0('<strong>',rendered,'</strong>');parts<-c(parts,id)
    }else parts<-c(parts,substr(x,start,end))
    cursor <- end+1L
  }
  if(cursor<=nchar(x))parts<-c(parts,substr(x,cursor,nchar(x)))
  list(text=paste0(parts,collapse=''),replacements=replacements)
}

# Protect TeX before commonmark consumes backslashes, underscores and table pipes.
# Code fences, code spans, indented code and HTML tags take precedence over math.
.ai_markdown_html <- function(x) {
  if (!requireNamespace('commonmark', quietly = TRUE))
    stop('Viewer Markdown \ub80c\ub354\ub9c1\uc5d0 commonmark \ud328\ud0a4\uc9c0\uac00 \ud544\uc694\ud569\ub2c8\ub2e4: install.packages("commonmark")', call. = FALSE)
  pattern <- paste0(
    '(?m:^[ ]{0,3}(`{3,}|~{3,})[^\\n]*\\n[\\s\\S]*?^[ ]{0,3}\\1[~`]*[ \\t]*(?:\\n|$))',
    '|(?m:^[ ]{0,3}(?:`{3,}|~{3,})[^\\n]*(?:\\n[\\s\\S]*)?\\z)',
    '|(?m:^(?: {4}|\\t)[^\\n]*(?:\\n|$))',
    '|(`+)[^`]*?(?:`(?!\\2)[^`]*)*?\\2(?!`)',
    '|<[^>\\n]+>',
    '|\\\\\\\\|\\\\\\$',
    '|\\$\\$(?:[^$]|\\$(?!\\$))+?\\$\\$',
    '|\\\\\\[[\\s\\S]*?\\\\\\]',
    '|\\\\\\([^\\n]*?\\\\\\)',
    '|(?<![\\w\\\\$])\\$(?![\\s$])(?:\\\\[^\\n]|[^$\\n\\\\])*?(?<!\\s)\\$(?![\\w$])'
  )
  matches <- gregexpr(pattern, x, perl = TRUE)[[1L]]
  replacements <- character()
  if (matches[1L] != -1L) {
    lengths <- attr(matches, 'match.length')
    parts <- character()
    cursor <- 1L
    # Use a marker absent from the response to avoid replacing user text.
    marker <- 'AIMATHPLACEHOLDER'
    while (grepl(marker, x, fixed = TRUE)) marker <- paste0(marker, 'X')
    for (i in seq_along(matches)) {
      token <- substr(x, matches[i], matches[i] + lengths[i] - 1L)
      display <- startsWith(token, '$$') || startsWith(token, '\\[')
      math <- display || startsWith(token, '\\(') ||
        (startsWith(token, '$') && !startsWith(token, '$$'))
      if (matches[i] > cursor) parts <- c(parts, substr(x, cursor, matches[i] - 1L))
      if (math) {
        width <- if (startsWith(token, '$') && !display) 1L else 2L
        tex <- substr(token, width + 1L, nchar(token) - width)
        id <- paste0(marker, length(replacements) + 1L, 'END')
        replacements[id] <- paste0('<span class="ai-math" data-display="',
          if (display) 'true' else 'false', '" data-tex="', .ai_html_escape(tex),
          '">', .ai_html_escape(token), '</span>')
        parts <- c(parts, id)
      } else parts <- c(parts, token)
      cursor <- matches[i] + lengths[i]
    }
    if (cursor <= nchar(x)) parts <- c(parts, substr(x, cursor, nchar(x)))
    x <- paste0(parts, collapse = '')
  }
  bold <- .ai_relaxed_bold(x)
  html <- commonmark::markdown_html(bold$text, extensions = c('table', 'strikethrough'))
  for(id in names(bold$replacements))html<-gsub(id,bold$replacements[[id]],html,fixed=TRUE)
  for (id in names(replacements)) html <- gsub(id, replacements[[id]], html, fixed = TRUE)
  html
}

# Live Markdown Viewer. HTML is isolated in a sandboxed iframe (scripts disabled).
.ai_viewer <- function(title, question) {
  if (!requireNamespace('rstudioapi', quietly = TRUE) ||
      !rstudioapi::isAvailable())
    stop('viewer=TRUE\ub294 RStudio\uc5d0\uc11c \uc2e4\ud589\ud574\uc57c \ud569\ub2c8\ub2e4. install.packages("rstudioapi")\ub97c \ud655\uc778\ud558\uc2ed\uc2dc\uc624.', call. = FALSE)
  if (!requireNamespace('commonmark', quietly = TRUE))
    stop('Markdown \ub80c\ub354\ub9c1\uc5d0 commonmark\uac00 \ud544\uc694\ud569\ub2c8\ub2e4: install.packages("commonmark")', call. = FALSE)
  dir <- tempfile('r_ai_viewer_')
  dir.create(dir, recursive = TRUE)
  .ai_math_assets <- .ai_math_dir()
  required <- file.path(.ai_math_assets, c('katex.min.js', 'katex.min.css', 'fonts'))
  if (!all(file.exists(required)))
    stop('\uc218\uc2dd \ub80c\ub354\ub9c1 \ud30c\uc77c\uc774 \uc5c6\uc2b5\ub2c8\ub2e4. ai_clients.R\uacfc \ud568\uaed8 assets/katex \ud3f4\ub354\ub97c \ubcf4\uad00\ud558\uace0 source()\ub85c \ub2e4\uc2dc \ubd88\ub7ec\uc624\uc2ed\uc2dc\uc624.', call. = FALSE)
  if (!file.copy(.ai_math_assets, dir, recursive = TRUE))
    stop('Viewer \uc218\uc2dd \ub80c\ub354\ub9c1 \ud30c\uc77c\uc744 \ubcf5\uc0ac\ud558\uc9c0 \ubabb\ud588\uc2b5\ub2c8\ub2e4.', call. = FALSE)
  index <- file.path(dir, 'index.html')
  state <- file.path(dir, 'state.js')
  ui <- .ai_ui_dir()
  if(!file.copy(ui,dir,recursive=TRUE)) stop('Cannot copy Viewer UI assets.')
  file.copy(file.path(ui,'index.html'),index,overwrite=TRUE)
  writeLines('window.APP_CONFIG={mode:"viewer"};',file.path(dir,'config.js'))
  accumulated <- ''
  rendered <- ''; rendered_text <- NULL
  control <- .ai_control()
  console_url <- .ai_console_bridge()
  status <- '\uc694\uccad \uc900\ube44 \uc911'
  last_write <- 0
  save <- function(force = FALSE) {
    now <- as.numeric(Sys.time())
    if (!force && now - last_write < 0.1) return(invisible(NULL))
    last_write <<- now
    if(!identical(rendered_text,accumulated)) {
      rendered <<- .ai_markdown_html(accumulated); rendered_text <<- accumulated
    }
    js <- paste0('window.__ai_snapshot = ',
                 as.character(jsonlite::toJSON(list(question = question,
                   markdown = accumulated, html = rendered, status = status, console_url = console_url, stop_url = control$url, can_stop = control$is_open()), auto_unbox = TRUE)), ';')
    tmp <- tempfile('snapshot_', tmpdir = dir, fileext = '.js')
    writeLines(js, tmp, useBytes = TRUE)
    if (file.exists(state)) unlink(state)
    if (!file.rename(tmp, state)) {
      file.copy(tmp, state, overwrite = TRUE)
      unlink(tmp)
    }
    invisible(NULL)
  }
  save(force = TRUE)
  rstudioapi::viewer(index)
  push <- function(text) {
    first <- !nzchar(accumulated)
    accumulated <<- paste0(accumulated, text)
    status <<- '\uc0dd\uc131 \uc911...'
    save(force = first)
    invisible(NULL)
  }
  set_status <- function(value) {
    status <<- as.character(value)
    save(force = TRUE)
    invisible(NULL)
  }
  shutdown <- function() {control$close();save(force=TRUE);invisible(NULL)}
  list(push = push, status = set_status, path = index,poll=control$poll,
       is_stopped=control$stopped,close=shutdown)
}

.ai_popup <- function(title) {
  if (!capabilities('tcltk') || !requireNamespace('tcltk', quietly = TRUE))
    stop('\ucc3d \uae30\ub2a5\uc740 Tcl/Tk \uc9c0\uc6d0 R \ud658\uacbd\uc5d0\uc11c\ub9cc \uc774\uc6a9 \uac00\ub2a5\ud569\ub2c8\ub2e4.', call. = FALSE)
  tk <- asNamespace('tcltk')
  top <- tk$tktoplevel()
  tk$tkwm.title(top, title)
  tk$tkwm.geometry(top, '980x680')
  frame <- tk$tkframe(top)
  sc <- tk$tkscrollbar(frame)
  box <- tk$tktext(frame, wrap = 'word', background = '#141b25',
                   foreground = '#eef3fa', insertbackground = 'white',
                   yscrollcommand = function(...) tk$tkset(sc, ...))
  tk$tkconfigure(sc, command = function(...) tk$tkyview(box, ...))
  tk$tkpack(sc, side = 'right', fill = 'y')
  tk$tkpack(box, side = 'left', fill = 'both', expand = TRUE)
  tk$tkpack(frame, fill = 'both', expand = TRUE)
  tk$tkconfigure(box, state = 'disabled')
  push <- function(s) {
    try({
      tk$tkconfigure(box, state = 'normal')
      tk$tkinsert(box, 'end', s)
      tk$tksee(box, 'end')
      tk$tkconfigure(box, state = 'disabled')
      tk$tcl('update')
    }, silent = TRUE)
    invisible(NULL)
  }
  list(top = top, push = push)
}

.ai_parse <- function(event, provider, stream, show, finish = function(reason) NULL, usage = function(info) NULL, activity = function(stage) NULL) {
  if (stream && provider != 'ollama') {
    if (!startsWith(event, 'data:')) return(FALSE)
    event <- trimws(substring(event, 6L))
    if (identical(event, '[DONE]')) return(TRUE)
  }
  if (!nzchar(trimws(event))) return(FALSE)
  obj <- tryCatch(jsonlite::fromJSON(event, simplifyVector = FALSE),
                  error = function(e) NULL)
  if (is.null(obj)) return(FALSE)
  if (!is.null(obj$error)) {
    msg <- if (is.list(obj$error)) obj$error$message else as.character(obj$error)
    if (is.null(msg)) msg <- 'API \uc624\ub958\uac00 \ubc1c\uc0dd\ud588\uc2b5\ub2c8\ub2e4.'
    stop(provider, ': ', msg, call. = FALSE)
  }
  usage(.ai_usage(obj,provider))
  reasoning <- FALSE
  has_text <- function(x) is.character(x) && any(nzchar(x))
  if (identical(provider, 'ollama')) {
    reasoning <- has_text(obj$message$thinking)
    content <- obj$message$content
    done <- isTRUE(obj$done)
    if (done) finish(if (is.null(obj$done_reason)) 'stop' else obj$done_reason)
  } else if (provider %in% c('lmstudio', 'lemonade')) {
    ch <- if (length(obj$choices)) obj$choices[[1L]] else NULL
    message <- if (stream) ch$delta else ch$message
    reasoning <- has_text(message$reasoning_content) || has_text(message$reasoning)
    content <- message$content
    done <- !is.null(ch$finish_reason)
    if (done) finish(ch$finish_reason)
  } else {
    parts <- if (length(obj$candidates)) obj$candidates[[1L]]$content$parts else NULL
    reasoning <- any(vapply(parts,function(p) isTRUE(p$thought),logical(1)))
    parts <- Filter(function(p) !isTRUE(p$thought),parts)
    content <- if (length(parts)) {
      paste(vapply(parts, function(p) if (is.character(p$text)) p$text else '',
                   character(1)), collapse = '')
    } else NULL
    done <- length(obj$candidates) > 0L && !is.null(obj$candidates[[1L]]$finishReason)
    if (done) finish(obj$candidates[[1L]]$finishReason)
  }
  activity(if(has_text(content)) 'content' else if(reasoning) 'reasoning' else 'event')
  if (is.character(content) && length(content)) show(paste(content, collapse = ''))
  isTRUE(done)
}


# Normalize provider counters without estimating tokens from character counts.
.ai_usage <- function(obj, provider) {
  number <- function(...) {
    for (x in list(...)) if (is.numeric(x) && length(x)==1L && is.finite(x) && x>=0) return(as.numeric(x))
    NULL
  }
  if (provider=='ollama') {
    seconds <- number(obj$eval_duration)
    if (!is.null(seconds) && seconds>0) seconds <- seconds/1e9 else seconds <- NULL
    result <- list(input_tokens=number(obj$prompt_eval_count),output_tokens=number(obj$eval_count),
                   generation_seconds=seconds)
  } else if (provider=='aistudio') {
    u <- obj$usageMetadata
    result <- list(input_tokens=number(u$promptTokenCount),output_tokens=number(u$candidatesTokenCount),
                   total_tokens=number(u$totalTokenCount),thinking_tokens=number(u$thoughtsTokenCount))
  } else {
    u <- obj$usage; timing <- obj$timings; stats <- obj$stats
    seconds <- number(timing$predicted_ms)
    if (!is.null(seconds) && seconds>0) seconds <- seconds/1000 else seconds <- NULL
    result <- list(input_tokens=number(u$prompt_tokens,u$input_tokens),
      output_tokens=number(u$completion_tokens,u$output_tokens),total_tokens=number(u$total_tokens),
      server_rate=number(timing$predicted_per_second,stats$tokens_per_second),generation_seconds=seconds)
  }
  result[!vapply(result,is.null,logical(1))]
}
.ai_finalize_metrics <- function(metrics,elapsed) {
  metrics$elapsed_seconds <- elapsed
  if (!is.null(metrics$server_rate)) {
    metrics$tokens_per_second <- metrics$server_rate; metrics$rate_source <- 'server'
  } else if (!is.null(metrics$output_tokens) && !is.null(metrics$generation_seconds) && metrics$generation_seconds>0) {
    metrics$tokens_per_second <- metrics$output_tokens/metrics$generation_seconds; metrics$rate_source <- 'server'
  } else if (!is.null(metrics$output_tokens) && elapsed>0) {
    metrics$tokens_per_second <- metrics$output_tokens/elapsed; metrics$rate_source <- 'request_average'
  }
  metrics
}
.ai_metric_text <- function(metrics,elapsed=0,final=FALSE) {
  if(is.null(metrics)) metrics <- list()
  missing <- if(final) '\ubbf8\uc81c\uacf5' else '--'
  count <- function(x) if(is.null(x)) missing else paste0(formatC(x,format='f',digits=0,big.mark=','),' tok')
  m <- .ai_finalize_metrics(metrics,elapsed)
  rate <- if(is.null(m$tokens_per_second)) paste0(missing,' tok/s') else
    paste0(sprintf('%.1f tok/s',m$tokens_per_second),if(m$rate_source=='request_average') ' (\uc694\uccad \ud3c9\uade0)' else '')
  output <- count(m$output_tokens)
  if(is.null(m$output_tokens) && !is.null(m$output_chunks) && m$output_chunks>0) {
    output <- paste0('\u2248',formatC(m$output_chunks,format='f',digits=0,big.mark=','),' tok (\ucd94\uc815)')
    interval <- elapsed - m$first_chunk_seconds
    if(m$output_chunks>1 && is.finite(interval) && interval>=0.1)
      rate <- paste0('\u2248',sprintf('%.1f tok/s',(m$output_chunks-1)/interval),' (\uc218\uc2e0 \ucd94\uc815)')
  }
  paste0('Context = ',count(m$input_tokens),' | Output = ',output,' | ',rate)
}
# Completion length is unknown: percentages below 100 are explicitly estimates.
.ai_console_progress <- function(enabled = TRUE, metrics = function() list()) {
  started <- proc.time()[['elapsed']]
  last_draw <- -Inf
  percent <- 0L
  closed <- FALSE
  previous_width <- 0L;last_stage <- NULL
  elapsed_time <- function() max(0,proc.time()[['elapsed']] - started)
  update <- function(stage = '\uc11c\ubc84 \uc751\ub2f5 \ub300\uae30', receiving = FALSE, finish = FALSE,
                     failed = FALSE, force = FALSE) {
    if (!isTRUE(enabled) || closed) return(invisible(NULL))
    elapsed <- elapsed_time()
    if (!force && !finish && !failed && elapsed - last_draw < 0.5) return(invisible(NULL))
    estimate <- if (receiving) 35 + 60 * (1 - exp(-elapsed / 90)) else 5 + 25 * (1 - exp(-elapsed / 30))
    percent <<- if (finish) 100L else max(percent, min(95L, as.integer(estimate)))
    filled <- as.integer(percent / 5)
    bar <- paste0(strrep('=', filled), strrep(' ', 20L - filled))
    label <- if (finish) '\uc644\ub8cc' else if (failed) stage else paste0(stage, ' \u00b7 \ucd94\uc815')
    line1 <- sprintf('[AI] [%s] %3d%% | %s | %.1f\ucd08',bar,percent,label,elapsed)
    line2 <- paste0('| ',.ai_metric_text(metrics(),elapsed,final=finish || failed))
    redraw_both <- interactive() && isatty(stdout()) && Sys.getenv('RSTUDIO')!='1'
    if(previous_width>0L && redraw_both) {
      cat('\r\033[2K\033[1A\r\033[2K',line1,'\n',line2,sep='')
    } else if(previous_width==0L || finish || failed || !identical(last_stage,label)) {
      if(previous_width>0L) cat('\r',strrep(' ',previous_width),'\r',sep='')
      cat(line1,'\n',line2,sep='')
    } else cat('\r',line2,strrep(' ',max(0L,previous_width-nchar(line2,type='width'))),sep='')
    previous_width <<- nchar(line2,type='width');last_stage <<- label
    utils::flush.console()
    last_draw <<- elapsed
    if (finish || failed) { cat('\n'); closed <<- TRUE }
    invisible(NULL)
  }
  list(update = update, elapsed = elapsed_time)
}

.ai_send_once <- function(provider, data = NULL, prompt = NULL, model = NULL,
                     base_url = NULL, api_key = NULL,
                     stream = TRUE, window = FALSE, viewer = TRUE, echo = NULL,
                     on_chunk = NULL, system_prompt = .ai_system,
                     temperature = 0.2, max_tokens = 2048L,
                     max_rows = 100L, max_chars = 30000L,
                     timeout = 600L, retries = 3L, retry_wait = 2,
                     progress = isTRUE(viewer), history = NULL, .view = NULL, include_usage = TRUE, on_status = NULL) {
  .ai_require()
  if(!is.null(on_status) && !is.function(on_status)) stop('on_status must be a function.')
  if (is.null(echo)) echo <- !isTRUE(progress)
  if (!is.null(on_chunk) && !is.function(on_chunk)) stop('on_chunk\ub294 \ud568\uc218\uc5ec\uc57c \ud569\ub2c8\ub2e4.')
  query <- .ai_prompt(data, prompt, max_rows, max_chars)
  if (is.null(model) || !nzchar(model)) stop('\ubaa8\ub378 ID\uac00 \ud544\uc694\ud569\ub2c8\ub2e4.')
  if (identical(provider, 'aistudio')) {
    # API 키의 시작 문자/구분 기호는 검증하지 않는다.
    # 키의 실제 유효성 및 권한은 Google API 서버가 판단한다.
    if (is.null(api_key) || (is.character(api_key) && length(api_key) == 1L &&
                             !is.na(api_key) && !nzchar(trimws(api_key))))
      api_key <- Sys.getenv('GEMINI_API_KEY', '')
    if (!is.character(api_key) || length(api_key) != 1L ||
        is.na(api_key) || !nzchar(trimws(api_key)))
      stop('Google AI Studio API \ud0a4\ub97c \uc804\ub2ec\ud558\uac70\ub098 GEMINI_API_KEY \ud658\uacbd\ubcc0\uc218\uc5d0 \uc124\uc815\ud558\uc2ed\uc2dc\uc624.', call. = FALSE)
    # HTTP 헤더 및 curl 설정 파일의 줄바꿈 삽입만 차단한다.
    if (grepl('[[:cntrl:]]', api_key))
      stop('API \ud0a4\uc5d0 \uc904\ubc14\uafc8 \ub610\ub294 \uc81c\uc5b4\ubb38\uc790\uac00 \ud3ec\ud568\ub418\uc5b4 \uc788\uc2b5\ub2c8\ub2e4.', call. = FALSE)
    api_key <- trimws(api_key)
  }
  if (provider %in% c('lmstudio', 'lemonade')) {
    if (is.null(base_url)) base_url <- 'http://127.0.0.1:5678'
    url <- .ai_url(provider, base_url, 'chat/completions')
    payload <- list(model = model,
                    messages = c(list(list(role = 'system', content = system_prompt)),
                                 if (is.null(history)) list(list(role = 'user', content = query$user)) else history),
                    stream = isTRUE(stream), temperature = temperature,
                    max_tokens = as.integer(max_tokens))
    if (isTRUE(stream) && isTRUE(include_usage)) payload$stream_options <- list(include_usage=TRUE)
  } else if (identical(provider, 'ollama')) {
    if (is.null(base_url)) base_url <- 'http://127.0.0.1:11434'
    url <- paste0(sub('/+$', '', base_url), '/api/chat')
    payload <- list(model = model,
                    messages = c(list(list(role = 'system', content = system_prompt)),
                                 if (is.null(history)) list(list(role = 'user', content = query$user)) else history),
                    stream = isTRUE(stream),
                    options = list(temperature = temperature, num_predict = as.integer(max_tokens)))
  } else if (identical(provider, 'aistudio')) {
    if (is.null(base_url)) base_url <- 'https://generativelanguage.googleapis.com/v1beta'
    url <- paste0(sub('/+$', '', base_url), '/models/', model, ':',
                  if (isTRUE(stream)) 'streamGenerateContent?alt=sse' else 'generateContent')
    payload <- list(
      systemInstruction = list(parts = list(list(text = system_prompt))),
      contents = lapply(if (is.null(history)) list(list(role = 'user', content = query$user)) else history,
        function(message) list(role = if (message$role == 'assistant') 'model' else 'user',
          parts = list(list(text = message$content)))),
      generationConfig = list(temperature = temperature,
                              maxOutputTokens = as.integer(max_tokens)))
  } else stop('\uc9c0\uc6d0\ud558\uc9c0 \uc54a\ub294 AI \uc81c\uacf5\uc790\uc785\ub2c8\ub2e4.')

  body_file <- tempfile(fileext = '.json')
  conf_file <- tempfile(fileext = '.conf')
  header_file <- tempfile(fileext = '.headers')
  on.exit(unlink(c(body_file, conf_file, header_file)), add = TRUE)
  jsonlite::write_json(payload, body_file, auto_unbox = TRUE, null = 'null')
  # API key must never be placed on the command line, printed, or written to an R project file.
  # curl reads a short-lived config file; it is deleted when the call finishes.
  extra_args <- character()
  if (!is.null(api_key) && nzchar(api_key)) {
    if (grepl('[[:cntrl:]]', api_key)) stop('API \ud0a4\uc5d0 \uc81c\uc5b4\ubb38\uc790\uac00 \ud3ec\ud568\ub418\uc5b4 \uc788\uc2b5\ub2c8\ub2e4.')
    # encodeString()이 따옴표와 역슬래시를 escape하여 curl config 주입을 방지한다.
    header_line <- paste0('header = ',
                          encodeString(paste0(if (provider == 'aistudio') 'x-goog-api-key: ' else 'Authorization: Bearer ', api_key), quote = '"'))
    writeLines(header_line, conf_file, useBytes = TRUE)
    try(Sys.chmod(conf_file, mode = '0600'), silent = TRUE)
    extra_args <- c('--config', conf_file)
  }
  args <- c('--silent', '--show-error', '--no-buffer', '--fail-with-body',
            '--connect-timeout', '15', '--max-time', as.character(as.integer(timeout)),
            extra_args, '--dump-header', header_file, '-X', 'POST', url,
            '-H', 'Content-Type: application/json',
            '--data-binary', paste0('@', body_file))
  pop <- if (isTRUE(window)) .ai_popup(paste0(toupper(provider), ' | AI \uc2e4\uc2dc\uac04 \uc751\ub2f5')) else NULL
  if (!is.null(pop)) pop$push(paste0('\uc9c8\ubb38: ', query$raw_prompt, '\n\n[\uc0dd\uc131 \uc694\uccad \uc911...]\n'))
  view <- if (!is.null(.view)) .view else if (isTRUE(viewer)) .ai_viewer(paste0(toupper(provider), ' | RStudio Viewer'), query$raw_prompt) else NULL
  notify <- function(text) {
    if(!is.null(view)) view$status(text)
    if(is.function(on_status)) on_status(text)
    invisible(NULL)
  }
  if(is.null(.view) && !is.null(view) && is.function(view$close)) on.exit(view$close(),add=TRUE)
  if (!is.null(view) || is.function(on_status)) notify('\uc11c\ubc84 \uc751\ub2f5 \ub300\uae30 \uc911...')
  metrics <- list()
  usage <- function(info) { metrics <<- utils::modifyList(metrics,info) }
  console_stream <- isTRUE(stream) && isTRUE(echo)
  meter <- .ai_console_progress(isTRUE(progress) && !console_stream,metrics=function() metrics)
  completed <- FALSE
  cancelled <- FALSE
  on.exit(if (!completed) meter$update(if(cancelled) '\uc0ac\uc6a9\uc790 \uc911\uc9c0' else '\uc694\uccad \uc911\ub2e8/\uc2e4\ud328', failed = TRUE, force = TRUE), add = TRUE)
  meter$update('\uc694\uccad \uc900\ube44', force = TRUE)
  activity_state <- 'waiting'
  stage_label <- function() switch(activity_state,
    reasoning='\ubaa8\ub378 \ucd94\ub860 \uc911 (\ubcf8\ubb38 \ub300\uae30)',
    content='\uc751\ub2f5 \uc0dd\uc131 \uc911',
    event='\uc751\ub2f5 \uc218\uc2e0 \uc911 (\ubcf8\ubb38 \ub300\uae30)',
    '\uc11c\ubc84 \uc751\ub2f5 \ub300\uae30')
  activity <- function(stage) {
    if(isTRUE(stream) && stage %in% c('reasoning','content')) {
      if(is.null(metrics$first_chunk_seconds)) metrics$first_chunk_seconds <<- meter$elapsed()
      metrics$output_chunks <<- if(is.null(metrics$output_chunks)) 1L else metrics$output_chunks+1L
    }
    previous <- activity_state
    if(stage %in% c('reasoning','content') || activity_state=='waiting') activity_state <<- stage
    if(previous != activity_state) {
      meter$update(stage_label(),receiving=TRUE,force=TRUE)
      if(!is.null(view) || is.function(on_status)) notify(stage_label())
    }
  }
  finish_reason <- NULL
  terminal <- FALSE
  finish <- function(reason) { finish_reason <<- reason }
  full <- ''
  show <- function(s) {
    if (!is.character(s) || length(s) != 1L || !nzchar(s)) return(invisible(NULL))
    full <<- paste0(full, s)
    meter$update("\uc751\ub2f5 \uc0dd\uc131 \uc911", receiving = TRUE)
    if (isTRUE(echo) && (!isTRUE(progress) || console_stream)) { cat(s); utils::flush.console() }
    if (is.function(on_chunk)) on_chunk(s)
    if (!is.null(pop)) pop$push(s)
    if (!is.null(view)) view$push(s)
    invisible(NULL)
  }
  # Google의 일시적 429/5xx 응답만 재시도한다. 출력이 시작되었다면
  # 중복 텍스트 생성을 막기 위해 자동 재시도하지 않는다.
  retries <- as.integer(retries)
  if (is.na(retries) || retries < 0L || retries > 10L)
    stop('retries\ub294 0~10 \uc0ac\uc774 \uc815\uc218\uc5ec\uc57c \ud569\ub2c8\ub2e4.', call. = FALSE)
  if (!is.numeric(retry_wait) || length(retry_wait) != 1L ||
      !is.finite(retry_wait) || retry_wait < 0)
    stop('retry_wait\ub294 0 \uc774\uc0c1 \uc22b\uc790\uc5ec\uc57c \ud569\ub2c8\ub2e4.', call. = FALSE)
  for (attempt in seq_len(retries + 1L)) {
    writeLines(character(), header_file)
    stderr <- ''
    carry <- ''
    raw <- ''
    error_body <- ''
    got_event <- FALSE
    consume_line <- function(line) {
      line <- sub('\r$', '', line)
      if (!nzchar(line)) return(invisible(NULL))
      if (isTRUE(stream)) {
        if (provider != 'ollama' && !startsWith(line, 'data:')) return(invisible(NULL))
        got_event <<- TRUE
        if (.ai_parse(line, provider, TRUE, show, finish, usage, activity)) terminal <<- TRUE
      }
      invisible(NULL)
    }
    ingest <- function(s) {
      if (!length(s) || !nzchar(s)) return(invisible(NULL))
      # 실패 응답의 JSON 본문도 보존하여 curl 종료 코드 대신 실제 오류를 표시한다.
      if (nchar(error_body, type = 'bytes') < 30000L)
        error_body <<- paste0(error_body, s)
      if (!isTRUE(stream)) {
        raw <<- paste0(raw, s)
        return(invisible(NULL))
      }
      carry <<- paste0(carry, s)
      repeat {
        k <- regexpr('\n', carry, fixed = TRUE)[1L]
        if (k < 0L) break
        ln <- if (k > 1L) substr(carry, 1L, k - 1L) else ''
        carry <<- substring(carry, k + 1L)
        consume_line(ln)
      }
      invisible(NULL)
    }
    proc <- processx::process$new(.ai_curl(), args = args, stdout = '|', stderr = '|',
                                  cleanup = TRUE, windows_hide_window = TRUE)
    last_gui_update <- 0
    last_view_update <- 0
    tryCatch({
      repeat {
        if(!is.null(view) && is.function(view$poll)) view$poll()
        requested <- (!is.null(view) && is.function(view$is_stopped) && view$is_stopped()) ||
          (isTRUE(.ai_state()$busy) && isTRUE(.ai_state()$cancel_requested))
        if(requested) {
          cancelled <- TRUE
          stop(structure(list(message='Response stopped by user.',call=NULL),class=c('ai_cancelled','error','condition')))
        }
        state <- proc$poll_io(25L)
        if(isTRUE(viewer) || !is.null(view)) Sys.sleep(0.001)
        meter$update(stage_label(), receiving = activity_state != 'waiting')
        if((!is.null(view) || is.function(on_status)) && meter$elapsed()-last_view_update>=0.5) {
          notify(paste(stage_label(),.ai_metric_text(metrics,meter$elapsed()),sep='\n'))
          last_view_update <- meter$elapsed()
        }
        # Keep Tcl/Tk responsive even BEFORE the first AI token arrives.
        if ((isTRUE(window) || isTRUE(getOption('r_ai_gui_active', FALSE))) &&
            capabilities('tcltk') && (as.numeric(Sys.time()) - last_gui_update > 0.2)) {
          last_gui_update <- as.numeric(Sys.time())
          try(tcltk::tcl('update'), silent = TRUE)
        }
        if (state[['output']] %in% c('ready', 'closed')) {
          t <- proc$read_output()
          if (length(t)) ingest(paste(t, collapse = ''))
        }
        if (state[['error']] %in% c('ready', 'closed')) {
          t <- proc$read_error()
          if (length(t)) stderr <- paste0(stderr, paste(t, collapse = ''))
        }
        if (!proc$is_alive()) {
          t <- proc$read_all_output()
          if (length(t)) ingest(paste(t, collapse = ''))
          t <- proc$read_all_error()
          if (length(t)) stderr <- paste0(stderr, paste(t, collapse = ''))
          break
        }
      }
    }, error = function(e) {
      if(inherits(e,'ai_cancelled')) stop(e)
      msg <- conditionMessage(e)
      if (!is.null(api_key) && nzchar(api_key)) msg <- gsub(api_key, '[REDACTED]', msg, fixed = TRUE)
      e <- simpleError(msg)
      if (!is.null(pop)) pop$push(paste0('\n[\uc624\ub958] ', conditionMessage(e), '\n'))
      if (!is.null(view)) { view$push(paste0('\n[\uc624\ub958] ', conditionMessage(e))); notify('\uc694\uccad \uc2e4\ud328') }
      stop(e)
    }, finally = {
      if (proc$is_alive()) proc$kill()
    })
    if (isTRUE(stream) && nzchar(carry)) consume_line(carry)
    status <- proc$get_exit_status()
    headers <- tryCatch(readLines(header_file, warn = FALSE), error = function(e) character())
    statuses <- grep('^HTTP/[0-9.]+[[:space:]]+[0-9]{3}', headers, value = TRUE)
    http_code <- if (length(statuses)) {
      as.integer(sub('^HTTP/[0-9.]+[[:space:]]+([0-9]{3}).*$', '\\1', utils::tail(statuses, 1L)))
    } else NA_integer_
    if (identical(status, 0L)) break

    # JSON 에러 메시지는 사용자에게 표시하되 API 키가 섞이면 마스킹한다.
    api_message <- ''
    if (nzchar(error_body)) {
      err_obj <- tryCatch(jsonlite::fromJSON(error_body, simplifyVector = FALSE),
                          error = function(e) NULL)
      if (!is.null(err_obj$error$message)) api_message <- err_obj$error$message
    }
    if (!nzchar(api_message)) api_message <- if (nzchar(error_body)) error_body else stderr
    if (!is.null(api_key) && nzchar(api_key))
      api_message <- gsub(api_key, '[REDACTED]', api_message, fixed = TRUE)

    can_retry <- identical(provider, 'aistudio') &&
      !is.na(http_code) && http_code %in% c(429L, 500L, 502L, 503L, 504L) &&
      !nzchar(full) && attempt <= retries
    if (can_retry) {
      delay <- min(30, retry_wait * 2^(attempt - 1L))
      notice <- sprintf('\n[Gemini HTTP %s: %s\ucd08 \ud6c4 \uc7ac\uc2dc\ub3c4 (%d/%d)]\n',
                        http_code, format(delay), attempt, retries)
      meter$update(paste0("\uc7ac\uc2dc\ub3c4 \ub300\uae30 (", attempt, "/", retries, ")"), force = TRUE)
      if (isTRUE(echo) && !isTRUE(progress)) cat(notice)
      if (!is.null(pop)) pop$push(notice)
      if (!is.null(view) || is.function(on_status)) notify(paste0('HTTP ', http_code, ': ', delay, '\ucd08 \ud6c4 \uc7ac\uc2dc\ub3c4 ', attempt, '/', retries))
      if (is.function(on_chunk)) on_chunk(notice)
      Sys.sleep(delay)
      next
    }
    suggestion <- if (identical(http_code, 503L))
      ' Google \uc11c\ubc84 \uc77c\uc2dc \uacfc\ubd80\ud558 \uac00\ub2a5\uc131: \uc7a0\uc2dc \ud6c4 \uc7ac\uc2dc\ub3c4\ud558\uac70\ub098 \ub2e4\ub978 Gemini \ubaa8\ub378\uc744 \uc120\ud0dd\ud558\uc2ed\uc2dc\uc624.'
    else if (identical(http_code, 429L))
      ' \uc694\uccad \uc81c\ud55c \ub610\ub294 \ud560\ub2f9\ub7c9 \ucd08\uacfc \uac00\ub2a5\uc131: Google AI Studio\uc758 \uc0ac\uc6a9\ub7c9\uacfc \ud55c\ub3c4\ub97c \ud655\uc778\ud558\uc2ed\uc2dc\uc624.'
    else ''
    if (!is.null(pop)) pop$push(paste0('\n[\uc624\ub958] ', substr(api_message, 1L, 1200L), '\n'))
    if (!is.null(view)) { view$push(paste0('\n[\uc624\ub958] ', substr(api_message, 1L, 1200L))); notify('\uc694\uccad \uc2e4\ud328') }
    stop(provider, ' HTTP \uc694\uccad \uc2e4\ud328 (HTTP ',
         if (is.na(http_code)) '\ubbf8\ud655\uc778' else http_code,
         ', curl \uc885\ub8cc ', status, '): ', substr(api_message, 1L, 1800L),
         suggestion, call. = FALSE)
  }
  if (!isTRUE(stream)) {
    .ai_parse(raw, provider, FALSE, show, finish, usage, activity)
    terminal <- TRUE
  }
  if (isTRUE(stream) && !terminal)
    stop('\uc751\ub2f5 \uc5f0\uacb0\uc774 \uc644\ub8cc \uc2e0\ud638 \uc5c6\uc774 \ub05d\ub0ac\uc2b5\ub2c8\ub2e4. ai_continue()\ub85c \uc774\uc5b4 \uc4f8 \uc218 \uc788\uc2b5\ub2c8\ub2e4.', call. = FALSE)
  if (!nzchar(full)) {
    if(activity_state=='reasoning') stop('\ubaa8\ub378\uc774 \ucd94\ub860\ub9cc \uc0dd\uc131\ud558\uace0 \ubcf8\ubb38\uc744 \ubc18\ud658\ud558\uc9c0 \uc54a\uc558\uc2b5\ub2c8\ub2e4. max_tokens\ub97c \ub298\ub9ac\uac70\ub098 \ubaa8\ub378\uc758 \ucd94\ub860 \uc124\uc815\uc744 \ud655\uc778\ud558\uc2ed\uc2dc\uc624.',call.=FALSE)
    note <- if (got_event) '\uc751\ub2f5 \uc774\ubca4\ud2b8\uc5d0\uc11c \ud14d\uc2a4\ud2b8\ub97c \ucc3e\uc9c0 \ubabb\ud588\uc2b5\ub2c8\ub2e4.' else 'AI \uc751\ub2f5\uc744 \uc218\uc2e0\ud558\uc9c0 \ubabb\ud588\uc2b5\ub2c8\ub2e4.'
    if (!is.null(pop)) pop$push(paste0('\n[\uc624\ub958] ', note, '\n'))
    if (!is.null(view)) { view$push(paste0('\n[\uc624\ub958] ', note)); notify('\ud14d\uc2a4\ud2b8 \uc5c6\uc74c') }
    stop(provider, ': ', note, ' \ubaa8\ub378/\ucd9c\ub825 \ud1a0\ud070/\uc548\uc804 \uc124\uc815\uc744 \ud655\uc778\ud558\uc2ed\uc2dc\uc624.', call. = FALSE)
  }
  metrics <- .ai_finalize_metrics(metrics,meter$elapsed())
  meter$update('\uc644\ub8cc', finish = TRUE, force = TRUE)
  completed <- TRUE
  if (isTRUE(echo) && isTRUE(progress) && !console_stream) cat(full)
  if (isTRUE(echo)) cat('\n')
  if (!is.null(pop)) pop$push('\n\n[\uc644\ub8cc]')
  if (!is.null(view) || is.function(on_status)) notify(paste0('\uc644\ub8cc | ',.ai_metric_text(metrics,metrics$elapsed_seconds,TRUE)))
  invisible(structure(full, finish_reason = finish_reason, metrics = metrics))
}



# A tiny local stop endpoint serviced by the existing nonblocking receive loop.
# It never reads/writes user files and accepts only a per-viewer random URL token.
.ai_control <- function(console_handler=NULL) {
  listener <- NULL
  first <- 35000L + as.integer((as.numeric(Sys.time())*1000+Sys.getpid()) %% 20000)
  for(port in first+0:30) {
    listener <- tryCatch(serverSocket(port),error=function(e) NULL)
    if(!is.null(listener)) break
  }
  if(is.null(listener)) stop('Cannot open the local response-stop endpoint.')
  token <- paste0(basename(tempfile()),basename(tempfile()))
  path <- paste0('/stop/',token);console_path <- paste0('/console/',token)
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
      if(proc.time()[['elapsed']]-client$opened>if(is.function(console_handler))15 else 2) {close_client(client);next}
      if(socketSelect(list(client$con),timeout=0)) {
        bytes <- tryCatch(readBin(client$con,'raw',65536L),error=function(e) raw())
        client$data <- c(client$data,bytes)
        text <- tryCatch(rawToChar(client$data),error=function(e) NULL)
        if(is.null(text)) {close_client(client);next}
        if(length(client$data)>1048576L) {close_client(client);next}
        if(grepl('\r\n\r\n',text,fixed=TRUE)) {
          split <- regexpr('\r\n\r\n',text,fixed=TRUE,useBytes=TRUE)[1L]
          header <- rawToChar(client$data[seq_len(split-1L)])
          lines <- strsplit(header,'\r\n',fixed=TRUE)[[1L]];line <- lines[1L]
          length_line <- grep('^Content-Length:',lines,value=TRUE,ignore.case=TRUE)
          count <- if(length(length_line))suppressWarnings(as.numeric(trimws(sub('^[^:]*:','',length_line[1L])))) else 0
          if(!is.finite(count)||count<0||count>1000000) {close_client(client);next}
          start <- split+4L
          if(length(client$data)<start-1L+count){keep[[length(keep)+1L]]<-client;next}
          valid <- line %in% paste0('POST ',path,c(' HTTP/1.1',' HTTP/1.0'))
          console <- is.function(console_handler)&&line %in% paste0('POST ',console_path,c(' HTTP/1.1',' HTTP/1.0'))
          preflight <- is.function(console_handler)&&line %in% paste0('OPTIONS ',console_path,c(' HTTP/1.1',' HTTP/1.0'))
          if(valid) stopped <<- TRUE
          status <- if(valid||console||preflight)'200 OK' else '404 Not Found'
          body <- if(valid)'{"stopped":true}' else if(preflight)'{}' else '{"error":"not found"}'
          if(console) {
            body <- tryCatch({
              if(count==0L)stop('Empty code.')
              payload <- jsonlite::fromJSON(rawToChar(client$data[start:(start+count-1L)]))
              if(!is.character(payload$code)||length(payload$code)!=1L||is.na(payload$code)||!nzchar(payload$code))stop('Empty code.')
              console_handler(payload$code)
              '{"inserted":true,"executed":false}'
            },error=function(e){status<<-'400 Bad Request';as.character(jsonlite::toJSON(list(error=conditionMessage(e)),auto_unbox=TRUE))})
          }
          response <- paste0('HTTP/1.1 ',status,
            '\r\nContent-Type: application/json; charset=utf-8\r\nAccess-Control-Allow-Origin: *',
            '\r\nAccess-Control-Allow-Methods: POST, OPTIONS\r\nAccess-Control-Allow-Headers: Content-Type\r\nCache-Control: no-store',
            '\r\nConnection: close\r\nContent-Length: ',nchar(body,type='bytes'),'\r\n\r\n',body)
          try(writeBin(charToRaw(enc2utf8(response)),client$con),silent=TRUE)
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
  list(console_url=paste0('http://127.0.0.1:',port,console_path),url=paste0('http://127.0.0.1:',port,path),poll=poll,stopped=function()stopped,
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

# A persistent main-session bridge: only inserts code; it never evaluates model output.
.ai_console_bridge <- function() {
  if(!requireNamespace('rstudioapi',quietly=TRUE)||!rstudioapi::isAvailable()||!requireNamespace('later',quietly=TRUE))return(NULL)
  st <- .ai_state()
  if(!is.null(st$console_bridge)&&st$console_bridge$is_open())return(st$console_bridge$console_url)
  bridge <- .ai_control(console_handler=function(code)rstudioapi::sendToConsole(code,execute=FALSE,echo=TRUE,focus=TRUE))
  st$console_bridge <- bridge
  tick <- function(){
    if(!bridge$is_open())return(invisible(NULL))
    try(bridge$poll(),silent=TRUE)
    later::later(tick,0.1)
    invisible(NULL)
  }
  later::later(tick,0.1)
  bridge$console_url
}

# Settings and credentials live in session options, never in package objects.
.ai_state <- function() {
  state <- getOption('jjstat.ai.state')
  if (!is.environment(state)) {
    state <- new.env(parent = emptyenv())
    state$config <- list(); state$keys <- list(); state$last <- NULL; state$busy <- FALSE
    file <- .ai_config_file()
    if (file.exists(file)) state$config <- tryCatch(readRDS(file), error = function(e) list())
    options(jjstat.ai.state = state)
  }
  state
}
.ai_config_file <- function() file.path(tools::R_user_dir('jjstat', 'config'), 'ai-settings.rds')
.ai_defaults <- function(provider) switch(provider,
  ollama = list(base_url = 'http://127.0.0.1:11434', model = ''),
  lmstudio = list(base_url = 'http://127.0.0.1:5678', model = ''),
  lemonade = list(base_url = 'http://127.0.0.1:13305/api/v1', model = ''),
  aistudio = list(base_url = 'https://generativelanguage.googleapis.com/v1beta', model = ''))
.ai_provider <- function(provider) match.arg(provider, c('ollama','lmstudio','aistudio','lemonade'))
.ai_config <- function(provider) {
  provider <- .ai_provider(provider); state <- .ai_state()
  stored <- state$config[[provider]]
  cfg <- utils::modifyList(.ai_defaults(provider), if (is.null(stored)) list() else stored)
  key <- state$keys[[provider]]
  if (is.null(key)) key <- Sys.getenv(switch(provider, aistudio = 'GEMINI_API_KEY',
    lmstudio = 'LM_API_TOKEN', lemonade = 'LEMONADE_API_KEY', ollama = 'OLLAMA_API_KEY'), '')
  cfg$api_key <- key
  cfg
}
.ai_base <- function(base_url, port = NULL) {
  if (!is.character(base_url) || length(base_url) != 1L || is.na(base_url) ||
      !grepl('^https?://[^/?#@[:space:]]+', base_url) || grepl('[?#@[:cntrl:]]', base_url))
    stop('\uc11c\ubc84 \uc8fc\uc18c\ub294 \ud0a4\ub098 \ucffc\ub9ac \uc5c6\uc774 http:// \ub610\ub294 https://\ub85c \uc785\ub825\ud558\uc2ed\uc2dc\uc624.', call. = FALSE)
  base_url <- sub('/+$', '', trimws(base_url))
  if (!is.null(port)) {
    value <- suppressWarnings(as.numeric(port))
    if (length(value) != 1L || !is.finite(value) || value != floor(value) || value < 1 || value > 65535)
      stop('\ud3ec\ud2b8\ub294 1~65535 \uc0ac\uc774 \uc815\uc218\uc5ec\uc57c \ud569\ub2c8\ub2e4.', call. = FALSE)
    authority <- sub('^(https?://[^/]+).*$', '\\1', base_url)
    path <- substring(base_url, nchar(authority) + 1L)
    authority <- sub(':[0-9]+$', '', authority)
    base_url <- paste0(authority, ':', as.integer(value), path)
  }
  base_url
}
.ai_root <- function(base_url) sub('/(?:api/)?v[0-9]+$|/api$', '', sub('/+$','',base_url), perl = TRUE)
.ai_url <- function(provider, base_url, endpoint) {
  base_url <- .ai_base(base_url)
  if (provider == 'ollama') return(paste0(sub('/api$','',base_url), '/api/', endpoint))
  if (provider == 'aistudio') return(paste0(base_url, '/', endpoint))
  if (!grepl('/(?:api/)?v[0-9]+$', base_url, perl = TRUE))
    base_url <- paste0(base_url, if (provider == 'lemonade') '/api/v1' else '/v1')
  paste0(base_url, '/', endpoint)
}
.ai_save_config <- function(provider, base_url, model, api_key, save = FALSE) {
  provider <- .ai_provider(provider); state <- .ai_state()
  base_url <- .ai_base(base_url)
  if (!is.character(model) || length(model) != 1L || is.na(model)) stop('\ubaa8\ub378 ID\ub97c \uc785\ub825\ud558\uc2ed\uc2dc\uc624.')
  if (!is.character(api_key) || length(api_key) != 1L || is.na(api_key) || grepl('[[:cntrl:]]',api_key))
    stop('API \ud0a4 \ud615\uc2dd\uc774 \uc798\ubabb\ub418\uc5c8\uc2b5\ub2c8\ub2e4.')
  state$config[[provider]] <- list(base_url = base_url, model = trimws(model))
  state$keys[[provider]] <- trimws(api_key)
  if (isTRUE(save)) {
    file <- .ai_config_file(); dir.create(dirname(file), recursive = TRUE, showWarnings = FALSE)
    # Only addresses and model IDs are serialized. Keys remain session-only.
    safe <- lapply(state$config, function(x) x[intersect(names(x),c('base_url','model'))])
    saveRDS(safe, file)
  }
  invisible(NULL)
}
#' Inspect AI provider settings without revealing credentials
#' @param provider Provider name.
#' @return A list containing address, model, and whether an API key is set.
#' @export
ai_settings <- function(provider = 'lmstudio') {
  cfg <- .ai_config(provider); cfg$api_key_set <- nzchar(cfg$api_key); cfg$api_key <- NULL; cfg
}
.ai_http <- function(provider, url, payload = NULL, api_key = '', timeout = 30) {
  .ai_require(); .ai_base(sub('[?].*$', '', url))
  files <- c(tempfile(fileext='.json'),tempfile(fileext='.conf'),tempfile(fileext='.body'))
  on.exit(unlink(files), add=TRUE)
  args <- c('--silent','--show-error','--connect-timeout','10','--max-time',as.character(timeout),
    '--output',files[3L],'--write-out','%{http_code}')
  if (nzchar(api_key)) {
    if (grepl('[[:cntrl:]]',api_key)) stop('API \ud0a4\uc5d0 \uc81c\uc5b4\ubb38\uc790\uac00 \uc788\uc2b5\ub2c8\ub2e4.')
    header <- paste0(if(provider == 'aistudio') 'x-goog-api-key: ' else 'Authorization: Bearer ',api_key)
    writeLines(paste0('header = ',encodeString(header,quote='"')),files[2L],useBytes=TRUE)
    try(Sys.chmod(files[2L],'0600'),silent=TRUE)
    args <- c(args,'--config',files[2L])
  }
  if (!is.null(payload)) {
    jsonlite::write_json(payload,files[1L],auto_unbox=TRUE,null='null')
    args <- c(args,'-H','Content-Type: application/json','--data-binary',paste0('@',files[1L]))
  }
  proc <- processx::process$new(.ai_curl(),c(args,url),stdout='|',stderr='|',windows_hide_window=TRUE)
  on.exit(if(proc$is_alive()) proc$kill(),add=TRUE)
  repeat {
    proc$poll_io(100L)
    if (isTRUE(getOption('r_ai_gui_active',FALSE)) && capabilities('tcltk'))
      try(tcltk::tcl('update'),silent=TRUE)
    if (!proc$is_alive()) break
  }
  status <- suppressWarnings(as.integer(trimws(proc$read_all_output())))
  body <- if(file.exists(files[3L])) paste(readLines(files[3L],warn=FALSE,encoding='UTF-8'),collapse='\n') else ''
  obj <- tryCatch(jsonlite::fromJSON(body,simplifyVector=FALSE),error=function(e) NULL)
  if (proc$get_exit_status() != 0L || is.na(status) || status >= 400L || is.null(obj) || !is.null(obj$error) ||
      (!is.null(obj$status) && is.character(obj$status) && obj$status %in% c('error','failed','failure'))) {
    detail <- if(is.list(obj$error)) obj$error$message else if(is.character(obj$error)) obj$error else ''
    if (is.null(detail) || !nzchar(detail)) detail <- '\uc8fc\uc18c\u00b7\ud3ec\ud2b8\u00b7\uc11c\ubc84 \uc2e4\ud589 \uc0c1\ud0dc\u00b7API \ud0a4\ub97c \ud655\uc778\ud558\uc2ed\uc2dc\uc624.'
    if(nzchar(api_key)) detail <- gsub(api_key,'[REDACTED]',detail,fixed=TRUE)
    cond <- structure(list(message=paste0(provider,' HTTP ',status,': ',detail),call=NULL,status=status),
                      class=c('ai_http_error','error','condition'))
    stop(cond)
  }
  obj
}
#' List available text-generation models
#' @param provider Provider name.
#' @param base_url Server address; defaults to saved settings.
#' @param api_key Optional session-only API key.
#' @param details Return identifiers and load-state columns.
#' @return Character model IDs, or a data frame when details is TRUE.
#' @export
ai_models <- function(provider = 'lmstudio', base_url = NULL, api_key = NULL, details = FALSE) {
  provider <- .ai_provider(provider); cfg <- .ai_config(provider)
  if(is.null(base_url)) base_url <- cfg$base_url
  if(is.null(api_key)) api_key <- cfg$api_key
  items <- list(); native <- FALSE
  if(provider == 'aistudio') {
    if(!nzchar(api_key)) stop('API \ud0a4\ub97c \uc785\ub825\ud558\uc2ed\uc2dc\uc624.')
    token <- NULL
    repeat {
      url <- .ai_url(provider,base_url,'models?pageSize=1000')
      if(!is.null(token)) url <- paste0(url,'&pageToken=',utils::URLencode(token,reserved=TRUE))
      obj <- .ai_http(provider,url,api_key=api_key)
      items <- c(items,obj$models); token <- obj$nextPageToken
      if(is.null(token) || !nzchar(token)) break
    }
    items <- Filter(function(x) 'generateContent' %in% unlist(x$supportedGenerationMethods),items)
  } else if(provider == 'lmstudio') {
    url <- paste0(.ai_root(base_url),'/api/v1/models')
    obj <- tryCatch(.ai_http(provider,url,api_key=api_key), ai_http_error=function(e) {
      if(!e$status %in% c(404L,405L)) stop(e)
      .ai_http(provider,.ai_url(provider,base_url,'models'),api_key=api_key)
    })
    native <- !is.null(obj$models); items <- if(native) obj$models else obj$data
  } else {
    obj <- .ai_http(provider,.ai_url(provider,base_url,if(provider=='ollama') 'tags' else 'models'),api_key=api_key)
    items <- if(provider=='ollama') obj$models else obj$data
  }
  items <- Filter(function(x) {
    type <- if(is.null(x$type)) '' else x$type
    labels <- tolower(unlist(x$labels))
    !type %in% c('embedding','embeddings','image','audio','decision') &&
      !any(labels %in% c('image','image-generation','diffusion','embedding','audio','tts','stt'))
  },items)
  rows <- lapply(items,function(x) {
    id <- if(provider=='aistudio') sub('^models/','',x$name) else if(provider=='ollama') x$name else if(native) x$key else x$id
    loaded <- if(native) length(x$loaded_instances)>0L else if(!is.null(x$state)) x$state=='loaded' else NA
    data.frame(id=as.character(id),loaded=loaded,stringsAsFactors=FALSE)
  })
  result <- if(length(rows)) do.call(rbind,rows) else data.frame(id=character(),loaded=logical())
  if(isTRUE(details)) result else result$id
}
#' Load a selected model into a local server
#' @param provider Provider name.
#' @param model Model identifier.
#' @param base_url Server address.
#' @param api_key Optional API key.
#' @param timeout Model loading timeout in seconds.
#' @return Server response invisibly. AI Studio returns availability, not a local load.
#' @export
ai_load_model <- function(provider, model, base_url=NULL, api_key=NULL, timeout=300) {
  provider <- .ai_provider(provider); cfg <- .ai_config(provider)
  if(is.null(base_url)) base_url <- cfg$base_url
  if(is.null(api_key)) api_key <- cfg$api_key
  if(!is.character(model) || length(model)!=1L || !nzchar(model)) stop('\ubaa8\ub378\uc744 \uc120\ud0dd\ud558\uc2ed\uc2dc\uc624.')
  if(provider=='aistudio') {
    if(!model %in% ai_models(provider,base_url,api_key)) stop('\ud574\ub2f9 \ud0a4\ub85c \uc0ac\uc6a9\ud560 \uc218 \uc5c6\ub294 \ubaa8\ub378\uc785\ub2c8\ub2e4.')
    return(invisible(list(status='available',model=model)))
  }
  if(provider=='ollama') {url <- .ai_url(provider,base_url,'generate'); payload <- list(model=model,stream=FALSE)}
  else if(provider=='lemonade') {url <- .ai_url(provider,base_url,'load'); payload <- list(model_name=model)}
  else {url <- paste0(.ai_root(base_url),'/api/v1/models/load'); payload <- list(model=model)}
  invisible(.ai_http(provider,url,payload,api_key,timeout))
}
#' Test a selected model with a short generation request
#' @param provider Provider name.
#' @param model Selected model identifier.
#' @param base_url Server address.
#' @param api_key Optional API key.
#' @return Generated test text invisibly.
#' @export
ai_test_connection <- function(provider,model=NULL,base_url=NULL,api_key=NULL) {
  provider <- .ai_provider(provider); cfg <- .ai_config(provider)
  if(is.null(model) || !nzchar(model)) model <- cfg$model
  if(is.null(base_url)) base_url <- cfg$base_url
  if(is.null(api_key)) api_key <- cfg$api_key
  if(!nzchar(model)) stop('\ubaa8\ub378 \ubaa9\ub85d\uc744 \uc870\ud68c\ud55c \ub4a4 \ubaa8\ub378\uc744 \uc120\ud0dd\ud558\uc2ed\uc2dc\uc624.')
  text <- .ai_send_once(provider,prompt='Reply with OK.',model=model,base_url=base_url,api_key=api_key,
    viewer=FALSE,stream=FALSE,echo=FALSE,progress=FALSE,max_tokens=128L,timeout=90L,retries=0L)
  invisible(as.character(text))
}
.ai_setting <- function(provider,base_url=NULL,port=NULL,model=NULL,api_key=NULL,open=TRUE,save=FALSE) {
  provider <- .ai_provider(provider); cfg <- .ai_config(provider)
  if(!is.null(base_url)) cfg$base_url <- base_url
  cfg$base_url <- .ai_base(cfg$base_url,port)
  if(!is.null(model)) cfg$model <- model
  if(!is.null(api_key)) cfg$api_key <- api_key
  if(!isTRUE(open)) {
    .ai_save_config(provider,cfg$base_url,cfg$model,cfg$api_key,save)
    return(invisible(ai_settings(provider)))
  }
  if(!capabilities('tcltk') || !requireNamespace('tcltk',quietly=TRUE)) stop('Tcl/Tk\ub97c \uc9c0\uc6d0\ud558\ub294 \ub370\uc2a4\ud06c\ud1b1 R\uc5d0\uc11c \uc2e4\ud589\ud558\uc2ed\uc2dc\uc624.')
  tk <- asNamespace('tcltk'); top <- tk$tktoplevel()
  tk$tkwm.title(top,paste0(toupper(provider),' \uc5f0\uacb0 \uc124\uc815'))
  tk$tkwm.geometry(top,'740x390')
  urlvar <- tk$tclVar(cfg$base_url); keyvar <- tk$tclVar(cfg$api_key); modelvar <- tk$tclVar(cfg$model)
  porttext <- if(provider=='aistudio') '' else sub('^.*:([0-9]+)(/.*)?$','\\1',cfg$base_url)
  if(!grepl('^[0-9]+$',porttext)) porttext <- ''
  portvar <- tk$tclVar(porttext); persist <- tk$tclVar(if(save) '1' else '0')
  status <- tk$tclVar('\uc8fc\uc18c\u00b7\ud3ec\ud2b8 \uc785\ub825 \u2192 \ubaa8\ub378 \ubaa9\ub85d \uc870\ud68c \u2192 \ubaa8\ub378 \uc120\ud0dd \u2192 \ub85c\ub4dc / \uc751\ub2f5 \ud14c\uc2a4\ud2b8 \u2192 \uc800\uc7a5')
  row <- function(label,widget) {
    tk$tkgrid(tk$tklabel(top,text=label),widget,sticky='ew',padx=10,pady=5)
  }
  row('\uc11c\ubc84 \uc8fc\uc18c',tk$tkentry(top,textvariable=urlvar,width=62))
  if(provider!='aistudio') row('\ud3ec\ud2b8',tk$tkentry(top,textvariable=portvar,width=10))
  row(if(provider=='aistudio') 'API \ud0a4' else 'API \ud1a0\ud070 (\uc120\ud0dd)',tk$tkentry(top,textvariable=keyvar,show='*',width=50))
  models <- tk$ttkcombobox(top,textvariable=modelvar,width=55)
  row('\ubaa8\ub378 \uc120\ud0dd / \uc9c1\uc811 \uc785\ub825',models)
  tk$tkgrid.columnconfigure(top,1,weight=1)
  note <- if(provider=='aistudio') '\ud074\ub77c\uc6b0\ub4dc \ubaa8\ub378\uc740 \ub85c\uceec \ub85c\ub529 \ub300\uc2e0 \uc0ac\uc6a9 \uac00\ub2a5 \uc5ec\ubd80\uc640 \uc2e4\uc81c \uc751\ub2f5\uc744 \ud655\uc778\ud569\ub2c8\ub2e4.' else
    '\ub85c\ub529\uc5d0 \uc2dc\uac04\uc774 \uac78\ub9b4 \uc218 \uc788\uc2b5\ub2c8\ub2e4. Lemonade\ub294 \ubbf8\uc124\uce58 \ubaa8\ub378\uc744 \ub2e4\uc6b4\ub85c\ub4dc\ud560 \uc218 \uc788\uc2b5\ub2c8\ub2e4.'
  tk$tkgrid(tk$tklabel(top,text=note,wraplength=690,justify='left'),columnspan=2,sticky='w',padx=10,pady=5)
  tk$tkgrid(tk$tkcheckbutton(top,text='\uc8fc\uc18c\u00b7\ubaa8\ub378\uc744 \ub2e4\uc74c R \uc138\uc158\uc5d0\ub3c4 \uc800\uc7a5 (\ud0a4\ub294 \ud604\uc7ac \uc138\uc158\uc5d0\ub9cc \ubcf4\uad00)',variable=persist),columnspan=2,sticky='w',padx=10)
  bar <- tk$tkframe(top); tk$tkgrid(bar,columnspan=2,sticky='ew',padx=10,pady=8)
  tk$tkgrid(tk$tklabel(top,textvariable=status,wraplength=690,justify='left'),columnspan=2,sticky='w',padx=10,pady=8)
  busy <- FALSE; buttons <- list()
  values <- function() list(base_url=.ai_base(as.character(tk$tclvalue(urlvar)),
    if(provider=='aistudio' || !nzchar(as.character(tk$tclvalue(portvar)))) NULL else as.character(tk$tclvalue(portvar))),
    model=trimws(as.character(tk$tclvalue(modelvar))),api_key=as.character(tk$tclvalue(keyvar)))
  action <- function(label,work) function() {
    if(busy) return(invisible(NULL))
    if(isTRUE(.ai_state()$busy)) {
      tcltk::tclvalue(status) <- 'AI \uc751\ub2f5 \uc0dd\uc131\uc774 \ub05d\ub09c \ub4a4 \uc124\uc815\uc744 \ud14c\uc2a4\ud2b8\ud558\uc2ed\uc2dc\uc624.'
      return(invisible(NULL))
    }
    busy <<- TRUE; old <- getOption('r_ai_gui_active'); options(r_ai_gui_active=TRUE)
    for(b in buttons) tk$tkconfigure(b,state='disabled')
    tcltk::tclvalue(status) <- paste0(label,' \uc911...'); tk$tcl('update')
    on.exit({busy <<- FALSE; options(r_ai_gui_active=old)
      for(b in buttons) try(tk$tkconfigure(b,state='normal'),silent=TRUE)},add=TRUE)
    tryCatch(work(values()),error=function(e) { try(tcltk::tclvalue(status) <- conditionMessage(e),silent=TRUE) })
    invisible(NULL)
  }
  addbutton <- function(text,work) {
    b <- tk$tkbutton(bar,text=text,command=action(text,work)); buttons[[length(buttons)+1L]] <<- b
    tk$tkpack(b,side='left',padx=3)
  }
  addbutton('\uc5f0\uacb0 / \ubaa8\ub378 \ubaa9\ub85d',function(v) {
    ids <- ai_models(provider,v$base_url,v$api_key)
    tk$tkconfigure(models,values=ids)
    if(length(ids) && !v$model %in% ids) tcltk::tclvalue(modelvar) <- ids[[1L]]
    tcltk::tclvalue(status) <- paste0('\uc5f0\uacb0 \uc131\uacf5 \u00b7 \uc0ac\uc6a9 \uac00\ub2a5\ud55c \ud14d\uc2a4\ud2b8 \ubaa8\ub378 ',length(ids),'\uac1c')
  })
  addbutton(if(provider=='aistudio') '\ubaa8\ub378 \uc0ac\uc6a9 \ud655\uc778' else '\uc120\ud0dd \ubaa8\ub378 \ub85c\ub4dc',function(v) {
    result <- ai_load_model(provider,v$model,v$base_url,v$api_key)
    if(provider=='lmstudio' && !is.null(result$instance_id)) tcltk::tclvalue(modelvar) <- result$instance_id
    tcltk::tclvalue(status) <- if(provider=='aistudio') '\ubaa8\ub378 \uc0ac\uc6a9 \uac00\ub2a5 \u00b7 \uc751\ub2f5 \ud14c\uc2a4\ud2b8\ub85c \uc2e4\uc81c \uc0dd\uc131\uc744 \ud655\uc778\ud558\uc2ed\uc2dc\uc624.' else '\ubaa8\ub378 \ub85c\ub529 \uc131\uacf5 \u00b7 \uc751\ub2f5 \ud14c\uc2a4\ud2b8\ub85c \uc2e4\uc81c \uc0dd\uc131\uc744 \ud655\uc778\ud558\uc2ed\uc2dc\uc624.'
  })
  addbutton('\uc9e7\uc740 \uc751\ub2f5 \ud14c\uc2a4\ud2b8',function(v) {
    answer <- ai_test_connection(provider,v$model,v$base_url,v$api_key)
    tcltk::tclvalue(status) <- paste0('\uc751\ub2f5 \uc131\uacf5: ',substr(answer,1L,180L))
  })
  addbutton('\uc124\uc815 \uc800\uc7a5',function(v) {
    .ai_save_config(provider,v$base_url,v$model,v$api_key,as.character(tk$tclvalue(persist))=='1')
    tcltk::tclvalue(status) <- '\uc124\uc815\uc744 \uc801\uc6a9\ud588\uc2b5\ub2c8\ub2e4. API \ud0a4\ub294 \ud604\uc7ac R \uc138\uc158\uc5d0\ub9cc \ubcf4\uad00\ud569\ub2c8\ub2e4.'
  })
  tk$tkwm.protocol(top,'WM_DELETE_WINDOW',function() {
    if(!busy) tk$tkdestroy(top) else tcltk::tclvalue(status) <- '\uc791\uc5c5\uc774 \ub05d\ub09c \ub4a4 \ucc3d\uc744 \ub2eb\uc744 \uc218 \uc788\uc2b5\ub2c8\ub2e4.'
  })
  invisible(top)
}

.ai_continue_prompt <- paste(
  '\uc55e\uc120 \ub2f5\ubcc0\uc758 \ub9c8\uc9c0\ub9c9 \ubb38\uc790 \ubc14\ub85c \ub2e4\uc74c\ubd80\ud130 \uc774\uc5b4\uc11c \uc791\uc131\ud558\ub77c.',
  '\uc774\ubbf8 \uc791\uc131\ud55c \uc81c\ubaa9\u00b7\ud45c\u00b7\ubb38\uc7a5\uc740 \ubc18\ubcf5\ud558\uc9c0 \ub9d0\uace0, \ub2eb\ud788\uc9c0 \uc54a\uc740 \ubb38\uc7a5\u00b7Markdown \ud45c\u00b7\ucf54\ub4dc\ube14\ub85d\uc744 \uc774\uc5b4\uc11c \uc644\uc131\ud558\ub77c.',
  '\uc6d0\ub798 \uc9c8\ubb38\uacfc \ubd84\uc11d \ub370\uc774\ud130 \ubc0f \ubb38\uccb4\ub97c \uc720\uc9c0\ud558\uace0, \uc774\uc5b4\uc4f0\uae30 \uc548\ub0b4 \ubb38\uad6c \uc5c6\uc774 \ubcf8\ubb38\ub9cc \ucd9c\ub825\ud558\ub77c.'
)
.ai_truncated <- function(reason) !is.null(reason) && tolower(reason) %in%
  c('length','max_tokens','max_token','max_output_tokens')
.ai_chat <- function(provider,data=NULL,prompt=NULL,model=NULL,base_url=NULL,api_key=NULL,
                     viewer=TRUE,window=FALSE,stream=TRUE,echo=NULL,on_chunk=NULL,max_tokens=4096L,
                     auto_continue=TRUE,max_continuations=3L,system_prompt=.ai_system,
                     .session=NULL,...) {
  provider <- .ai_provider(provider); state <- .ai_state()
  if(!is.logical(stream) || length(stream)!=1L || is.na(stream)) stop('stream must be TRUE or FALSE.')
  if(isTRUE(state$busy)) stop('\ub2e4\ub978 AI \uc694\uccad\uc774 \uc9c4\ud589 \uc911\uc785\ub2c8\ub2e4. \uc644\ub8cc \ud6c4 \ub2e4\uc2dc \uc2e4\ud589\ud558\uc2ed\uc2dc\uc624.')
  if(length(max_continuations)!=1L || !is.numeric(max_continuations) || is.na(max_continuations) ||
     max_continuations!=floor(max_continuations) || max_continuations<0 || max_continuations>20)
    stop('max_continuations\ub294 0~20 \uc0ac\uc774 \uc815\uc218\uc5ec\uc57c \ud569\ub2c8\ub2e4.')
  if(length(max_tokens)!=1L || !is.numeric(max_tokens) || !is.finite(max_tokens) || max_tokens<1 || max_tokens!=floor(max_tokens))
    stop('max_tokens\ub294 \uc591\uc758 \uc815\uc218\uc5ec\uc57c \ud569\ub2c8\ub2e4.')
  cfg <- .ai_config(provider)
  if(is.null(base_url)) base_url <- cfg$base_url
  base_url <- .ai_base(base_url)
  if(is.null(api_key)) api_key <- cfg$api_key
  if(!is.character(api_key) || length(api_key)!=1L || is.na(api_key) || grepl('[[:cntrl:]]',api_key)) stop('API \ud0a4 \ud615\uc2dd\uc774 \uc798\ubabb\ub418\uc5c8\uc2b5\ub2c8\ub2e4.')
  if(is.null(model) || !nzchar(model)) model <- cfg$model
  if(!nzchar(model)) {
    ids <- ai_models(provider,base_url,api_key)
    if(!length(ids)) stop('\uc0ac\uc6a9 \uac00\ub2a5\ud55c \ud14d\uc2a4\ud2b8 \ubaa8\ub378\uc774 \uc5c6\uc2b5\ub2c8\ub2e4. \uc124\uc815 \ucc3d\uc5d0\uc11c \ubaa8\ub378\uc744 \ud655\uc778\ud558\uc2ed\uc2dc\uc624.')
    model <- ids[[1L]]
    state$config[[provider]] <- list(base_url=base_url,model=model)
  }
  if(provider == 'aistudio') model <- sub('^models/', '', model)
  # Keep explicit credentials in options for continuation, not in the transcript.
  state$keys[[provider]] <- api_key
  dots <- list(...)
  query <- .ai_prompt(data,prompt,if(is.null(dots$max_rows)) 100L else dots$max_rows,
    if(is.null(dots$max_chars)) 30000L else dots$max_chars)
  if(is.null(.session)) {
    history <- list(list(role='user',content=query$user)); accumulated <- ''; original <- query$raw_prompt
  } else {
    history <- c(.session$history,list(list(role='user',content=query$raw_prompt)))
    accumulated <- .session$text; original <- .session$question
  }
  request_options <- c(list(viewer=viewer,window=window,stream=stream,echo=echo,max_tokens=max_tokens,
    auto_continue=auto_continue,max_continuations=max_continuations,system_prompt=system_prompt),dots)
  session <- list(provider=provider,model=model,base_url=base_url,question=original,
    history=history,text=accumulated,finish_reason='interrupted',options=request_options)
  state$busy <- TRUE;state$cancel_requested <- FALSE
  on.exit(state$busy <- FALSE,add=TRUE)
  view <- if(isTRUE(viewer)) .ai_viewer(paste0(toupper(provider),' | RStudio Viewer'),original) else NULL
  if(!is.null(view) && is.function(view$close)) on.exit(view$close(),add=TRUE)
  if(!is.null(view) && nzchar(accumulated)) view$push(accumulated)
  round <- 0L
  repeat {
    current <- ''
    session$history <- history
    # Do not replace a previous response until a new request is ready to run.
    state$last <- session
    receive <- function(chunk) {
      current <<- paste0(current,chunk)
      session$text <<- paste0(accumulated,current)
      session$history <<- c(history,list(list(role='assistant',content=current)))
      state$last <- session
      if(is.function(on_chunk)) on_chunk(chunk)
    }
    result <- tryCatch(do.call(.ai_send_once,c(list(provider=provider,prompt=original,
      model=model,base_url=base_url,api_key=api_key,viewer=FALSE,.view=view,window=window,stream=stream,
      echo=echo,on_chunk=receive,max_tokens=max_tokens,system_prompt=system_prompt,history=history,
      progress=if(is.null(dots$progress)) isTRUE(viewer) else dots$progress),dots[setdiff(names(dots),'progress')])),
      error=function(e) {
        if(inherits(e,'ai_cancelled')) return(e)
        message <- conditionMessage(e)
        if(nzchar(api_key)) message <- gsub(api_key,'[REDACTED]',message,fixed=TRUE)
        if(!is.null(view)) view$status(paste0('\uc694\uccad \uc2e4\ud328 | ',message))
        stop(message,call.=FALSE)
      })
    if(inherits(result,'ai_cancelled')) {
      accumulated <- session$text;reason <- 'cancelled';session$finish_reason <- reason;state$last <- session
      break
    }
    accumulated <- paste0(accumulated,as.character(result))
    history <- c(history,list(list(role='assistant',content=as.character(result))))
    reason <- attr(result,'finish_reason')
    session$text <- accumulated; session$history <- history; session$finish_reason <- reason
    session$metrics <- attr(result,'metrics')
    state$last <- session
    if(!.ai_truncated(reason) || !isTRUE(auto_continue) || round >= max_continuations) break
    round <- round+1L
    if(!is.null(view)) view$status(paste0('\ud1a0\ud070 \uc81c\ud55c \u00b7 \uc790\ub3d9 \uc774\uc5b4\uc4f0\uae30 ',round,'/',max_continuations))
    if(isTRUE(viewer) || isTRUE(dots$progress)) cat(sprintf('[AI] \ud1a0\ud070 \uc81c\ud55c: \uc790\ub3d9 \uc774\uc5b4\uc4f0\uae30 %d/%d\n',round,max_continuations))
    history <- c(history,list(list(role='user',content=.ai_continue_prompt)))
  }
  if(identical(reason,'cancelled')) {
    if(!is.null(view)) view$status('\uc911\uc9c0\ub428 \u00b7 \ubc1b\uc740 \ubcf8\ubb38\uc740 \ubcf4\uc874\ub418\uc5c8\uc2b5\ub2c8\ub2e4.')
  } else if(.ai_truncated(reason)) {
    if(!is.null(view)) view$status('\ud1a0\ud070 \uc81c\ud55c\uc73c\ub85c \uc911\ub2e8 \u00b7 ai_continue()\ub85c \uc774\uc5b4\uc4f0\uae30')
    warning('\ucd9c\ub825 \ud1a0\ud070 \uc81c\ud55c\uc5d0 \ub3c4\ub2ec\ud588\uc2b5\ub2c8\ub2e4. ai_continue()\ub85c \uc774\uc5b4 \uc4f0\uac70\ub098 max_tokens\ub97c \ub298\ub9ac\uc2ed\uc2dc\uc624.',call.=FALSE)
  } else if(!is.null(view)) view$status(paste0('\uc644\ub8cc | ',.ai_metric_text(session$metrics,session$metrics$elapsed_seconds,TRUE)))
  invisible(accumulated)
}
#' Continue the last AI response with its original data and conversation
#' @param prompt Instructions for the next section.
#' @param provider Optional provider; must match the saved conversation.
#' @param ... Options overriding the previous call, e.g. max_tokens or viewer.
#' @return The complete accumulated response invisibly.
#' @export
ai_continue <- function(prompt=.ai_continue_prompt,provider=NULL,...) {
  last <- .ai_state()$last
  if(is.null(last) || !nzchar(last$text)) stop('\uc774\uc5b4 \uc4f8 \uc774\uc804 \uc751\ub2f5\uc774 \uc5c6\uc2b5\ub2c8\ub2e4.')
  if(!is.null(provider) && provider!=last$provider) stop('\uc774\uc804 \uc751\ub2f5\uacfc \ub3d9\uc77c\ud55c \uacf5\uae09\uc790\ub97c \uc120\ud0dd\ud558\uc2ed\uc2dc\uc624.')
  args <- c(list(provider=last$provider,prompt=prompt,model=last$model,
    base_url=last$base_url,.session=last),last$options)
  do.call(.ai_chat,utils::modifyList(args,list(...),keep.null=TRUE))
}
#' Retrieve the most recent accumulated response
#' @return A character string; empty when there is no response.
#' @export
ai_last_response <- function() {
  last <- .ai_state()$last
  if(is.null(last)) '' else last$text
}

#' ollama chat with a live Markdown Viewer
#' @param data Optional analysis data, compatible with a pipe.
#' @param prompt User instructions.
#' @param model Model identifier; defaults to saved settings or first available model.
#' @param base_url Server address; defaults to saved settings.
#' @param api_key Optional session-only API key.
#' @param window Also open a text window.
#' @param viewer Display a live RStudio Markdown Viewer (default TRUE).
#' @param stream Stream response fragments as they arrive (default TRUE).
#' @param ... Generation options including max_tokens, auto_continue, and max_continuations.
#' @return The accumulated answer invisibly.
#' @export
ollama <- function(data=NULL,prompt=NULL,model=NULL,base_url=NULL,api_key=NULL,
                     window=FALSE,viewer=TRUE,stream=TRUE,...) {
  .ai_chat('ollama',data=data,prompt=prompt,model=model,base_url=base_url,api_key=api_key,
           window=window,viewer=viewer,stream=stream,...)
}
#' Configure ollama in a separate window
#' @param base_url Optional server address.
#' @param port Optional local port override.
#' @param model Optional model identifier.
#' @param api_key Optional API key; retained in this session only.
#' @param open Open the settings window; FALSE applies settings programmatically.
#' @param save Persist address and model only, never the key.
#' @return A Tk window or safe settings invisibly.
#' @export
ollama_setting <- function(base_url=NULL,port=NULL,model=NULL,api_key=NULL,open=TRUE,save=FALSE) {
  .ai_setting('ollama',base_url,port,model,api_key,open,save)
}

#' lmstudio chat with a live Markdown Viewer
#' @param data Optional analysis data, compatible with a pipe.
#' @param prompt User instructions.
#' @param model Model identifier; defaults to saved settings or first available model.
#' @param base_url Server address; defaults to saved settings.
#' @param api_key Optional session-only API key.
#' @param window Also open a text window.
#' @param viewer Display a live RStudio Markdown Viewer (default TRUE).
#' @param stream Stream response fragments as they arrive (default TRUE).
#' @param ... Generation options including max_tokens, auto_continue, and max_continuations.
#' @return The accumulated answer invisibly.
#' @export
lmstudio <- function(data=NULL,prompt=NULL,model=NULL,base_url=NULL,api_key=NULL,
                     window=FALSE,viewer=TRUE,stream=TRUE,...) {
  .ai_chat('lmstudio',data=data,prompt=prompt,model=model,base_url=base_url,api_key=api_key,
           window=window,viewer=viewer,stream=stream,...)
}
#' Configure lmstudio in a separate window
#' @param base_url Optional server address.
#' @param port Optional local port override.
#' @param model Optional model identifier.
#' @param api_key Optional API key; retained in this session only.
#' @param open Open the settings window; FALSE applies settings programmatically.
#' @param save Persist address and model only, never the key.
#' @return A Tk window or safe settings invisibly.
#' @export
lmstudio_setting <- function(base_url=NULL,port=NULL,model=NULL,api_key=NULL,open=TRUE,save=FALSE) {
  .ai_setting('lmstudio',base_url,port,model,api_key,open,save)
}

#' aistudio chat with a live Markdown Viewer
#' @param data Optional analysis data, compatible with a pipe.
#' @param prompt User instructions.
#' @param model Model identifier; defaults to saved settings or first available model.
#' @param base_url Server address; defaults to saved settings.
#' @param api_key Optional session-only API key.
#' @param window Also open a text window.
#' @param viewer Display a live RStudio Markdown Viewer (default TRUE).
#' @param stream Stream response fragments as they arrive (default TRUE).
#' @param ... Generation options including max_tokens, auto_continue, and max_continuations.
#' @return The accumulated answer invisibly.
#' @export
aistudio <- function(data=NULL,prompt=NULL,model=NULL,base_url=NULL,api_key=NULL,
                     window=FALSE,viewer=TRUE,stream=TRUE,...) {
  .ai_chat('aistudio',data=data,prompt=prompt,model=model,base_url=base_url,api_key=api_key,
           window=window,viewer=viewer,stream=stream,...)
}
#' Configure aistudio in a separate window
#' @param base_url Optional server address.
#' @param port Optional local port override.
#' @param model Optional model identifier.
#' @param api_key Optional API key; retained in this session only.
#' @param open Open the settings window; FALSE applies settings programmatically.
#' @param save Persist address and model only, never the key.
#' @return A Tk window or safe settings invisibly.
#' @export
aistudio_setting <- function(base_url=NULL,port=NULL,model=NULL,api_key=NULL,open=TRUE,save=FALSE) {
  .ai_setting('aistudio',base_url,port,model,api_key,open,save)
}

#' lemonade chat with a live Markdown Viewer
#' @param data Optional analysis data, compatible with a pipe.
#' @param prompt User instructions.
#' @param model Model identifier; defaults to saved settings or first available model.
#' @param base_url Server address; defaults to saved settings.
#' @param api_key Optional session-only API key.
#' @param window Also open a text window.
#' @param viewer Display a live RStudio Markdown Viewer (default TRUE).
#' @param stream Stream response fragments as they arrive (default TRUE).
#' @param ... Generation options including max_tokens, auto_continue, and max_continuations.
#' @return The accumulated answer invisibly.
#' @export
lemonade <- function(data=NULL,prompt=NULL,model=NULL,base_url=NULL,api_key=NULL,
                     window=FALSE,viewer=TRUE,stream=TRUE,...) {
  .ai_chat('lemonade',data=data,prompt=prompt,model=model,base_url=base_url,api_key=api_key,
           window=window,viewer=viewer,stream=stream,...)
}
#' Configure lemonade in a separate window
#' @param base_url Optional server address.
#' @param port Optional local port override.
#' @param model Optional model identifier.
#' @param api_key Optional API key; retained in this session only.
#' @param open Open the settings window; FALSE applies settings programmatically.
#' @param save Persist address and model only, never the key.
#' @return A Tk window or safe settings invisibly.
#' @export
lemonade_setting <- function(base_url=NULL,port=NULL,model=NULL,api_key=NULL,open=TRUE,save=FALSE) {
  .ai_setting('lemonade',base_url,port,model,api_key,open,save)
}

#' Open an independent AI question window with Markdown and PV tabs
#' @param provider AI provider name.
#' @param data Optional analysis data, including piped data.
#' @param prompt Initial question. Requests start only when the run button is pressed.
#' @param model Optional model ID; defaults to saved settings.
#' @param api_key Optional API key; defaults to saved settings.
#' @param initial_response Optional Markdown restored without an AI request.
#' @param engine Web application (default) or legacy Tcl/Tk text window.
#' @param launch Open the web application window. FALSE returns a local URL for embedding.
#' @param ... Request options such as base_url, stream and max_tokens.
#' @return Invisibly, a web-window handle with url and close(), or a Tk toplevel.
#' @export
ai_window <- function(provider=c('ollama','lmstudio','aistudio','lemonade'),data=NULL,
                      prompt='\uc774 \ubd84\uc11d\uacb0\uacfc\ub97c \uc124\uba85\ud574\uc918',model=NULL,api_key=NULL,
                      initial_response=NULL,engine=c('web','tk'),launch=TRUE,...) {
  provider <- match.arg(provider);engine <- match.arg(engine)
  if(engine=='tk') return(.ai_tk_window(provider,data,prompt,model,api_key,initial_response,...))
  .ai_web_window(provider,data,prompt,model,api_key,initial_response,launch,...)
}

 .ai_tk_window <- function(provider=c('ollama','lmstudio','aistudio','lemonade'),
                      data=NULL,prompt='\uc774 \ubd84\uc11d\uacb0\uacfc\ub97c \uc124\uba85\ud574\uc918',model=NULL,api_key=NULL,initial_response=NULL,...) {
  provider <- match.arg(provider)
  force(data);force(prompt);force(initial_response);opts <- list(...)
  if(!is.null(initial_response) && (!is.character(initial_response) || length(initial_response)!=1L || is.na(initial_response)))
    stop('initial_response must be a single character string.')
  if(!capabilities('tcltk') || !requireNamespace('tcltk',quietly=TRUE))
    stop('Tcl/Tk\ub97c \uc9c0\uc6d0\ud558\ub294 \ub370\uc2a4\ud06c\ud1b1 R\uc5d0\uc11c \uc2e4\ud589\ud558\uc2ed\uc2dc\uc624.')
  cfg <- .ai_config(provider)
  if(is.null(model)) model <- cfg$model
  if(is.null(api_key)) api_key <- cfg$api_key
  external_chunk <- opts$on_chunk;external_status <- opts$on_status
  if(!is.null(external_chunk) && !is.function(external_chunk)) stop('on_chunk\ub294 \ud568\uc218\uc5ec\uc57c \ud569\ub2c8\ub2e4.')
  if(!is.null(external_status) && !is.function(external_status)) stop('on_status\ub294 \ud568\uc218\uc5ec\uc57c \ud569\ub2c8\ub2e4.')
  top <- tcltk::tktoplevel()
  tcltk::tkwm.title(top,paste0(toupper(provider),' | R AI \uc9c8\ubb38\ucc3d [Live transcript]'))
  tcltk::tkwm.geometry(top,'980x760')
  settings_bar <- tcltk::tkframe(top)
  model_var <- tcltk::tclVar(model);key_var <- tcltk::tclVar(api_key)
  tcltk::tkpack(tcltk::tklabel(settings_bar,text='\ubaa8\ub378 ID'),side='left')
  model_entry <- tcltk::tkentry(settings_bar,textvariable=model_var,width=45)
  tcltk::tkpack(model_entry,side='left',fill='x',expand=TRUE)
  key_entry <- NULL
  if(provider=='aistudio') {
    tcltk::tkpack(tcltk::tklabel(settings_bar,text=' API \ud0a4'),side='left')
    key_entry <- tcltk::tkentry(settings_bar,textvariable=key_var,show='*',width=24)
    tcltk::tkpack(key_entry,side='left')
  }
  tcltk::tkpack(settings_bar,fill='x')
  query_bar <- tcltk::tkframe(top)
  question_var <- tcltk::tclVar(prompt)
  question <- tcltk::tkentry(query_bar,textvariable=question_var,width=80)
  tcltk::tkpack(question,side='left',fill='x',expand=TRUE)
  tcltk::tkpack(query_bar,fill='x')
  status_var <- tcltk::tclVar('\uc900\ube44 \u00b7 \uc9c8\ubb38 \uc2e4\ud589 \ubc84\ud2bc\uc744 \ub20c\ub7ec \uc694\uccad\ud558\uc2ed\uc2dc\uc624.')
  tcltk::tkpack(tcltk::tklabel(top,textvariable=status_var,anchor='w',justify='left',wraplength=940),fill='x')
  area <- tcltk::tkframe(top);scroll <- tcltk::tkscrollbar(area)
  output <- tcltk::tktext(area,wrap='word',background='#141b25',foreground='#eef3fa',
    insertbackground='white',state='disabled',yscrollcommand=function(...)tcltk::tkset(scroll,...))
  tcltk::tkconfigure(scroll,command=function(...)tcltk::tkyview(output,...))
  tcltk::tkpack(scroll,side='right',fill='y');tcltk::tkpack(output,side='left',fill='both',expand=TRUE)
  tcltk::tkpack(area,fill='both',expand=TRUE)
  transcript_var <- tcltk::tclVar('')
  transcript <- ''
  writer_name <- paste0('::jjstat_write_',gsub('[^A-Za-z0-9]','',basename(tempfile())))
  writer_body <- paste(
    'if {![winfo exists $widget]} {return}',
    'set value [set $variable]',
    '$widget configure -state normal',
    'set current [$widget get 1.0 end-1c]',
    'if {[string first $current $value] == 0} {$widget insert end [string range $value [string length $current] end]} else {$widget delete 1.0 end; $widget insert 1.0 $value}',
    '$widget configure -state disabled',
    '$widget see end',
    'update idletasks',sep='; ')
  tcltk::tcl('proc',writer_name,'widget variable index operation',writer_body)
  writer_command <- tcltk::tcl('list',writer_name,output)
  tcltk::tcl('trace','add','variable',transcript_var,'write',writer_command)
  busy <- FALSE;closed <- FALSE;last_paint <- -Inf
  paint <- function(force=FALSE) {
    if(closed) return(invisible(NULL))
    now <- proc.time()[['elapsed']]
    if(force || now-last_paint>=0.03) {
      tcltk::tksee(output,'end');tcltk::tcl('update','idletasks');last_paint <<- now
    }
    invisible(NULL)
  }
  status <- function(text) {
    if(closed) return(invisible(NULL))
    tcltk::tclvalue(status_var) <- enc2utf8(paste(text,collapse='
'))
    paint(TRUE)
  }
  write_transcript <- function(value,force=FALSE) {
    if(closed) return(invisible(NULL))
    transcript <<- enc2utf8(value)
    tcltk::tclvalue(transcript_var) <- transcript
    actual <- tcltk::tclvalue(tcltk::tcl(output,'get','1.0','end-1c'))
    if(!identical(enc2utf8(actual),transcript))
      stop('The question-window transcript was not written to the text widget.')
    paint(force)
    invisible(NULL)
  }
  push <- function(text,force=FALSE) {
    write_transcript(paste0(transcript,enc2utf8(paste(text,collapse=''))),force)
  }
  set_busy <- function(value) {
    busy <<- value
    if(closed) return(invisible(NULL))
    tcltk::tkconfigure(run_button,state=if(value)'disabled' else 'normal')
    tcltk::tkconfigure(stop_button,state=if(value)'normal' else 'disabled')
    for(w in list(question,model_entry,key_entry)) if(!is.null(w))
      tcltk::tkconfigure(w,state=if(value)'disabled' else 'normal')
  }
  ask <- function(...) {
    if(busy || closed) return(invisible(NULL))
    q <- tcltk::tclvalue(question_var)
    if(!nzchar(trimws(q))) {status('\uc9c8\ubb38\uc744 \uc785\ub825\ud558\uc2ed\uc2dc\uc624.');return(invisible(NULL))}
    m <- trimws(tcltk::tclvalue(model_var))
    old_active <- getOption('r_ai_gui_active',FALSE)
    options(r_ai_gui_active=TRUE)
    set_busy(TRUE)
    on.exit({set_busy(FALSE);options(r_ai_gui_active=old_active)},add=TRUE)
    tryCatch({
      status('\uc694\uccad \uc900\ube44 \uc911...')
      push(paste0('

[\uc9c8\ubb38] ',q,'
',strrep('-',58L),'
'),TRUE)
      response_prefix <- transcript
      first <- TRUE
      receive <- function(text) {
        push(text,force=first);first <<- FALSE
        if(is.function(external_chunk)) external_chunk(text)
      }
      receive_status <- function(text) {
        status(text)
        if(is.function(external_status)) external_status(text)
      }
      args <- opts
      args$data <- data;args$prompt <- q;args$model <- if(nzchar(m))m else NULL
      args$api_key <- tcltk::tclvalue(key_var)
      args$viewer <- FALSE;args$window <- FALSE;args$echo <- FALSE
      args$on_chunk <- receive;args$on_status <- receive_status
      if(is.null(args$stream)) args$stream <- TRUE
      args$provider <- provider
      answer <- do.call(.ai_chat,args)
      # Reconcile with the returned answer even if a live callback did not run.
      if(is.character(answer) && length(answer)==1L)
        write_transcript(paste0(response_prefix,answer),TRUE)
      if(identical(.ai_state()$last$finish_reason,'cancelled')) {
        push('
[\uc911\uc9c0\ub428 \u00b7 \ubc1b\uc740 \ubcf8\ubb38 \ubcf4\uc874]
',TRUE);status('\uc911\uc9c0\ub428 \u00b7 \ubc1b\uc740 \ub0b4\uc6a9\uc740 ai_last_response()\ub85c \ud655\uc778\ud560 \uc218 \uc788\uc2b5\ub2c8\ub2e4.')
      } else push('
[\uc644\ub8cc]
',TRUE)
      invisible(answer)
    },interrupt=function(e) {
      if(!closed) {push('
[\uc911\uc9c0\ub428]
',TRUE);status('\uc0ac\uc6a9\uc790\uac00 \uc694\uccad\uc744 \uc911\uc9c0\ud588\uc2b5\ub2c8\ub2e4.')}
      invisible(NULL)
    },error=function(e) {
      message <- conditionMessage(e)
      if(!closed) {
        status(paste0('\uc624\ub958: ',message))
        tryCatch(push(paste0('
[\uc624\ub958] ',message,'
'),TRUE),error=function(display_error)
          warning('\uc9c8\ubb38\ucc3d \ucd9c\ub825 \uc624\ub958: ',conditionMessage(display_error),call.=FALSE))
      }
      invisible(NULL)
    })
    invisible(NULL)
  }
  run_button <- tcltk::tkbutton(query_bar,text='\uc9c8\ubb38 \uc2e4\ud589',command=ask)
  stop_button <- tcltk::tkbutton(query_bar,text='\uc751\ub2f5 \uc911\uc9c0',state='disabled',command=function(){
    if(busy) {ai_stop();status('\uc751\ub2f5\uc744 \uc911\uc9c0\ud558\ub294 \uc911...')}
  })
  tcltk::tkpack(stop_button,side='right');tcltk::tkpack(run_button,side='right')
  tcltk::tkbind(question,'<Return>',ask)
  tcltk::tkwm.protocol(top,'WM_DELETE_WINDOW',function(){
    if(busy) ai_stop()
    closed <<- TRUE
    try(tcltk::tcl('trace','remove','variable',transcript_var,'write',writer_command),silent=TRUE)
    try(tcltk::tcl('rename',writer_name,''),silent=TRUE)
    tcltk::tkdestroy(top)
  })
  push('\uc9c8\ubb38\uc744 \uc785\ub825\ud55c \ub4a4 [\uc9c8\ubb38 \uc2e4\ud589]\uc744 \ub204\ub974\uc2ed\uc2dc\uc624.
',TRUE)
  if(!is.null(initial_response) && nzchar(initial_response)) {
    push(paste0('\n[\uc774\uc804 \uc751\ub2f5 \ubcf5\uc6d0]\n',initial_response,'\n'),TRUE)
    status('\uc774\uc804 \uc751\ub2f5\uc744 \ubcf5\uc6d0\ud588\uc2b5\ub2c8\ub2e4. \ubaa8\ub378\uc5d0 \ub2e4\uc2dc \uc694\uccad\ud558\uc9c0 \uc54a\uc558\uc2b5\ub2c8\ub2e4.')
  }
  invisible(top)
}


#' Ollama 전용 질문창
#' @param data 선택적 분석 결과
#' @param ... ai_window 옵션
#' @export
ollama_window <- function(data = NULL, ...) ai_window('ollama', data = data, ...)

#' LM Studio 전용 질문창
#' @param data 선택적 분석 결과
#' @param ... ai_window 옵션
#' @export
lmstudio_window <- function(data = NULL, ...) ai_window('lmstudio', data = data, ...)

#' Google AI Studio 전용 질문창 (API 키 마스킹 입력)
#' @param data 선택적 분석 결과
#' @param ... ai_window 옵션
#' @export
aistudio_window <- function(data = NULL, ...) ai_window('aistudio', data = data, ...)


#' RStudio Viewer에서 실시간 출력하는 통합 함수
#' @param data 데이터프레임 또는 분석 결과
#' @param prompt 사용자 질문
#' @param provider ollama / lmstudio / aistudio
#' @param ... 해당 제공자 함수에 전달할 추가 인수
#' @return AI 답변 문자열 (invisible)
#' @export
ai_viewer <- function(data = NULL, prompt = NULL,
                      provider = c('lmstudio', 'ollama', 'aistudio', 'lemonade'), ...) {
  provider <- match.arg(provider)
  f <- switch(provider, lmstudio = lmstudio, ollama = ollama, aistudio = aistudio, lemonade = lemonade)
  f(data = data, prompt = prompt, viewer = TRUE, ...)
}

#' Lemonade text question window
#' @param data Optional analysis data.
#' @param ... Options passed to ai_window.
#' @export
lemonade_window <- function(data=NULL,...) ai_window('lemonade',data=data,...)

.ai_ui_dir <- function() {
  env <- environment(.ai_ui_dir)
  if(isNamespace(env)) return(system.file('assets','ui',package=getNamespaceName(env),mustWork=TRUE))
  normalizePath(file.path(dirname(.ai_math_dir()),'ui'),winslash='/',mustWork=TRUE)
}
.ai_json_read <- function(file,default=NULL) tryCatch(jsonlite::fromJSON(file,simplifyVector=FALSE),error=function(e)default)
.ai_json_write <- function(value,file) {
  tmp <- tempfile('json_',tmpdir=dirname(file))
  jsonlite::write_json(value,tmp,auto_unbox=TRUE,null='null',na='null',digits=NA)
  if(file.exists(file)) unlink(file)
  if(!file.rename(tmp,file)) {file.copy(tmp,file,overwrite=TRUE);unlink(tmp)}
  invisible(NULL)
}
.ai_history_dir <- function() file.path(tools::R_user_dir('jjstat','data'),'ai-history')
.ai_record_id <- function() paste0(format(Sys.time(),'%Y%m%dT%H%M%S'),'_',basename(tempfile('record_')))
.ai_history_write <- function(record,folder=.ai_history_dir()) {
  dir.create(folder,recursive=TRUE,showWarnings=FALSE)
  safe <- record[intersect(names(record),c('id','question','markdown','html','provider','model','created','updated','finish_reason','status'))]
  if(is.null(safe$id))safe$id <- .ai_record_id()
  if(!grepl('^[A-Za-z0-9_-]+$',safe$id))stop('Invalid history identifier.')
  .ai_json_write(safe,file.path(folder,paste0(safe$id,'.json')))
  invisible(safe$id)
}
.ai_history_records <- function(folder=.ai_history_dir()) {
  files <- list.files(folder,pattern='[.]json$',full.names=TRUE)
  records <- Filter(function(x)is.list(x)&&!is.null(x$id)&&!is.null(x$question),lapply(files,.ai_json_read))
  if(length(records))records <- records[order(vapply(records,function(x)if(is.null(x$updated))'' else x$updated,character(1)),decreasing=TRUE)]
  records
}
#' List locally saved AI questions and responses
#' @param limit Maximum number of recent records.
#' @return A data frame with record ID, question, provider, model and time.
#' @export
ai_history <- function(limit=100L) {
  rows <- utils::head(.ai_history_records(),as.integer(limit))
  if(!length(rows))return(data.frame(id=character(),question=character(),provider=character(),model=character(),updated=character()))
  do.call(rbind,lapply(rows,function(x)data.frame(id=x$id,question=x$question,provider=x$provider,model=x$model,updated=x$updated,stringsAsFactors=FALSE)))
}
.ai_runtime_info <- function() {
  env <- environment(.ai_web_window)
  if(isNamespace(env))return(list(package=getNamespaceName(env),libs=.libPaths(),assets=.ai_math_dir()))
  root <- dirname(dirname(.ai_math_assets))
  if(file.exists(file.path(root,'ai_web.R')))return(list(modules=normalizePath(root,winslash='/'),libs=.libPaths(),assets=.ai_math_dir()))
  script <- file.path(root,'ai_clients.R')
  if(file.exists(script))return(list(script=normalizePath(script,winslash='/'),libs=.libPaths(),assets=.ai_math_dir()))
  modules <- file.path(dirname(root),'R')
  if(!dir.exists(modules))stop('Cannot locate AI source modules.')
  list(modules=normalizePath(modules,winslash='/'),libs=.libPaths(),assets=.ai_math_dir())
}
.ai_web_worker <- function(boot) {
  .ai_require();if(!requireNamespace('commonmark',quietly=TRUE))stop('Install commonmark to render Markdown.')
  box <- boot$box;statefile <- file.path(box,'state.json');jobfile <- file.path(box,'job.json');lock <- file.path(box,'working')
  .ai_save_config(boot$provider,boot$config$base_url,boot$config$model,boot$config$api_key,FALSE)
  record <- .ai_json_read(statefile,list());last_write <- 0;rendered_text <- NULL
  publish <- function(force=FALSE) {
    now <- proc.time()[['elapsed']]
    if(!force && now-last_write<0.1)return(invisible(NULL))
    last_write <<- now
    if(!identical(rendered_text,record$markdown)){record$html <<- .ai_markdown_html(record$markdown);rendered_text <<- record$markdown}
    record$revision <<- paste0(Sys.time(),'_',nchar(record$markdown))
    .ai_json_write(record,statefile)
  }
  if(nzchar(record$markdown)) {
    seed <- .ai_state();query <- .ai_prompt(boot$data,record$question,100L,30000L)
    seed$last <- list(provider=boot$provider,model=boot$config$model,base_url=boot$config$base_url,
      question=record$question,text=record$markdown,finish_reason='restored',
      history=list(list(role='user',content=query$user),list(role='assistant',content=record$markdown)),
      options=boot$options)
  }
  writeLines('ready',file.path(box,'worker-ready'))
  repeat {
    if(file.exists(file.path(box,'quit')))break
    job <- .ai_json_read(jobfile)
    if(is.null(job)){Sys.sleep(0.025);next}
    file.create(lock)
    record <- list(id=job$id,job_id=job$id,question=job$question,markdown='',html='',provider=boot$provider,
      model=job$model,console_url=boot$console_url,created=format(Sys.time(),'%Y-%m-%dT%H:%M:%OS6%z'),updated='',status='\uc11c\ubc84 \uc751\ub2f5 \ub300\uae30 \uc911...',running=TRUE,finish_reason=NULL)
    if(identical(job$kind,'continue'))record$markdown <- ai_last_response()
    publish(TRUE);unlink(jobfile)
    cancel <- function() {
      if(file.exists(file.path(box,paste0('stop_',job$id)))||file.exists(file.path(box,'quit')))ai_stop()
    }
    args <- boot$options
    args$viewer <- FALSE;args$window <- FALSE;args$echo <- FALSE;args$progress <- FALSE
    args$on_chunk <- function(text){record$markdown <<- paste0(record$markdown,text);cancel();publish()}
    args$on_status <- function(text){record$status <<- text;cancel();publish()}
    tryCatch({
      if(identical(job$kind,'continue')) {
        args$prompt <- job$question
        answer <- do.call(ai_continue,args)
      } else {
        args$provider <- boot$provider;args$data <- boot$data;args$prompt <- job$question
        args$model <- if(nzchar(job$model))job$model else NULL
        args$base_url <- boot$config$base_url;args$api_key <- boot$config$api_key
        answer <- do.call(.ai_chat,args)
      }
      record$markdown <- as.character(answer)
      last <- .ai_state()$last;record$model <- last$model;record$finish_reason <- last$finish_reason
      record$status <- if(identical(last$finish_reason,'cancelled'))'\uc911\uc9c0\ub428 \u00b7 \ubc1b\uc740 \ub0b4\uc6a9\uc740 \uc800\uc7a5\ub418\uc5c8\uc2b5\ub2c8\ub2e4.' else if(.ai_truncated(last$finish_reason))'\ud1a0\ud070 \uc81c\ud55c \u00b7 \uc774\uc5b4\uc11c \uc791\uc131\ud560 \uc218 \uc788\uc2b5\ub2c8\ub2e4.' else '\uc644\ub8cc'
      if(!is.null(last$metrics))record$status <- paste(record$status,.ai_metric_text(last$metrics,last$metrics$elapsed_seconds,TRUE),sep='\n')
    },error=function(e){record$status <<- paste0('\uc624\ub958: ',conditionMessage(e));record$finish_reason <<- 'error'})
    record$running <- FALSE;record$updated <- format(Sys.time(),'%Y-%m-%dT%H:%M:%OS6%z')
    record$html <- .ai_markdown_html(record$markdown)
    .ai_history_write(record,boot$history)
    publish(TRUE)
    unlink(lock)
  }
}
.ai_web_http <- function(boot) {
  requireNamespace('jsonlite',quietly=TRUE)
  listener <- NULL
  for(port in (35000L+as.integer(Sys.getpid()%%15000L))+0:100) {
    listener <- tryCatch(serverSocket(port),error=function(e)NULL)
    if(!is.null(listener))break
  }
  if(is.null(listener))stop('No free local port.')
  on.exit(close(listener),add=TRUE)
  prefix <- paste0('/',boot$token,'/');origin <- paste0('http://127.0.0.1:',port)
  .ai_json_write(list(url=paste0(origin,prefix,'index.html')),file.path(boot$box,'server-ready.json'))
  last_contact <- proc.time()[['elapsed']];last_state <- .ai_json_read(file.path(boot$box,'state.json'),list())
  reply <- function(con,status,body,type='application/json; charset=utf-8') {
    if(!is.raw(body))body <- charToRaw(enc2utf8(body))
    header <- paste0('HTTP/1.1 ',status,'\r\nContent-Type: ',type,'\r\nContent-Length: ',length(body),
      '\r\nCache-Control: no-store\r\nConnection: close\r\nX-Content-Type-Options: nosniff\r\n\r\n')
    writeBin(c(charToRaw(header),body),con)
  }
  json <- function(con,value,status='200 OK')reply(con,status,jsonlite::toJSON(value,auto_unbox=TRUE,null='null'))
  snapshot <- function() {
    last_state <<- .ai_json_read(file.path(boot$box,'state.json'),last_state)
    if(file.exists(file.path(boot$box,'job.json'))||file.exists(file.path(boot$box,'working')))last_state$running <<- TRUE
    last_state
  }
  repeat {
    if(file.exists(file.path(boot$box,'quit')))break
    if(proc.time()[['elapsed']]-last_contact>300){writeLines('quit',file.path(boot$box,'quit'));break}
    if(!socketSelect(list(listener),timeout=0.25))next
    con <- socketAccept(listener,blocking=TRUE,open='r+b',timeout=2)
    tryCatch({
      line <- readLines(con,n=1L,warn=FALSE);headers <- character()
      if(!length(line))stop('Empty request')
      repeat {h<-readLines(con,n=1L,warn=FALSE);if(!length(h)||!nzchar(h))break;headers<-c(headers,h);if(sum(nchar(headers))>8192L)stop('Headers too large')}
      parts <- strsplit(line,' ',fixed=TRUE)[[1L]];method<-parts[1L];path<-sub('[?].*$','',parts[2L])
      if(!startsWith(path,prefix)){json(con,list(error='Not found'),'404 Not Found');next}
      last_contact <- proc.time()[['elapsed']]
      rel <- substring(path,nchar(prefix)+1L)
      if(grepl('(^|/)\\.\\.(/|$)|[\\\\:]',utils::URLdecode(rel)))stop('Invalid path')
      length_header <- grep('^Content-Length:',headers,value=TRUE,ignore.case=TRUE)
      count <- if(length(length_header))as.numeric(trimws(sub('^[^:]*:','',length_header[1L]))) else 0
      if(!is.finite(count)||count<0||count>1024*1024)stop('Invalid body size')
      payload <- if(count>0)jsonlite::fromJSON(rawToChar(readBin(con,'raw',count)),simplifyVector=FALSE) else list()
      if(method=='POST') {
        given_origin <- grep('^Origin:',headers,value=TRUE,ignore.case=TRUE)
        if(length(given_origin)&&trimws(sub('^[^:]*:','',given_origin[1L]))!=origin)stop('Origin not allowed')
        if(rel %in% c('api/ask','api/continue')) {
          s <- snapshot()
          if(isTRUE(s$running)){json(con,list(error='\ud604\uc7ac \uc751\ub2f5\uc744 \uc644\ub8cc\ud558\uac70\ub098 \uc911\uc9c0\ud55c \ub4a4 \uc2e4\ud589\ud558\uc2ed\uc2dc\uc624.'),'409 Conflict');next}
          if(!is.character(payload$question)||length(payload$question)!=1L||!nzchar(trimws(payload$question)))stop('\uc9c8\ubb38\uc744 \uc785\ub825\ud558\uc2ed\uc2dc\uc624.')
          if(nchar(payload$question)>30000L)stop('Question is too long.')
          if(!is.null(payload$model)&&(!is.character(payload$model)||length(payload$model)!=1L||is.na(payload$model)))stop('Invalid model.')
          if(rel=='api/continue'&&!nzchar(s$markdown))stop('No previous response to continue.')
          id <- .ai_record_id()
          .ai_json_write(list(id=id,question=payload$question,model=if(is.null(payload$model))'' else payload$model,
            kind=if(rel=='api/continue')'continue' else 'ask'),file.path(boot$box,'job.json'))
          json(con,list(id=id,accepted=TRUE),'202 Accepted')
        } else if(rel=='api/stop') {
          s<-snapshot();pending<-.ai_json_read(file.path(boot$box,'job.json'))
          id<-if(!is.null(pending$id))pending$id else s$job_id
          if(!is.null(id))writeLines('stop',file.path(boot$box,paste0('stop_',id)))
          json(con,list(stopped=TRUE))
        } else if(rel=='api/close'){writeLines('quit',file.path(boot$box,'quit'));json(con,list(closed=TRUE))}
        else json(con,list(error='Not found'),'404 Not Found')
      } else if(method=='GET'&&rel=='api/state')json(con,snapshot())
      else if(method=='GET'&&rel=='api/history') {
        records<-utils::head(.ai_history_records(boot$history),1000L)
        json(con,list(records=lapply(records,function(x)x[intersect(names(x),c('id','question','provider','model','created','updated','finish_reason'))])))
      } else if(method=='GET'&&startsWith(rel,'api/history/')) {
        id<-substring(rel,nchar('api/history/')+1L)
        if(!grepl('^[A-Za-z0-9_-]+$',id))stop('Invalid history ID')
        record<-.ai_json_read(file.path(boot$history,paste0(id,'.json')))
        if(is.null(record))json(con,list(error='\uae30\ub85d\uc744 \ucc3e\uc744 \uc218 \uc5c6\uc2b5\ub2c8\ub2e4.'),'404 Not Found') else {if(is.character(record$markdown)&&length(record$markdown)==1L)record$html<-.ai_markdown_html(record$markdown);json(con,record)}
      } else if(method=='GET'&&rel=='config.js') {
        s <- snapshot()
        reply(con,'200 OK',paste0('window.APP_CONFIG=',jsonlite::toJSON(list(mode='window',provider=s$provider,model=s$model,prompt=s$question,console_url=boot$console_url),auto_unbox=TRUE),';'),'text/javascript; charset=utf-8')
      } else if(method=='GET') {
        source<-if(rel=='index.html')file.path(boot$ui,'index.html') else if(startsWith(rel,'ui/'))file.path(boot$ui,substring(rel,4L)) else if(startsWith(rel,'katex/'))file.path(boot$assets,substring(rel,7L)) else ''
        if(!nzchar(source)||!file.exists(source)||dir.exists(source))json(con,list(error='Not found'),'404 Not Found') else {
          ext<-tolower(tools::file_ext(source));type<-switch(ext,html='text/html; charset=utf-8',js='text/javascript; charset=utf-8',css='text/css; charset=utf-8',woff2='font/woff2',woff='font/woff',ttf='font/ttf','application/octet-stream')
          reply(con,'200 OK',readBin(source,'raw',file.info(source)$size),type)
        }
      } else json(con,list(error='Method not allowed'),'405 Method Not Allowed')
    },error=function(e)try(json(con,list(error=conditionMessage(e)),'400 Bad Request'),silent=TRUE),finally=try(close(con),silent=TRUE))
  }
}
.ai_web_window <- function(provider,data=NULL,prompt='\uc774 \ubd84\uc11d\uacb0\uacfc\ub97c \uc124\uba85\ud574\uc918',model=NULL,api_key=NULL,
                           initial_response=NULL,launch=TRUE,history_dir=.ai_history_dir(),...) {
  .ai_require();provider<-.ai_provider(provider);opts<-list(...)
  if(!requireNamespace('commonmark',quietly=TRUE))stop('Install commonmark to render Markdown.')
  if(!is.null(initial_response)&&(!is.character(initial_response)||length(initial_response)!=1L||is.na(initial_response)))stop('initial_response must be a single string.')
  if(!is.character(prompt)||length(prompt)!=1L||is.na(prompt))stop('prompt must be a single string.')
  if(is.function(opts$on_chunk)||is.function(opts$on_status))stop('R callbacks are supported with engine="tk".')
  cfg<-.ai_config(provider)
  if(!is.null(opts$base_url))cfg$base_url<-opts$base_url
  if(!is.null(model))cfg$model<-model
  if(!is.null(api_key))cfg$api_key<-api_key
  cfg$base_url<-.ai_base(cfg$base_url)
  opts[intersect(names(opts),c('data','prompt','model','api_key','base_url','provider','viewer','window','echo','progress','on_chunk','on_status'))]<-NULL
  opts<-utils::modifyList(list(stream=TRUE,max_tokens=4096L,auto_continue=TRUE,max_continuations=3L),opts)
  box<-tempfile('jjstat_ai_web_');dir.create(box)
  runtime<-.ai_runtime_info();runtime$box<-box;runtime$ui<-.ai_ui_dir();runtime$history<-history_dir;runtime$console_url<-.ai_console_bridge()
  runtime$token<-paste0(basename(tempfile()),basename(tempfile()))
  state<-list(id=NULL,job_id=NULL,question=prompt,markdown=if(is.null(initial_response))'' else initial_response,
    html=if(is.null(initial_response))'' else .ai_markdown_html(initial_response),provider=provider,model=cfg$model,
    console_url=runtime$console_url,status='\uc900\ube44 \u00b7 \uc9c8\ubb38 \uc2e4\ud589 \ubc84\ud2bc\uc744 \ub20c\ub7ec \uc694\uccad\ud558\uc2ed\uc2dc\uc624.',running=FALSE,revision='initial')
  .ai_json_write(state,file.path(box,'state.json'))
  helper<-file.path(box,'helper.R')
  writeLines(c("if(.Platform$OS.type=='windows')try(Sys.setlocale('LC_CTYPE','Korean_Korea.utf8'),silent=TRUE)",
    "path<-commandArgs(TRUE)[1L];boot<-readRDS(path);unlink(path)",".libPaths(boot$libs)",
    "if(!is.null(boot$package)){ns<-asNamespace(boot$package)}else{ns<-new.env(parent=globalenv());if(!is.null(boot$script))source(boot$script,local=ns,encoding='UTF-8')else for(file in list.files(boot$modules,pattern='[.]R$',full.names=TRUE))source(file,local=ns,encoding='UTF-8');ns$.ai_math_assets<-boot$assets}",
    "get(boot$role,envir=ns)(boot)"),helper,useBytes=TRUE)
  worker<-runtime;worker$role<-'.ai_web_worker';worker$data<-data;worker$config<-cfg;worker$options<-opts;worker$provider<-provider
  http<-runtime;http$role<-'.ai_web_http'
  workerfile<-file.path(box,'worker.rds');httpfile<-file.path(box,'server.rds')
  saveRDS(worker,workerfile);saveRDS(http,httpfile);try(Sys.chmod(c(workerfile,httpfile),'0600'),silent=TRUE)
  rscript<-file.path(R.home('bin'),if(.Platform$OS.type=='windows')'Rscript.exe' else 'Rscript')
  workers<-lapply(c(workerfile,httpfile),function(file)processx::process$new(rscript,c('--vanilla',helper,file),
    stdout=file.path(box,paste0(basename(file),'.out')),stderr=file.path(box,paste0(basename(file),'.err')),windows_hide_window=TRUE,cleanup=TRUE))
  deadline<-proc.time()[['elapsed']]+20
  repeat {
    ready<-.ai_json_read(file.path(box,'server-ready.json'))
    if(!is.null(ready$url)&&file.exists(file.path(box,'worker-ready')))break
    if(any(!vapply(workers,function(p)p$is_alive(),logical(1)))||proc.time()[['elapsed']]>deadline) {
      for(p in workers)if(p$is_alive())p$kill()
      stop('AI window startup failed. Details: ',box)
    }
    Sys.sleep(0.025)
  }
  st<-.ai_state();st$web_windows<-c(Filter(function(x)any(vapply(x,function(p)p$is_alive(),logical(1))),st$web_windows),list(workers))
  url<-ready$url
  if(isTRUE(launch)) {
    edge<-c(Sys.which('msedge.exe'),file.path(Sys.getenv('ProgramFiles(x86)'),'Microsoft','Edge','Application','msedge.exe'),file.path(Sys.getenv('ProgramFiles'),'Microsoft','Edge','Application','msedge.exe'))
    edge<-edge[nzchar(edge)&file.exists(edge)]
    if(.Platform$OS.type=='windows'&&length(edge))processx::process$new(edge[1L],c(paste0('--app=',url),'--window-size=1200,920'),cleanup=FALSE,windows_hide_window=TRUE)
    else utils::browseURL(url)
  }
  shutdown<-function(){writeLines('quit',file.path(box,'quit'));invisible(NULL)}
  invisible(structure(list(url=url,close=shutdown,path=box,history_dir=history_dir),class='jjstat_ai_window'))
}

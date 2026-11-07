# jjstat AI 기능 병합용 폴더

이 폴더는 기존 `jjstat` 패키지에 합칠 파일 모음입니다. 기존 패키지의 DESCRIPTION, NAMESPACE, 버전, 저자, 라이선스를 교체하지 않습니다.

```text
jjstat_integration/
  R/                    # 기존 jjstat/R에 병합할 R 코드
    ai_clients.R        # Viewer, 수식, HTTP 스트리밍
    ai_settings.R       # 공급자 설정·모델 조회·로딩·연결 테스트
    ai_chat.R           # 대화 보존과 이어쓰기
    ai_providers.R      # 네 공급자 및 *_setting() 공개 함수
    ai_windows.R        # 질문창 공개 함수와 선택적 Tk 텍스트 창
    ai_web.R            # 독립 HTML 질문창·작업 프로세스·질문 기록
  inst/assets/ui/       # 로컬 Mermaid·DOMPurify·탭·복사 UI와 라이선스
  inst/assets/katex/    # jjstat/inst/assets/katex에 복사 (LICENSE·fonts 포함)
  man/                  # 생성된 함수 도움말
  tools/                # 개발·검증 도구; R/에 넣지 않음
  DESCRIPTION.additions # 기존 DESCRIPTION의 해당 필드에 추가할 항목
  NAMESPACE.additions   # 기존 NAMESPACE에 병합할 export 항목
```

## 기존 jjstat에 넣는 순서

1. 기존 `R/`에 같은 함수명이나 파일명이 있는지 확인합니다. 특히 `lmstudio`, `ollama`, `aistudio`, `ai_models`가 이미 있으면 중복 정의를 정리한 뒤 병합합니다.
2. 이 폴더의 `R/`, `inst/`, `man/` 내용을 기존 패키지의 같은 폴더로 복사합니다. 기존 파일을 통째로 덮어쓰지 말고 충돌을 확인합니다.
3. `DESCRIPTION.additions`에 적힌 패키지를 기존 DESCRIPTION의 Imports/Suggests 등에 합칩니다. Tcl/Tk 또는 RStudio가 없어도 패키지는 로드할 수 있습니다. `viewer=TRUE` 요청은 RStudio가 필요하며, 설정 창은 Tcl/Tk가 필요합니다.
4. roxygen2를 쓰면 패키지 루트에서 `devtools::document()`를 실행합니다. NAMESPACE를 수동 관리한다면 `NAMESPACE.additions`의 export 줄을 병합합니다.
5. `devtools::check()` 후 `devtools::install()`합니다. 기존 패키지 자체의 의존성·테스트도 함께 확인합니다.

설치된 패키지 이름은 실행 시 namespace에서 찾습니다. 따라서 기존 `jjstat`에 합친 뒤에도 수식 파일은 `system.file()`로 설치 위치에서 찾으며, 개발 당시의 절대 경로에 의존하지 않습니다.

## 설정 창

```r
library(jjstat)
ollama_setting()
lmstudio_setting()
aistudio_setting()
lemonade_setting()
```

각 함수는 별도 창을 엽니다. 서버 주소와 포트, API 키/토큰, 모델을 입력한 다음 다음 순서로 사용합니다.

1. **연결 / 모델 목록**: 실제 서버에 연결하여 텍스트 생성 모델을 가져옵니다.
2. 모델을 선택하거나 모델 ID를 직접 입력합니다.
3. **선택 모델 로드**: Ollama·Lemonade·LM Studio의 로딩 API를 호출합니다. Lemonade는 미설치 모델을 다운로드할 수 있습니다. LM Studio는 native v1 로딩 API를 제공하는 버전이 필요합니다.
4. **짧은 응답 테스트**: 선택 모델이 실제로 답하는지 확인합니다. API 키·모델 권한·생성 경로까지 확인하며, AI Studio에서는 사용량이 발생할 수 있습니다.
5. **설정 저장**: 이후 공급자 함수 호출에 적용합니다.

AI Studio는 클라우드 서비스이므로 로컬 모델 로딩 대신 **모델 사용 확인**을 제공합니다. 모델 목록에 나타난 사실과 실제 응답 성공을 구분합니다.

| 함수 | 기본 주소 |
|---|---|
| ollama | http://127.0.0.1:11434 |
| lmstudio | http://127.0.0.1:5678 |
| lemonade | http://127.0.0.1:13305/api/v1 |
| aistudio | https://generativelanguage.googleapis.com/v1beta |

LM Studio의 기존 사용자 포트 5678을 유지했습니다. 서버가 다른 포트에서 실행 중이면 설정 창에서 맞춥니다. Lemonade 주소는 사용 중인 서버에 맞춰 `/v1` 형태로도 입력할 수 있습니다.

API 키는 입력창에서 마스킹되며 현재 R 세션의 옵션에만 보관합니다. **주소·모델을 다음 R 세션에도 저장**을 체크하면 키를 제외한 주소와 모델만 `tools::R_user_dir('jjstat', 'config')` 아래에 저장합니다. AI Studio 키는 다음 세션에서 다시 입력하거나 `GEMINI_API_KEY` 환경변수로 제공합니다. LM Studio·Lemonade의 선택적 Bearer 토큰도 지원합니다.

창 없이 설정할 수도 있습니다.

```r
lemonade_setting(port=13305, model='실제 모델 ID', open=FALSE)
lmstudio_setting(port=1234, model='실제 모델 ID', open=FALSE)
ai_settings('lemonade')  # 키 원문은 반환하지 않음
```

## 기본 Viewer와 분석 요청

네 공급자 함수 모두 `viewer=TRUE`가 기본입니다. RStudio Viewer에서 응답을 스트리밍하고 콘솔에는 추정 진행률과 경과 시간을 표시합니다. 기본 출력 토큰 한도는 4096입니다.

```r
ttest_results$I_insa %>%
  Round(2) %>%
  Unite('t_value', 'sig') %>%
  replace_df_rep(stat_labels) %>%
  lmstudio('분석결과를 표로 제시하고 APA 7판 형식의 보고서를 ~이다 학술체로 작성해줘')

lemonade('이 결과를 설명해줘')
```

`viewer=FALSE`는 RStudio 외 환경에서 사용하거나 콘솔 스트리밍이 필요할 때 지정합니다. `progress=FALSE`로 진행률을 끌 수 있습니다. `echo=TRUE, stream=TRUE`이면 콘솔 본문을 즉시 스트리밍합니다.

Viewer는 기본 흰 배경, 라이트·다크 전환, 표별 복사, 질문·응답 전체 복사와 오프라인 KaTeX 수식을 지원합니다. 복사한 표는 HTML과 탭 구분 텍스트로 전달됩니다.

## 응답이 끊겼을 때

출력 토큰 한도로 종료되었다는 서버의 신호(`length`, `MAX_TOKENS` 등)를 받으면 기본적으로 최대 3회 자동 이어쓰기를 수행합니다. 원래 분석 데이터, 질문, 이미 작성한 답변을 대화 이력으로 전달하며 Viewer와 반환 문자열에 이어 붙입니다. 끝나지 않은 문장·표·코드블록을 이어 쓰도록 요청합니다.

```r
# 더 긴 보고서: 요청별 토큰 한도와 자동 추가 요청 횟수
lmstudio('긴 보고서를 작성해줘', max_tokens=8192, max_continuations=5)

# 자동으로 이어 쓰지 않고 결과를 확인
lmstudio('보고서를 작성해줘', auto_continue=FALSE)

# 마지막 답변을 직접 이어 쓰고, 전체 누적 응답을 반환
report <- ai_continue()

# 자연스럽게 종료됐지만 다음 절을 추가하고 싶을 때
report <- ai_continue('앞서 작성한 보고서에 이어 논의와 결론을 작성해줘')

# 중단 직전까지 수신한 텍스트 확인
ai_last_response()
```

통신 실패나 종료 신호 없이 끝난 스트림은 정상 완료로 처리하지 않습니다. 받은 본문을 보존하므로 연결을 복구한 뒤 `ai_continue()`로 재개할 수 있습니다. 자동 이어쓰기 횟수에 도달하면 경고와 함께 부분 결과를 반환합니다. 안전 차단 등 토큰 제한 이외의 이유에는 자동 이어쓰기를 하지 않습니다.

이어쓰기는 모델에 대한 추가 생성 요청이므로 모델에 따라 일부 문장이 반복되거나 문맥 연결이 매끄럽지 않을 수 있습니다. 대화가 모델의 입력 문맥 한도를 넘으면 서버 설정을 늘리거나 내용을 줄여 새로 요청해야 합니다. `max_tokens`는 각 요청의 출력 한도이며 입력 문맥 크기와는 다릅니다. 원래 데이터를 임의로 잘라 이어쓰지는 않습니다. 대화는 현재 R 세션의 마지막 요청을 기준으로 보관하며 파일로 자동 저장하지 않습니다.

## 개발 검증

이 폴더에서 다음을 실행합니다. 서버는 로컬 모의 서버를 사용하며 실제 모델/API 키가 필요하지 않습니다. 공급자 검증에는 Node.js가 필요합니다.

```text
Rscript --vanilla tools/verify_math.R
node tools/verify_math.js
Rscript --vanilla tools/verify_progress.R
Rscript --vanilla tools/verify_providers.R
```

KaTeX 원본 라이선스는 `inst/assets/katex/LICENSE`에 포함되어 있습니다. `verification/`에 생성되는 결과와 임시 패키지는 배포 파일에 넣지 않습니다.

## 구현에 참고한 공식 API 문서

- [Lemonade 모델 및 생성 API](https://lemonade-server.ai/docs/api/)
- [LM Studio 모델 로딩 API](https://lmstudio.ai/docs/developer/rest/load)
- [Ollama 대화 API](https://docs.ollama.com/api/chat)
- [Gemini 생성 및 종료 사유](https://ai.google.dev/api/generate-content)

검증 범위와 결과는 [VALIDATION.md](VALIDATION.md)에 기록했습니다.

## Context와 생성 속도

기본 진행률 줄과 Viewer 완료 상태에 토큰 지표를 표시합니다.

```text
[AI] [====================] 100% | 완료 | 118.9초
| Context = 1,234 tok | Output = 1,332 tok | 11.2 tok/s
```

- `Context`는 이번 요청의 입력 토큰 수입니다. 시스템 지시문·분석 데이터·전달한 대화 이력 등을 포함하는 서버 카운터이며, 모델의 최대 문맥 용량과는 다릅니다.
- `Output`은 서버가 보고한 이번 요청의 출력 토큰 수입니다. Gemini의 내부 thinking 토큰은 보이는 응답 토큰과 별도로 취급합니다.
- Ollama의 `eval_count / eval_duration`, LM Studio의 처리량 통계, Lemonade의 `timings`가 있으면 서버의 생성 속도를 사용합니다.
- 서버의 생성 시간 통계가 없지만 출력 토큰 수가 있으면 전체 요청 경과 시간으로 나누고 `tok/s (요청 평균)`으로 표시합니다. 이 값에는 서버 대기·로딩·입력 처리·통신 시간이 포함됩니다.
- 토큰 수는 글자 수로 추정하지 않습니다. 아직 도착하지 않은 값은 `--`, 완료 후에도 서버가 제공하지 않은 값은 `미제공`으로 표시합니다. 서버에 따라 카운터는 응답 마지막에만 도착합니다.
- 자동·수동 이어쓰기에서는 각 추가 요청의 지표를 표시합니다. 대화가 다시 입력되므로 각 요청의 Context를 단순 합산하지 않습니다.
- LM Studio·Lemonade의 스트리밍 요청에는 `stream_options.include_usage=TRUE`를 전달합니다. 이를 지원하지 않는 구버전 서버라면 `include_usage=FALSE`를 지정할 수 있으며 제공되지 않는 카운터는 표시할 수 없습니다.

수정 후 `ai_clients.R`을 다시 `source()`하거나 병합한 패키지를 다시 설치·로드해야 적용됩니다. 토큰 메타데이터 검증은 `Rscript --vanilla tools/verify_metrics.R`로 실행합니다.

## 빠른 스트리밍·두 줄 진행률·중지

네 공급자 함수의 공개 인수에 `stream=TRUE`가 기본값으로 표시됩니다.

```r
lmstudio('보고서를 작성해줘', stream=TRUE)
# 콘솔 본문도 즉시 확인하려면 (진행 막대 대신 본문 스트리밍)
lmstudio('보고서를 작성해줘', stream=TRUE, echo=TRUE)
# 완성된 응답을 한 번에 받으려면
lmstudio('보고서를 작성해줘', stream=FALSE)
```

저장한 모델/주소가 있으면 모델 목록 조회·연결 테스트·모델 재로딩 없이 바로 생성 POST를 보냅니다. 최초 자동 선택한 모델도 세션에 재사용합니다. curl 버퍼링을 끄고 25ms 간격으로 수신하며, 첫 본문은 바로 Viewer 스냅샷에 저장합니다. 이후 스냅샷은 최대 100ms 간격으로 갱신하고 Viewer도 100ms 간격으로 확인합니다. 상태 정보만 바뀌면 이미 변환한 Markdown HTML을 재사용합니다.

추론 전용 이벤트와 본문을 구분합니다. 모델이 reasoning/thinking만 보내는 동안은 **모델 추론 중 (본문 대기)**라고 표시하며, 추론 텍스트를 보고서 본문에 섞지 않습니다. 생성된 토큰 전부가 추론인 경우 본문은 추론이 끝난 뒤에야 도착할 수 있습니다. `stream=TRUE`는 도착한 본문을 즉시 전달하는 옵션입니다.

진행률과 지표를 두 줄로 표시합니다.

```text
[AI] [====================] 100% | 완료 | 201.6초
| Context = 547 tok | Output = 2,668 tok | 13.2 tok/s (요청 평균)
```

생성 중에는 두 번째 줄의 수신 정보를 갱신합니다. 서버가 실사용량을 매번 보내면 그 값을 사용합니다. 실사용량이 마지막에만 오는 서버에서는 다음처럼 스트림 조각 수 기준 추정치에 `≈`와 `추정`을 붙이며, 실제 사용량이 오면 교체합니다. 하나의 조각이 여러 토큰일 수 있어 정확한 토큰 수와 일치하지 않습니다. 입력 Context는 서버 카운터를 받을 때까지 `--`로 표시합니다. 토큰 수를 얻으려고 매번 토큰화 API를 호출하거나 본문 전달을 지연하지 않습니다.

```text
[AI] [=======             ]  46% | 응답 생성 중 · 추정 | 12.3초
| Context = -- | Output = ≈178 tok (추정) | ≈19.4 tok/s (수신 추정)
```

RStudio에서는 두 번째 줄을 계속 갱신하고, 단계 변경·완료 시 첫 줄을 새로 표시합니다. 일반 터미널이 커서 이동을 지원하면 두 줄을 제자리에서 갱신합니다.

Viewer 상단 **응답 중지** 버튼으로 연결을 끊을 수 있습니다. 본문이 아직 없어도 중지할 수 있으며, 받은 본문은 보존합니다. 중지 요청은 현재 Viewer의 임의 토큰으로 보호된 로컬 제어 주소로만 전달됩니다. 추가 패키지나 별도 상주 서버를 설치하지 않습니다. 요청이 끝나면 제어 포트를 닫고 버튼을 비활성화합니다.

```r
# 중지한 뒤 받은 내용 확인
ai_last_response()
# 일부 본문을 받았다면 이어 쓰기
ai_continue()
# 사용자 콜백·Tk 버튼 등에서도 중지 가능
ai_stop()
```

RStudio 콘솔이 실행 중일 때 다른 R 명령을 입력할 수는 없으므로, 즉시 중지할 때는 Viewer 버튼 또는 RStudio의 Esc/Stop을 사용합니다. `ai_stop()`는 콜백이나 Tk 이벤트에서 호출할 수 있습니다. `echo=TRUE, stream=TRUE`는 콘솔 본문 전달을 우선하고 진행 막대는 생략합니다.

GPU 설정 적용 내용은 병합용 폴더의 `GPU_SETUP.md`를 참고하십시오.

## Markdown/PV 질문창과 질문 기록

```r
# 기존 창을 닫고 새 코드와 assets를 다시 불러옵니다.
source('ai_clients.R', encoding='UTF-8')
ttest_results$I_insa %>% lmstudio_window()
# 같은 화면: ollama_window(), lemonade_window(), aistudio_window()
```

기본 질문창은 독립 HTML 창입니다. Windows에서는 Edge 앱 창을 열며, Edge를 찾지 못하면 기본 브라우저를 사용합니다. RStudio 콘솔을 점유하지 않는 별도 R 작업 프로세스가 스트리밍을 처리합니다. Node.js나 Shiny를 설치할 필요가 없습니다. 저장된 주소·모델·세션 API 키를 사용하며, 모델 확인 요청 없이 질문 실행 버튼을 누르면 생성 요청을 보냅니다.

- **PV 미리보기 / Markdown 원문** 탭을 전환합니다. `viewer=TRUE`에도 같은 탭과 렌더러를 사용합니다.
- 표 복사는 HTML 표와 탭 구분 텍스트, 코드 복사는 코드 원문을 제공합니다.
- fenced `mermaid` 코드는 다이어그램으로 렌더링합니다. 코드 보기와 코드 복사도 제공합니다. 스트리밍 중에는 닫힌 코드 블록부터 렌더링합니다. 문법 오류 시 코드를 보존하고 오류를 표시합니다.
- **PV 전체 복사**는 렌더링된 본문과 표를 복사하고, Mermaid는 가능한 경우 PNG 이미지로 변환합니다. 붙여넣는 앱의 HTML/이미지 지원에 따라 결과가 달라질 수 있습니다. 수식의 복사 텍스트는 TeX 원문을 사용합니다.
- **MD 복사 / MD 다운로드**는 원래 Markdown 본문을 보존합니다. 다이어그램 코드도 포함됩니다.
- 질문은 여러 줄로 입력하며 입력창 아래 모서리를 끌어 높이를 조절할 수 있습니다. Enter는 줄바꿈, Ctrl+Enter 또는 **질문 실행**은 요청 실행입니다. 창 전체도 크기를 조절할 수 있습니다. 창을 열 때 자동 요청하지 않습니다.
- **새 질문**은 입력과 표시를 비우고 원래 분석 데이터를 유지하여 새로운 독립 요청을 준비합니다. **이어서 작성**은 현재 응답과 대화를 이어갑니다. 실행 중 **응답 중지**로 멈춰도 받은 내용은 보존됩니다.
- **질문 히스토리**에서 저장된 질문을 선택하면 질문과 응답을 다시 볼 수 있습니다. 완료·중지·오류 시 질문, 응답, 공급자, 모델, 시각을 로컬 JSON으로 저장합니다. API 키와 원래 분석 객체는 따로 저장하지 않습니다. 보고서에는 분석 내용이 포함될 수 있습니다.

기록 위치는 `file.path(tools::R_user_dir('jjstat','data'),'ai-history')`이며, `ai_history()`로 최근 기록 목록을 볼 수 있습니다. 이 디렉터리는 R을 다시 실행해도 유지됩니다. 질문창의 작업 프로세스에서 생성한 응답은 질문창과 기록에서 확인합니다. 주 R 세션의 `ai_last_response()`는 주 세션에서 실행한 요청을 반환합니다. 새 질문창의 설정 변경은 이미 열린 창에 적용되지 않으므로 설정 변경 후 새 창을 여십시오.

이전 R 응답을 요청 없이 복원하려면 `lmstudio_window(initial_response=ai_last_response())`를 사용합니다. 기존 Tcl/Tk 텍스트 창과 R 콜백이 필요하면 `lmstudio_window(engine='tk', on_chunk=function(text) ...)`를 사용합니다. Markdown/PV·Mermaid·다운로드·저장 기록 기능은 기본 web 창에서 제공합니다.

RStudio Viewer는 `lmstudio('질문', viewer=TRUE)`처럼 사용합니다. Viewer의 질문 실행·기록 관리는 별도 질문창에서 제공합니다. KaTeX·Mermaid·DOMPurify·UI 파일을 모두 함께 배포하므로 렌더링에 외부 CDN을 사용하지 않습니다. 창을 닫으면 로컬 보조 프로세스는 유휴 시간 후 종료되고, R 세션 종료 시에도 정리됩니다.

## 상단 메뉴 · 특수문자 볼드 · toConsole (2026-11-08)

PV/Markdown 탭과 복사·다운로드 메뉴를 제목 옆 상단 도구막대에 모았습니다. 질문과 상태는 그 아래 작은 줄에 표시하고, 긴 질문은 마우스를 올리면 전체 내용을 볼 수 있습니다. 좁은 화면에서는 메뉴가 줄바꿈됩니다. 질문창의 입력란 크기 조절도 유지합니다.

짝을 이룬 `**...**`는 괄호, 따옴표, 세미콜론, 대괄호 등 내부 문장부호나 뒤에 붙은 한글 때문에 볼드가 풀리지 않도록 처리합니다. 볼드 안의 링크·인라인 코드·수식을 유지하고, 표 셀 안의 볼드에 포함된 `|`도 셀을 나누지 않습니다. 코드 블록과 코드 문자열의 `**`는 원문으로 보존합니다. 저장 기록을 다시 열 때도 현재 렌더러를 적용합니다. 원래 Markdown 파일 내용은 바꾸지 않습니다.

R 코드 블록에는 **코드 복사** 옆에 **toConsole**이 있습니다. 누르면 해당 코드 전체를 주 RStudio 세션의 콘솔 입력란으로 보냅니다. `rstudioapi::sendToConsole(..., execute=FALSE)`를 사용하므로 자동 실행하지 않으며, 사용자가 Enter를 눌러 실행합니다. Viewer와 기본 HTML 질문창에서 모두 지원하며, 응답 완료 후에도 사용할 수 있습니다.

이 기능은 RStudio와 `later` 패키지가 필요합니다. 독립 스크립트 사용 중 버튼이 비활성화되면 RStudio에서 `install.packages('later')` 후 코드를 다시 source()하고 새 창을 여십시오. RStudio 밖에서는 콘솔 전송 버튼을 비활성화하며 코드 복사는 그대로 사용할 수 있습니다. jjstat에는 DESCRIPTION.additions의 Imports에 later를 함께 병합합니다. 기존 창은 닫고 새 코드를 다시 불러와야 UI와 브리지가 갱신됩니다.

## 답변 중심 접기 화면 (2026-11-08)

기본 화면은 질문 입력·질문/토큰 정보·상세 메뉴를 접고 답변을 크게 표시합니다.

- **+ 질문**: 입력창을 열거나 접습니다. 접어도 작성 중인 질문은 보존합니다. 질문 실행 후에는 자동으로 접힙니다. 실행은 질문 실행 버튼 또는 Ctrl+Enter로만 시작합니다.
- **모델**: 상단의 작은 입력칸에서 확인·변경합니다. 긴 모델 ID는 마우스를 올려 전체 이름을 볼 수 있습니다.
- **PV / MD**: 상단의 작은 탭으로 전환합니다.
- **+ 정보**: 전체 질문, 진행 상태, Context/Output/tok/s 정보를 펼쳐 봅니다. 다시 눌러 접습니다. 작은 상태 표시는 상단에 유지합니다.
- **⋯ 메뉴**: PV/MD 복사, MD 다운로드, 새 질문, 이어쓰기, 질문 기록, 테마 기능을 열어 사용합니다. 메뉴는 답변 위에 잠시 펼쳐지고, 항목 선택·바깥 클릭·Esc로 닫습니다.
- 새 질문은 입력창을 열며, 기록을 선택하면 입력창과 기록 패널을 접어 선택한 답변을 넓게 보여줍니다.

Viewer에도 작은 PV/MD 탭, 정보 접기, 상세 메뉴를 적용합니다. Viewer의 새 질문은 별도 *_window()에서 작성합니다. 기존 창을 닫고 현재 ai_clients.R을 다시 source()한 뒤 새 질문창을 열어야 새 화면이 적용됩니다. jjstat 설치본은 inst/assets/ui를 포함하여 다시 설치합니다.

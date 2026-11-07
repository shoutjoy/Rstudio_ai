# 검증 기록 · 2026-11-07

- Windows / R 4.4.1에서 별도 jjstat 검증 패키지로 빌드·설치·로드·namespace·도움말·설치 후 수식 경로를 검사했습니다.
- `R CMD check --no-manual --no-build-vignettes`: 오류 0, 경고 0, NOTE 1. NOTE는 설치 크기(11.0MB, 수식 자산·도움말 등)에 관한 것입니다.
- 원래 jjstat 패키지나 설치된 jjstat는 변경하지 않았습니다. 기존 패키지에 병합한 뒤 그 패키지 전체에 대한 check는 별도로 필요합니다.
- 네 공급자의 모델 조회·로딩·짧은 응답, 스트리밍/비스트리밍 자동 이어쓰기, 수동 이어쓰기, 원래 데이터 보존, 부분 응답 복구, 자동 반복 횟수 제한을 로컬 모의 HTTP 서버로 검증했습니다.
- 실제 Tcl/Tk 설정 창을 생성하고 각 버튼을 실행해 목록·로딩·응답·저장 결과를 확인했습니다. 화면의 시각적 배치는 별도 육안 검사하지 않았습니다.
- 수식/코드/스트리밍 사례 17개, 실제 KaTeX 변환 6개, 폰트 파일, Viewer JavaScript 문법 및 기존 진행률 검증을 통과했습니다.
- 실제 Ollama / Lemonade 모델, Google API 키, 최종 RStudio 세션에서의 생성 품질과 문장 반복 여부는 검증하지 않았습니다. LM Studio에 대한 추가 실측은 아래에 기록했습니다.

## 토큰 지표 추가 검증

- 네 공급자 모두 스트리밍·비스트리밍 입력/출력 토큰 카운터, 마지막 usage 전용 이벤트, OpenAI 호환 include_usage 요청을 모의 서버로 검증했습니다.
- 서버 처리량 11.2 tok/s, Ollama 나노초 단위 생성 시간 변환, 생성 시간이 없는 응답의 요청 평균 표시, 미제공·잘못된 카운터 처리와 Viewer 완료 상태를 검증했습니다.
- 기존 공급자·설정 창·이어쓰기·진행률 회귀 검증을 통과했습니다.
- 변경 후 별도 패키지 R CMD check: 오류 0, 경고 0, 설치 크기 NOTE 1개입니다. 실제 서버의 카운터 제공 여부는 서버 버전·백엔드에 따라 달라집니다.

## 빠른 스트리밍·두 줄·실시간 수신 지표·중지 추가 검증

- `stream=TRUE`를 네 공개 함수의 기본 인수로 노출하고 FALSE 전달도 검증했습니다.
- 저장 모델을 사용할 때 조회/로딩 없이 POST만 보내는 경로를 검증했습니다.
- 시간 차를 둔 모의 스트림에서 서버 완료 전에 콜백과 실제 Viewer 파일이 갱신됨을 확인했습니다. 최초 측정에서 첫 본문 전송→스냅샷 저장은 21~38ms였고, 부하가 있는 병렬 검증에서는 84~135ms였습니다.
- 실제 로드된 Gemma 12B의 짧은 스트림에서 31개 이벤트 중 reasoning_content 29개, 본문 0개, 토큰 한도 종료를 확인했습니다. 이 상태를 서버 대기와 구분하도록 수정했습니다.
- 실제 Gemma E4B GPU 설정 변경 후 단순 요청은 첫 본문 약 1.21초, 전체 약 1.22초에 도착했습니다. 이전 12B 테스트와 모델/설정이 다르므로 같은 모델의 속도 비교로 해석하지 않습니다.
- 실제 Edge에서 중지 버튼 클릭→로컬 제어 POST→R curl 종료→부분 응답 보존→중지 상태·버튼 비활성화를 검증했습니다.
- 생성 전/도중 중지, 콜백 ai_stop(), 중지 후 ai_continue(), 중지 시 100% 미표시를 검증했습니다.
- 두 줄 표시와 수신 조각 기준 ≈ 추정치, 서버 카운터 우선 사용을 검증했습니다. 입력 Context 카운터를 받기 전에는 --로 표시합니다.
- 별도 jjstat 검증 패키지의 검사 결과는 오류 0, 경고 0, 설치 크기 NOTE 1개입니다.

실제 GPU 변경과 적용 범위는 [GPU_SETUP.md](GPU_SETUP.md)에 기록했습니다.

## 새 질문창 출력 보완 검증

- R 4.3.3 및 R 4.4.1에서 네 공급자의 실제 Tk 질문창 버튼을 모의 서버와 연결했습니다.
- 버튼을 누르기 전 요청하지 않음, 파이프 입력과 추가 옵션 보존, 첫 본문이 완료 전에 텍스트 위젯에 삽입됨, 스트리밍/비스트리밍 결과 표시를 검증했습니다.
- 추론 상태 별도 표시, 사용자 콜백과 창 출력의 동시 작동, 오류 본문 표시, 실행 버튼 복원, Tk 중지 버튼과 부분 본문 보존을 검증했습니다.
- 기존 토큰 지표·Viewer 중지 검증도 통과했습니다. 실제 사용자 ttest_results 객체를 이용한 모델의 최종 보고서 품질은 이 검증에 포함하지 않았습니다.

## 실제 기록 누락 재점검

- 실제 사용자 창에서 완료·Output 2,687 tok 상태인데 초기 안내문만 남아 있는 화면을 관찰했습니다. 기존 단순 위젯 검증으로는 이 화면 문제까지 확인하지 못했음을 구분했습니다.
- Tcl 변수 추적을 통한 기록, 기록 직후 위젯 내용 일치 검사, 완료 응답 전체 재확정을 추가했습니다.
- 실제 LM Studio의 Gemma E4B에 별도 R 4.3.3 네이티브 질문창에서 버튼을 클릭해 요청하고, 질문·표·본문이 화면에 남는 것을 Windows 화면 캡처로 확인했습니다. 사용자 분석 자료가 아닌 합성 두 행 데이터로 검사했습니다.
- 실시간 콜백을 의도적으로 호출하지 않는 모의 함수에서도 반환된 전체 응답을 창에 기록하는 회귀 사례를 검증했습니다.
- initial_response로 이미 완성된 응답을 새 모델 요청 없이 표시하는 경로를 검증했습니다.

최종 Tcl 기록·완료 응답 재확정·기존 응답 복원 경로는 R 4.3.3과 R 4.4.1에서 모두 통과했습니다. 변경 후 패키지 검사 결과도 오류 0, 경고 0, 설치 크기 NOTE 1개입니다.


## Markdown/PV web window verification (2026-11-07)

- Edge + local streamed mock: no request on opening; response painted before completion; Markdown/PV tabs; KaTeX; Mermaid SVG with 3 nodes; theme switch.
- Inspected clipboard payloads: table HTML + TSV, exact code text, full PV without copy controls, Mermaid PNG embedded in copied HTML. Exact raw MD download verified, including original line endings.
- New questions, stop with partial response, continuation, history loading verified. No API key in history metadata. An independent R 4.3.3 module-loaded window reopened persisted history and restored initial_response without requesting AI.
- Actual Viewer writer emitted local assets; the generated file-URL page rendered table, math and Mermaid. Current change was not manually clicked inside the RStudio Viewer pane.
- Existing 7 R regressions and KaTeX JS check passed on R 4.4.1. Installed-package smoke launched the web workers. R CMD check: 0 errors, 0 warnings, 1 installed-size NOTE (6.1 MB).
- The new UI was tested with a mock provider. LM Studio port 5678 was unavailable at final verification. The earlier real-model Tk test does not count as a real-provider test of the new web UI.

Browser test: from standalone root run `Rscript --vanilla jjstat_integration/tools/verify_web.R`; from integration root run `Rscript --vanilla tools/verify_web.R`. Set PLAYWRIGHT_MODULE to the Playwright module directory if not locally installed. Edge is required by this development test. Node/Playwright are not needed by R users.

Vendored renderer build: inside tools/ui-build, run npm ci and node build.cjs. Copy inst/assets/ui to standalone assets/ui after updating. Preserve THIRD_PARTY_LICENSES.txt and review dependency license changes when upgrading dependencies. Runtime rendering uses no CDN.


## Compact toolbar, relaxed strong emphasis, toConsole (2026-11-08)

- Browser checked the common toolbar position and compact Viewer header, plus R-only toConsole buttons in both web window and generated Viewer page. Clicks delivered the original code to a stubbed RStudio API with execute=FALSE; no model code was evaluated.
- Persistent parent-session bridge was verified through later callbacks after the response writer closed. UTF-8 code larger than 8 KB round-tripped exactly. This validates the API bridge; it does not claim a manual click inside the user's actual RStudio session.
- R 4.3.3 and R 4.4.1 focused checks cover punctuation and adjacent Korean bold, nested inline code/link/math, table-cell pipes, literal fenced/indented code, and console insertion without execution.
- Existing R regressions and browser copy/download/stream/stop/history checks passed. Mermaid node labels also remain visible as SVG text.
- R CMD check with later Imports: 0 errors, 0 warnings, 1 NOTE (6.2 MB installed size). Later UI/source refinements also passed browser and focused regressions.
- Focused developer commands: Rscript --vanilla tools/verify_bold.R and Rscript --vanilla tools/verify_console.R from the integration root. The browser test uses a local mock provider and a sendToConsole API stub, preserving the user's console.


## Answer-first collapsible UI (2026-11-08)

UI-only change; no R request/transport code or dependencies changed. Edge browser verified: composer, info and overflow menu initially collapsed; prompt retained on fold; fold actions never request AI; accepted requests automatically fold composer; new question opens it; history selection closes panels. PV/MD, copy/download, math, Mermaid labels, stop, continuation, history and toConsole regressions passed. Viewer info toggle and hidden question editor also passed.

At 780x820, the collapsed answer starts within 90px of the top and exceeds 650px height. Model input is <=160px. At 400px wide, the overflow menu stays entirely within the viewport. Escape closes it. Generated screenshots are verification/web-smoke/window-780.png and viewer.png in the test output folder. API generation remains a mock and toConsole uses an API stub in this automated test.

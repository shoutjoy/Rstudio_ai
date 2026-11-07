# 로컬 GPU 적용 기록 · 2026-11-07

실측 장비: NVIDIA GeForce RTX 4060 Laptop GPU, 전용 VRAM 8,188MiB. CPU 전용 상태는 아니었으며 CUDA 백엔드가 실행 중이었습니다.

## LM Studio

유휴 상태를 확인한 뒤 기존 Gemma E4B만 재로딩했습니다. 모델 선택은 유지했습니다.

| 항목 | 변경 전 | 변경 후 |
|---|---|---|
| 모델 | google/gemma-4-e4b | 동일 |
| 컨텍스트 | 131,072 | 16,384 |
| GPU 오프로딩 | 실행 인수 18 레이어 | GPU max, 실행 인수 39 레이어 |
| 동시 요청 | 1 | 1 |

실제 실행 프로세스: NVIDIA CUDA12 llama-server. CLI는 5.89GiB 로딩 메모리를 보고했습니다. 적용 후 짧은 실제 R 요청에서 첫 본문은 약 1.21초, 전체 응답은 약 1.22초에 도착했습니다. 단순 테스트 문장에 대한 결과이며 긴 통계 보고서의 속도와는 다릅니다.

현재 로딩에 적용한 명령은 다음과 같습니다. 앱에서 다른 설정으로 다시 로딩하면 달라질 수 있습니다. 진행 중인 요청은 중단하지 말고 유휴 상태에서 적용합니다.

```powershell
lms ps --json
lms unload google/gemma-4-e4b
lms load google/gemma-4-e4b --gpu max --context-length 16384 --parallel 1 --identifier google/gemma-4-e4b --yes
```

컨텍스트를 줄였으므로 입력 이력과 생성 길이는 16,384 토큰 범위 안에서 사용해야 합니다. 더 큰 문맥을 사용하면 GPU 메모리 요구량이 다시 늘어납니다.

## Lemonade

현재 서버 설정에 저장했습니다. 다음 llama.cpp 모델 로딩부터 적용됩니다.

```text
llamacpp.backend = cuda
llamacpp.prefer_system = false
ctx_size = 16384
```

CUDA 백엔드가 이미 설치되어 있음을 확인했습니다. GPU가 부족한 상태에서 별도 모델을 추가 로딩하지는 않았습니다.

## Ollama

서버가 종료 상태여서 모델 실행은 검증하지 않았습니다. 사용자 환경변수에 다음 실행부터 적용할 설정을 저장했습니다.

```text
OLLAMA_CONTEXT_LENGTH=16384
OLLAMA_NUM_PARALLEL=1
OLLAMA_MAX_LOADED_MODELS=1
OLLAMA_FLASH_ATTENTION=1
```

현재 R 함수는 CPU 강제 옵션을 보내지 않습니다. Ollama의 NVIDIA 자동 인식을 사용하며, 실행 후 `ollama ps`의 PROCESSOR 열과 `nvidia-smi`로 실제 오프로딩을 확인합니다. 새 환경변수는 새 프로세스에서 적용되므로 기존 트레이 프로세스가 남아 있으면 완전히 종료한 뒤 다시 실행합니다.

8GB GPU에서는 여러 서버의 큰 모델을 동시에 GPU에 올리면 메모리가 부족해질 수 있습니다. 사용 중인 서버의 모델을 중심으로 로딩합니다.

## 확인 자료

- [LM Studio GPU 오프로딩](https://lmstudio.ai/docs/cli/local-models/load)
- [Lemonade 서버 설정](https://lemonade-server.ai/docs/guide/configuration/)
- [Ollama GPU 지원](https://docs.ollama.com/gpu)

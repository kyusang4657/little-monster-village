# itch.io 1차 공개 안내

목표는 '출시를 한 번 경험해 보는 것'입니다. itch.io는 심사 없이 바로 올릴 수 있어서 첫 공개에 알맞습니다.

## 올릴 파일

| 파일 | 만드는 방법 | itch.io 설정 |
| --- | --- | --- |
| `monster-village-0.2.0-web.zip` | `godot --headless --path . --export-release "Web" build/web/index.html` 후 `build/web` 안의 파일을 **폴더 없이** 압축 | Kind of project: **HTML**, 업로드 후 *This file will be played in the browser* 체크 |
| `monster-village-0.2.0-debug.apk` | `godot --headless --path . --export-debug "Android" ...` (README 5장) | 다운로드 파일, 플랫폼 **Android** 표시 |

웹 빌드는 스레드를 쓰지 않는 템플릿(`variant/thread_support=false`)이라 itch.io의 *SharedArrayBuffer support* 옵션을 켤 필요가 없습니다.

## 프로젝트 페이지 설정(권장값)

- Title: 마물의 작은 마을 (영문 부제가 필요하면 *Little Monster Village*)
- Classification: Games · Release status: **In development**(첫 공개라면) 또는 Released
- Pricing: **No payments**(무료). 이 게임에는 광고·결제가 없습니다.
- Embed options: Viewport **1280 × 720**, *Mobile friendly* 체크(Orientation: Landscape), *Fullscreen button* 체크
- Genre: Strategy / Simulation, Tags: tower-defense, city-builder, cute, low-poly, korean
- Cover image: `docs/store/feature-1024x500.png`를 630×500으로 자르거나 그대로 사용, Screenshots: `docs/store/screenshots/*.jpg`
- 설명: `docs/store/STORE-LISTING.md`의 긴 설명
- 언어: Korean

## 확인한 것과 확인이 필요한 것

- 확인함(이 저장소의 빌드 환경): 웹 빌드를 로컬 서버에 올려 Chromium(헤드리스, WebGL2·SwiftShader)에서 실행. 마을 표시, 한국어 글자, 버튼 클릭(건설 메뉴 열림)까지 확인.
- 확인이 필요함: 실제 itch.io에 올린 상태의 로딩 시간(엔진 wasm 약 44MB, itch.io가 압축해서 전송), 휴대전화 브라우저의 터치·성능, 브라우저별 소리. 브라우저 정책 때문에 소리는 첫 터치(클릭) 이후에 나옵니다.
- 웹에서 저장 데이터는 브라우저 저장소(IndexedDB)에 들어갑니다. 브라우저 기록을 지우면 함께 지워집니다.

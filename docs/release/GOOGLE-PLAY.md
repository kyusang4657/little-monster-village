# Google Play 출시 준비 안내

itch.io 공개 다음에 원하면 **비공개 테스트 → 정식 출시** 순서로 진행합니다. 이 문서는 개발자 PC에서 직접 할 일을 정리합니다. 출시용 키와 계정 정보는 저장소에 넣지 않습니다.

> 확인일: 2026-10-03. Google 정책은 자주 바뀌므로 Play Console 화면의 안내를 최종 기준으로 삼으세요. 아래에서 **[확인함]**은 이번 작업에서 공식 페이지나 실제 빌드로 확인한 내용이고, **[확인 필요]**는 접속이 막혀 공식 문서를 직접 확인하지 못한 내용입니다.

## 1. 지금 APK를 바로 올릴 수 없는 이유와 준비된 것

- **[확인함]** Google Play 대상 API 요건(developer.android.com, 2026-10-03 확인): 2026년 8월 31일부터 **새 앱과 앱 업데이트는 Android 16(API 36) 이상**을 대상으로 해야 합니다. 연장 신청 시 2026년 11월 1일까지 가능합니다.
- **[확인함]** `release/` 의 디버그 APK는 Godot 4.4.1 기본 템플릿으로 만들어 `targetSdkVersion 34` 입니다(매니페스트 직접 확인, 2026-10-05). Godot 은 Gradle 빌드를 켜지 않으면 대상 SDK 를 바꿀 수 없습니다(내보내기 설정 오류: "Target SDK" can only be overridden when "Use Gradle Build" is enabled).
- Play 는 **AAB(Android App Bundle)** 형식을 받습니다. APK 는 itch.io 와 직접 설치용입니다.

### 준비된 것(2026-10-05, API 36 대응)

| 항목 | 내용 |
| --- | --- |
| 내보내기 프리셋 `Android AAB` | `export_presets.cfg` 에 추가. Gradle 빌드 켬, 형식 AAB, **대상 SDK 36**, 최소 SDK 는 기본(21), 패키지 ID·버전·아키텍처는 `Android` 프리셋과 같음. 기존 `Android`(APK, Gradle 없음) 프리셋은 그대로라 이 저장소의 APK 빌드는 바뀌지 않습니다 |
| 템플릿 설치 스크립트 | `tools/install_android_template.sh` — 편집기 메뉴 *Project → Install Android Build Template* 와 같은 일을 터미널에서 합니다(`android/build` 에 풀고 `android/.build_version` 기록, 둘 다 git 무시) |
| 빌드 명령 | 아래 4절 |
| **[확인함]** 이 저장소를 만든 클라우드 환경에서 | 템플릿 설치, 프리셋 인식, Gradle 8.2 래퍼 내려받기·실행(JDK 21 에서 시작됨)까지 동작. **Gradle 빌드는 Android Gradle Plugin 8.2.0 을 내려받는 단계에서 실패** — 그 환경의 네트워크 정책이 Google 호스트(`dl.google.com`, `maven.google.com`)를 막기 때문이며, 설정 문제가 아닙니다. 개발자 PC(인터넷 제한 없음)에서는 이 단계를 지나갑니다 |
| **[확인 필요]** | Godot 4.4.1 템플릿(AGP 8.2.0, compileSdk 34)으로 대상 SDK 36 AAB 를 끝까지 만들고 Play 가 받는지는 실제 빌드로 확인해야 합니다. Godot 도 "36 is higher than the default version 34. This may work, but wasn't tested" 경고를 냅니다. 안 되면 최신 Godot 4.x 안정판으로 올리는 것을 권합니다(이 프로젝트는 GDScript 와 Compatibility 렌더러만 써서 옮기기 쉬운 편) |

## 2. 로컬 환경(개발자 PC)

| 도구 | 내용 |
| --- | --- |
| JDK | **OpenJDK 17** (Godot 4.x Android 내보내기 안내 기준) **[확인 필요: Godot 문서 직접 확인 못 함]** |
| Android Studio 또는 command-line tools | SDK Manager로 `platform-tools`, `build-tools`(최신), `platforms;android-36`, `cmdline-tools;latest` 설치 |
| Godot | 사용할 Godot 버전과 **같은 버전의 내보내기 템플릿**. 편집기 메뉴 *Project → Install Android Build Template* 실행 |
| Godot 편집기 설정 | *Editor Settings → Export → Android*: Java SDK Path, Android SDK Path 지정 |

## 3. 출시용 서명 키 만들기와 보관

```bash
keytool -genkeypair -v -keystore monster-village-release.keystore \
  -alias monstervillage -keyalg RSA -keysize 4096 -validity 10000
```

- 비밀번호는 비밀번호 관리자에 저장합니다. **키 파일과 비밀번호를 저장소·채팅·메일에 올리지 마세요.** (`.gitignore`에 `*.keystore`가 있지만 `android/debug.keystore`만 예외로 커밋되어 있습니다. 이것은 공개된 디버그 키입니다.)
- 키 파일은 클라우드 개인 저장소와 외장 저장장치 두 곳 이상에 백업합니다.
- **Play App Signing**을 쓰면 Google이 앱 서명 키를 보관하고, 위에서 만든 키는 *업로드 키*가 됩니다. 업로드 키를 잃어도 Play Console에서 재설정을 요청할 수 있습니다.
- Godot 내보내기 프리셋(Android)의 *Keystore → Release*, *Release User*, *Release Password*에 넣거나, 환경 변수 `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `GODOT_ANDROID_KEYSTORE_RELEASE_USER`, `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD`로 넘깁니다. 이렇게 하면 `export_presets.cfg`에 비밀번호가 남지 않습니다.

## 4. AAB 만들기(Gradle 빌드)

1. 템플릿 설치(한 번): `tools/install_android_template.sh` (또는 편집기 메뉴 *Project → Install Android Build Template*). Godot 과 같은 버전의 내보내기 템플릿이 설치되어 있어야 합니다.
2. Android SDK 에 `platforms;android-34`(템플릿의 compileSdk), `build-tools;36.0.0`(없으면 "Could not find version of build tools that matches Target SDK, using 34.0.0" 안내만 나오고 34.0.0 을 씁니다), `platform-tools` 를 설치합니다. JDK 는 17 을 권합니다(템플릿의 javaVersion 이 17; Gradle 8.2 는 JDK 21 에서도 시작은 되지만 공식 지원 범위 밖).
3. 출시 키를 환경 변수로 넘깁니다(3절). 프리셋 파일에 비밀번호를 적지 않습니다.
   ```bash
   export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=/안전한/경로/monster-village-release.keystore
   export GODOT_ANDROID_KEYSTORE_RELEASE_USER=monstervillage
   export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD='...'
   ```
4. 빌드:
   ```bash
   godot --headless --path . --export-release "Android AAB" build/android/monster-village-release.aab
   ```
   올릴 때마다 `Android AAB` 와 `Android` 프리셋의 `version/code` 를 함께 1씩 올립니다(현재 7, `version/name="0.6.1"`). 패키지 ID `io.github.kyusang4657.monstervillage` 는 **바꾸지 않습니다**(바꾸면 다른 앱이 됨).
5. 결과 AAB 의 매니페스트에서 `targetSdkVersion 36` 을 확인한 뒤 Play Console 테스트 트랙에 올립니다. 확인은 `bundletool dump manifest --bundle build/android/monster-village-release.aab | grep targetSdk` 로 할 수 있습니다.

## 5. 비공개 테스트 요건

- **[확인 필요]** 2023년 11월 이후 만든 **개인 개발자 계정**은 정식 출시 전에 *비공개 테스트*에서 일정 수 이상의 테스터가 연속 14일 이상 참여해야 합니다. 이번 작업에서는 support.google.com 접속이 막혀 직접 확인하지 못했습니다. 작업자가 알고 있는 최근 기준은 **테스터 12명 이상, 14일 연속**입니다. Play Console의 *대시보드 → 프로덕션 액세스 신청* 화면에서 정확한 수치를 확인하세요.
- 테스터 모집: 지인·커뮤니티의 Google 계정 이메일 목록 또는 Google 그룹. 테스터는 참여 링크로 옵트인한 뒤 앱을 설치해야 합니다.
- 테스트 기간 중 받을 피드백: `docs/TEST-REPORT.md`의 P04~P06 항목(설치, 터치, 10분 플레이, 프레임)과 3단계까지의 이해도.

## 6. 콘텐츠 등급(IARC 설문) 작성 참고

| 설문 주제 | 이 게임의 사실 |
| --- | --- |
| 폭력 | 귀여운 만화풍 판타지 폭력. 방어탑이 화살로 인간 기사를 공격하면 기사가 쓰러져 사라짐. 피·신체 훼손·사실적 인간 묘사 없음. 플레이어가 직접 사람을 공격하는 조작은 없음(자동 방어). |
| 공포·성적 내용·욕설 | 없음 |
| 약물·술·담배 | 없음 |
| 도박·모의 도박 | 없음(뽑기·확률형 아이템 없음) |
| 사용자 간 상호작용·채팅·위치 공유 | 없음(오프라인 싱글플레이) |
| 구매 | 없음(앱 내 구매·광고 없음) |

예상 등급은 설문 결과로 정해지므로 여기서는 단정하지 않습니다.

## 7. 데이터 보안(Data safety) 양식에 적을 내용

- 데이터 수집: **수집하지 않음**. 개인정보·기기 식별자·위치·연락처·사진·사용 기록을 서버로 보내지 않습니다.
- 데이터 공유: **없음**
- 인터넷 사용: 앱에 인터넷 권한이 없습니다(**[확인함]** aapt 결과 추가 `uses-permission` 없음).
- 기기 안 저장: 진행 상황(`save.json`, 백업)과 설정(`settings.cfg`)은 앱 전용 저장소에만 있고, 앱을 지우면 함께 삭제됩니다.
- 암호화 전송, 삭제 요청 창구: 수집 데이터가 없으므로 해당 없음. 삭제는 앱 삭제 또는 *설정 → 앱 → 저장공간 → 데이터 삭제*.
- 광고 ID 사용: 아니요.
- 대상 연령: 13세 미만 아동을 주 대상으로 정하면 *가족 정책*이 추가로 적용됩니다. 처음에는 "13세 이상"으로 두는 편이 단순합니다.

## 8. 스토어 등록 정보에 쓸 자료

- 앱 아이콘 512×512: `docs/store/icon-512.png`
- 대표 그래픽 1024×500: `docs/store/feature-1024x500.png`
- 휴대전화 스크린샷(16:9, 1920×1080): `docs/store/screenshots/` 6장(실제 게임 실행 화면)
- 설명 초안: `docs/store/STORE-LISTING.md`
- 개인정보처리방침 URL: `docs/release/PRIVACY-POLICY.md`를 GitHub Pages, itch.io 페이지 등 **공개 웹 주소**에 올려 그 주소를 입력

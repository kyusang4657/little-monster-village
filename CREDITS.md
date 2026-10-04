# CREDITS · 출처와 라이선스

이 게임에 들어간 외부 자료와 직접 만든 자료의 출처를 모두 적었습니다.

## 게임 안에 들어간 자료

| 자료 | 위치 | 만든 사람 / 출처 | 라이선스 |
| --- | --- | --- | --- |
| 주아체(Jua) | `assets/fonts/Jua-Regular.ttf` | 우아한형제들 · [Google Fonts 저장소](https://github.com/google/fonts/tree/main/ofl/jua) | SIL Open Font License 1.1 (`assets/fonts/OFL-Jua.txt`) |
| 검은고딕(Black Han Sans) | `assets/fonts/BlackHanSans-Regular.ttf` | Zess Type · [Google Fonts 저장소](https://github.com/google/fonts/tree/main/ofl/blackhansans) | SIL Open Font License 1.1 (`assets/fonts/OFL-BlackHanSans.txt`) |
| 3D 모델 전부(성 Lv.1~4·주택·벌목소·방어탑·앞마당·꽃밭·버섯 등불·울타리·나무·비계) | `scripts/world/models.gd` | 이 프로젝트에서 기본 도형을 코드로 조합해 직접 제작 | 프로젝트 소스와 같음 |
| 캐릭터(고블린·기사 변형 5종·용사·기사단장)와 동작 | `scripts/world/character_rig.gd` | 이 프로젝트에서 코드로 메시·뼈대·자세를 직접 제작(3차) | 프로젝트 소스와 같음 |
| 이야기 대사 | `config/story.json` | 이 프로젝트에서 직접 작성(개발 중 쓰기·검토·고쳐 쓰기, 앱 안 생성 없음) | 프로젝트 소스와 같음 |
| 효과음 12종, 배경음 2곡 | `assets/audio/` | 이 프로젝트에서 `tools/make_sounds.py`로 직접 합성(사인·삼각·사각파, 잡음, 현 모델). 외부 음원 사용 없음 | **CC0 1.0**(퍼블릭 도메인 기증) |
| UI 아이콘 | `scripts/ui/ui_icon.gd` | 코드로 직접 그림 | 프로젝트 소스와 같음 |
| 게임 엔진 | — | [Godot Engine](https://godotengine.org) 4.4.1 | MIT (엔진 라이선스 고지는 Godot 저작권 표기에 따름) |

## 게임에 쓰지 않는 참고 자료

- `docs/handoff-v1/references/`의 이미지 10장은 생성형 AI로 만든 **외형 참고 시트**입니다. 게임 실행 파일에는 포함되지 않습니다(`docs/.gdignore`로 가져오기와 내보내기에서 제외). 스토어 이미지에도 쓰지 않고, 스토어 스크린샷은 실제 게임 실행 화면만 씁니다.

## 외부 무료 에셋(Kenney, Quaternius 등)을 쓰지 않은 이유

2차 개발 환경에서 kenney.nl, quaternius.com, opengameart.org, freesound.org 접속이 막혀 있었습니다. 라이선스를 확인할 수 없는 사본을 쓰지 않기 위해 모델과 소리를 모두 직접 만들었습니다. 나중에 외부 CC0 에셋으로 바꾸면 이 표에 이름·주소·라이선스를 추가해 주세요. 모델을 바꿀 때는 `Models.build()`의 기준점(점유 영역 지면 중앙), 정면(-Z), 노드 이름(Body, Turret/Crossbow/Operator)을 유지하면 게임 기능이 그대로 동작합니다. 캐릭터는 3차부터 Skeleton3D 뼈대이며 관절 이름(Head, ArmL/R, ForearmL/R, HandL/R, LegL/R, ShinL/R, FootL/R)은 `CharacterRig.joint()`로 찾습니다. 바꿀 때는 이 이름과 기준점(두 발 사이 지면), 정면(-Z), 오른손 +X(검·망치), 왼손 방패를 유지하세요.

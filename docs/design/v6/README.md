# 6차 교체 후보 — 전체 출연진 (v6, 기본값은 여전히 v5)

악마형 마왕 Lv.1 후보(`docs/design/demon-lv1/`)와 같은 방법으로 나머지 캐릭터를 다시 만든 **교체 후보**입니다.
게임 기본값은 바뀌지 않았습니다(`CharacterRig.model_set = "v5"`). 후보는 `--model-set=v6` 인자로만 선택됩니다.

| 가족 | 파일 | 변형 | 삼각형(v6) | 삼각형(v5) |
|---|---|---|---|---|
| 고블린 | `scripts/world/chars/goblin_v6_builder.gd` | 일반·망치·투구(+망치 없음) | 3,800 / 3,949 / 3,923 (없음 3,549) | 3,534 / 3,758 / 3,572 |
| 기사 | `scripts/world/chars/knight_v6_builder.gd` | 일반·중갑·창·망치·성기사 | 3,870 / 3,814 / 3,530 / 3,648 / 3,904 | 3,762 / 3,856 / 3,572 / 3,602 / 3,846 |
| 보스 | `scripts/world/chars/boss_v6_builder.gd` | 용사 루루·기사단장 | 5,924 / 5,402 | 5,865 / 5,714 |
| 오크·해골 | `scripts/world/chars/orc_v6_builder.gd`, `skeleton_v6_builder.gd` | 꼬마 오크·해골 궁수 | 3,928 / 3,900 | 3,907 / 3,582 |
| 뿔이 Lv.1~4 | `scripts/world/chars/demon_builder.gd` | 악마형 마왕(성장: Lv.2 견갑·장화 테, Lv.3 왕관·홀, Lv.4 큰 왕관·긴 망토·금 꼬리) | 4,862 / 4,898 / 5,471 / 5,747 | 5,189 / 5,xxx / 5,xxx / 5,xxx (docs/design/v6/imp/) |

예산(config): 캐릭터 4,000 / 보스·뿔이 6,000. 그리기 호출은 모두 1, 키(HEIGHT)·무기 끝·방패·보조 뼈(망토·깃·귀) 계약은 v5 와 같습니다.

## 방법(공통)
- 머리는 `DemonGeo.sculpt()` 한 면(볼·눈두덩·턱·눈구멍 패임), 눈알은 눈구멍 안에 평평하게, 눈 뼈 위 어두운 뚜껑 + 가는 눈썹.
- 몸통·옷은 `lathe()` 회전체(목가리개·흉갑·사슬·치마·조끼·로브), 팔다리는 몸통 안에서 시작하는 `limb()` 연속 관, 관절 구 없음, 숨은 고리는 외곽선 0.
- 정점 명암 굽기 없음(`bake = 0`), 공유 재질 `CharacterRig.character_material()` 그대로.
- 두 차례 심사(컨셉 크롭 대조) → 보완 1회. 심사 기록은 아래 "남은 차이" 에 요약.

## 캡처
- `docs/design/v6/<가족>/review.jpg`: 변형별 정면·¾·옆·공격·게임 크기·보통 얼굴·화난 얼굴.
- `docs/design/v6/<가족>/before-after.jpg`: v5(왼쪽 3칸) / v6(오른쪽 3칸).
- `docs/design/v6/compare/cast-v5-v6.jpg`: 전체 출연진 한 줄(위 v5, 아래 v6).
- `docs/design/v6/compare/game-*.jpg`: 실제 게임 화면(왼쪽 v5, 오른쪽 v6) — 일꾼, 병영, 스토리(기사단장·용사·뿔이).

## 검사
```
tests/character_checks.gd              → RESULT: 520 passed, 0 failed (model set v5)
tests/character_checks.gd --model-set=v6 → RESULT: 520 passed, 0 failed (model set v6)
tests/run_tests.gd                      → RESULT: 605 checks passed, 0 failed
```

## 실행
```
godot --path . -- --model-set=v6                      # 게임을 v6 후보로
tests/character_capture.gd -- --mode=cast --model-set=v6
tests/character_checks.gd -- --model-set=v6
```
코드에서 바꾸려면 `CharacterRig.model_set = "v6"` 를 리그 생성 전에 설정합니다. 기본값을 v6 로 돌리는 것(본 씬 적용)은 승인 후 `character_rig.gd` 의 한 줄만 바꾸면 됩니다.

## 남은 차이(심사 기록)
- 고블린: 입이 v5 의 넓은 이빨 웃음보다 얇게 읽힘(송곳니는 작음). 머리 비율은 컨셉 3등신보다 큰 2.3등신(v5 와 같음).
- 기사: 면갑 눈이 작은 금빛 타원(컨셉의 빛나는 두 눈에 가깝지만 작음); 일반 기사 얼굴이 v5 의 미소보다 무표정. 성기사 망토가 정면에서 다리 옆까지 보임(뒤에서 방패를 가리려 넓힘). 투구 챙(앞으로 기운 테)은 없음.
- 보스: 기사단장 면갑 눈이 아직 작은 금빛 덩어리로 읽힘; 깃을 낮춰 옆모습이 얌전해짐. 루루는 심사 7/10 → 보완 후 재심사 없음.
- 오크·해골: 오크 피부를 올리브로 바꿔 v5 보다 어두움(컨셉 일치, 게임 화면 대비는 약간 줄어듦). 해골 눈빛은 지시(25%)보다 큰 40%.
- 뿔이 Lv.2~4 는 v5(마룡) 그대로 — v6 로 실행하면 Lv.1 만 악마형이 되어 성장 단계 간 디자인이 끊깁니다. 적용 전에 Lv.2~4 후보가 필요합니다.

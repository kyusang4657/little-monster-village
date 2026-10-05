# 6차 모델 — 전체 출연진 (v6, 게임 기본값)

악마형 마왕 Lv.1 후보(`docs/design/demon-lv1/`)와 같은 방법으로 나머지 캐릭터를 다시 만들고, 뿔이를 Lv.1~4 악마형 마왕으로 완성한 뒤 **게임 기본값을 v6 로 바꿨습니다**(`CharacterRig.model_set = "v6"`).
이전 5차 모델은 `--model-set=v5` 인자로 비교·복원할 수 있습니다.

| 가족 | 파일 | 변형 | 삼각형(v6) | 삼각형(v5) |
|---|---|---|---|---|
| 고블린 | `scripts/world/chars/goblin_v6_builder.gd` | 일반·망치·투구(+망치 없음) | 3,838 / 3,987 / 3,961 (없음 3,587) | 3,534 / 3,758 / 3,572 |
| 기사 | `scripts/world/chars/knight_v6_builder.gd` | 일반·중갑·창·망치·성기사 | 3,870 / 3,866 / 3,582 / 3,700 / 3,956 | 3,762 / 3,856 / 3,572 / 3,602 / 3,846 |
| 보스 | `scripts/world/chars/boss_v6_builder.gd` | 용사 루루·기사단장 | 5,924 / 5,396 | 5,865 / 5,714 |
| 오크·해골 | `scripts/world/chars/orc_v6_builder.gd`, `skeleton_v6_builder.gd` | 꼬마 오크·해골 궁수 | 3,928 / 3,900 | 3,907 / 3,582 |
| 뿔이 Lv.1~4 | `scripts/world/chars/demon_builder.gd` | 악마형 마왕(성장: Lv.2 견갑·장화 테, Lv.3 왕관·홀, Lv.4 큰 왕관·긴 망토·금 꼬리) | 4,862 / 4,898 / 5,471 / 5,747 | 5,189 (마룡, Lv.2~4 는 docs/design/v5) |

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
5차로 되돌리려면 `character_rig.gd` 의 `static var model_set := "v6"` 를 `"v5"` 로 바꾸거나 `--model-set=v5` 로 실행합니다.

## 남은 차이(심사 기록)
- 고블린: (보완됨) 넓은 웃음·입속·윗니 줄·입꼬리 큰 아랫송곳니로 바꿈. "기쁨" 표정은 리그가 화난 입과 같은 뼈를 쓰므로 이를 드러낸 웃음으로 보임. 머리 비율은 컨셉 3등신보다 큰 2.3등신(v5 와 같음).
- 기사: (보완됨) 면갑 눈을 어두운 틈 속 크게 빛나는 가로 타원 둘로 바꿈(틈 높이 약 30%). 일반 기사 얼굴이 v5 의 미소보다 무표정. 성기사 망토가 정면에서 다리 옆까지 보임(뒤에서 방패를 가리려 넓힘). 투구 챙(앞으로 기운 테)은 없음.
- 보스: (보완됨) 기사단장 면갑도 같은 빛나는 눈으로 바꾸고 허리 보석을 평판으로. 깃을 낮춰 옆모습이 얌전해짐. 루루는 심사 7/10 → 보완 후 재심사 없음.
- 오크·해골: 오크 피부를 올리브로 바꿔 v5 보다 어두움(컨셉 일치, 게임 화면 대비는 약간 줄어듦). 해골 눈빛은 지시(25%)보다 큰 40%.
- 뿔이 Lv.2~4(악마형 성장): 왕관 띠가 뿔 뿌리를 지나감(컨셉과 같고 뿔에 가려짐), 어깨 해골은 게임 줌에서 작음, Lv.1 과 Lv.2 는 삼각형 차이가 작음(견갑이 덮개를 대체). 무서운 척 자세에서 Lv.4 망토 모서리가 -0.05 까지 내려감(검사 한계와 같음).

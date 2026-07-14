MERGE BATTLE - RUN PROGRESSION MVP
Godot 4.7 / GDScript

Audio system
- F9: merge SFX test; F10: Ultimate sequence test; F11: master mute toggle.
- SOUND toggles master mute; settings persist in user://audio_settings.cfg.
- Missing SFX use cached procedural prototypes; missing BGM is skipped safely.
- Replacement names/formats are documented under assets/audio/.

==================================================
실행 / 조작
==================================================

1. Godot Project Manager에서 project.godot을 Import합니다.
2. F6 또는 F5로 실행합니다.

PC
- 이동: 방향키 / WASD / mouse drag
- Ultimate: U 또는 ULTIMATE button
- 현재 성장 확인: BUILD button
- 새 run: R 또는 RESTART button

Mobile
- 이동: 상하좌우 swipe
- Ultimate / BUILD / RESTART button

Debug build
- F1: enemy HP를 1로 설정
- F2: 빈 cell에 64 tile 생성
- F3: Soul 5개 추가
- F4: upgrade 선택 화면 강제 표시
- F8: meta save 초기화

==================================================
핵심 rule
==================================================

- 4×4 board에서 2048 방식으로 이동하고 merge합니다.
- 정상 이동에만 turn이 증가하고 새 2/4 tile이 생성됩니다.
- merge 값의 합과 combo bonus에 run attack 배율과 permanent 배율을 적용합니다.
- 최종 damage는 roundi로 반올림합니다.
- Ultimate는 가장 큰 64+ tile을 소비하며 turn을 소비하지 않습니다.
- enemy 공격 간격은 기본 3 move이며 Fortify로 최대 5 move까지 증가합니다.
- enemy를 처치하면 Soul 1개를 획득하고 upgrade 3개 중 하나를 선택합니다.
- upgrade를 선택해야 다음 stage가 시작됩니다.
- stage 전환 시 board, HP, run upgrade는 유지되고 enemy와 attack turn만 갱신됩니다.

==================================================
Run upgrade
==================================================

- Power Up: 모든 merge damage +20%
- Combo Master: combo bonus +25%
- Vitality: max HP +20, 현재 HP +20
- Recovery: stage clear 회복량 +5
- Ultimate Power: Ultimate 배율 +0.5x
- Fortify: enemy 공격을 1 move 늦춤, 최대 2 level

동일 선택 화면에 같은 upgrade는 중복되지 않습니다. Max level upgrade는 후보에서 제외됩니다.

==================================================
Meta progression
==================================================

- stage clear마다 Soul 1개를 즉시 user://merge_battle_progress.cfg에 저장합니다.
- Soul 5개마다 permanent attack level이 1 증가합니다.
- level당 새 run의 damage +5%, 최대 +50%입니다.
- Souls, best stage, total runs가 game over 뒤에도 유지됩니다.
- save가 없거나 읽을 수 없으면 default 값으로 시작합니다.

==================================================
Animation / input flow
==================================================

- tile 이동: 0.10초
- merge pop: 0.08초
- spawn: 0.08초
- actor attack: 약 0.11초
- hit flash / shake: 약 0.10초
- damage text: 약 0.34초

board input은 tile 이동, merge 적용, spawn이 끝날 때까지만 잠깁니다.
player/enemy attack, hit, damage text는 board 확정 뒤 독립적으로 재생됩니다.
연속 effect는 이전 damage text를 기다리지 않으며 actor/panel Tween은 이전 상태를 안전하게 정리합니다.

==================================================
Project 구조
==================================================

res://
├─ project.godot
├─ scenes/main.tscn
└─ scripts/
   ├─ main.gd                 game flow와 UI 연결
   ├─ board_logic.gd          2048 move/merge/spawn과 tile event
   ├─ run_state.gd            현재 run 성장과 damage 계산
   ├─ upgrade_system.gd       upgrade 정의/후보/변경값 표시
   ├─ save_manager.gd         Soul/best stage/run/meta save
   ├─ battle_actor_view.gd    idle/attack/hit/death/spawn/ultimate
   └─ actor_figure.gd         기본 도형 player/5종 monster silhouette

==================================================
PC 수동 test 순서
==================================================

1. 방향키, WASD, mouse drag로 이동하고 mobile 환경에서는 swipe를 확인합니다.
2. 이동 tile이 cell 사이를 0.10초 정도로 이동하고 merge pop과 spawn이 이어지는지 확인합니다.
3. spawn 직후 다음 입력이 가능하며 damage text가 남아 있어도 board가 움직이는지 확인합니다.
4. 빠르게 여러 번 입력해도 중복 turn이나 잘못된 tile이 생기지 않는지 확인합니다.
5. 작은 merge, 32 merge, 64+ merge, 동시 merge에서 attack 크기와 text가 달라지는지 확인합니다.
6. 정상 이동 3회마다 enemy가 짧게 공격하고 player HP가 감소하는지 확인합니다.
7. F1 후 merge하여 stage clear upgrade card가 정확히 3개 표시되는지 확인합니다.
8. card를 선택하기 전 board 입력이 막히고, 선택 후 기존 board로 다음 stage가 시작되는지 확인합니다.
9. Power/Combo/Vitality/Recovery/Ultimate/Fortify가 BUILD 표시와 실제 rule에 반영되는지 확인합니다.
10. F2 후 U를 눌러 tile 소비, 0.6초 이하 Ultimate 연출, damage와 input 복귀를 확인합니다.
11. stage별 Slime/Goblin/Golem/Mage/Dragon의 색상과 형태가 바뀌는지 확인합니다.
12. stage clear 후 Soul과 Best Stage가 즉시 증가하는지 확인합니다.
13. game over 후 PLAY AGAIN으로 새 run을 시작해 board와 run upgrade는 초기화되고 Soul은 유지되는지 확인합니다.
14. Soul 5개 이상에서 새 run의 Permanent Power와 실제 damage가 +5% 단위로 증가하는지 확인합니다.
15. user save file을 임시로 손상시킨 뒤 실행해 crash 없이 default 상태로 시작하는지 확인합니다.
16. Debug build에서 F1/F2/F3/F4/F8을 각각 확인합니다.

MERGE BATTLE - PHASE 2 RUN BUILD
Godot 4.7 / GDScript / 720x1280 portrait

조작
- 이동: 방향키 / WASD / mouse drag / mobile swipe
- ULTIMATE: U 또는 button (gauge 100% 필요, tile 비소비)
- BREAK: 가장 큰 64+ tile 제거, 제거 값 25% shield
- BUILD: 현재 run stat 및 upgrade 확인
- RESTART: 즉시 새 run. board, HP, gauge, shield, upgrade 초기화

Run 규칙
- stage clear 후 board, HP, gauge, shield, Break charge, upgrade가 유지됩니다.
- enemy만 stage별 HP/damage/attack countdown으로 교체됩니다.
- 영구 성장, Soul, meta save는 Phase 2에서 사용하지 않습니다.
- upgrade 선택 전에는 battle input이 잠기며 선택 후 다음 stage가 시작됩니다.

Ultimate
- merge charge: 4=4, 8=6, 16=10, 32=16, 64=25, 128+=35.
- 한 move의 merge 수에 따라 12%씩 combo charge가 붙고 Fast/Arcane Core가 배율을 적용합니다.
- damage = max(largest tile, recent merge damage) x 2 x additive bonuses.
- 사용 시 gauge만 0이 되며 tile/turn/spawn에는 영향을 주지 않습니다.

Large Tile Core
- 64/128/256/512/1024 이상에서 Attack +10/+20/+30/+40/+50%.
- 가장 높은 한 단계만 적용하며 Giant Strength가 level당 +4% 강화합니다.

Upgrade pool (max level)
Attack: Power Up(5), Heavy Strike(4), Critical Edge(4), First Blood(3)
Combo: Combo Master(5), Chain Slash(3), Finisher(4), Rhythm Attack(3)
Survival: Vitality(5), Recovery(5), Tough Skin(4), Emergency Shield(3), Second Wind(1)
Ultimate: Fast Charge(5), Ultimate Power(5), Overflow(3), Aftershock(3)
Large Tile: Giant Strength(5), Stable Core(3), Arcane Core(3)
Utility: Break Charge(3), Small Start(3), Battle Focus(3), Stage Preparation(3)

Debug build
- F1 enemy HP=1
- F2 빈 cell에 64 tile
- F3 Ultimate gauge=100%
- F4 upgrade overlay 강제 표시
- F7 Break charge +1
- F8 현재 run upgrade 초기화
- F9/F10/F11 기존 audio test/mute 유지

수동 smoke test
1. 이동하지 않는 입력은 turn/spawn/charge를 만들지 않는지 확인합니다.
2. merge animation 뒤 input이 빠르게 풀리고 공격/damage text와 겹쳐 진행되는지 확인합니다.
3. F1 후 merge하여 서로 다른 card 3개와 rarity 색상, max-level 제외를 확인합니다.
4. 선택 후 board/HP가 유지되고 BUILD에 level/stat이 표시되는지 확인합니다.
5. F3 후 Ultimate가 tile을 보존하고 gauge만 0으로 만드는지 확인합니다.
6. F2 후 BREAK가 64 tile, charge를 제거하고 shield를 생성하는지 확인합니다.
7. enemy attack이 shield부터 소모하고 남은 damage만 HP에 적용하는지 확인합니다.
8. 64/128/256 tile에서 CORE 표시와 merge damage 변화를 확인합니다.
9. Restart와 game over/PLAY AGAIN에서 새 run 상태를 확인합니다.
10. 작은 창과 720x1280에서 card/build Scroll 및 action row overflow를 확인합니다.

Project 구조
- scripts/main.gd: battle flow, input, runtime UI/effects
- scripts/board_logic.gd: 2048 rule, spawn chance, tile query/removal API
- scripts/run_state.gd: run stats, upgrade effects, damage/charge/shield calculations
- scripts/upgrade_system.gd: 24 definitions, rarity/weight, candidate/max-level rules
- scripts/upgrade_card.gd: one-shot rarity card UI
- scripts/build_panel.gd: scrollable build display
- scripts/audio_manager.gd: non-blocking gameplay/UI SFX with procedural fallback

현재 balance
- Enemy HP: Stage 1은 62, Stage 2~9는 stage당 +34, 이후 stage당 +14
- Enemy damage: 기본 7, stage당 +2
- Stage clear 기본 회복: 10 HP

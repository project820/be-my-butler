# BMB Global Learnings

[2026-03-13 16:45] PRAISE (step 5): executor가 10파일 한번에 완료 (410초) → infra 레시피에서 단일 executor 전략이 효과적 [bmb]
[2026-03-13 16:45] MISTAKE (step 7): cross-model verifier timeout — pane 종료, 결과 없음 → cross_model_verify timeout을 900초로 줄여야 함 [bmb]
[2026-03-13 16:45] MISTAKE (step 11): bmb_learn 미호출, learnings.md 비어있음 → Step 11에서 bmb_learn은 반드시 bash로 source 후 호출 [bmb]
[2026-03-13 16:45] MISTAKE (step 11): analyst 보고서를 유저에게 전달하지 않음 → analyst report 핵심 발견을 유저에게 직접 요약 전달 필수 [bmb]
[2026-03-13 16:45] MISTAKE (step 10.5): promotion check 미실행 → learnings.md 스캔 및 승격 제안은 회고의 핵심 — 생략 금지 [bmb]
[2026-03-13 16:45] PRAISE (step 5): bugfix 3건 100초 완료 → 명확한 fix 지시가 있으면 executor가 빠르게 처리 [bmb]
[2026-03-13 16:45] PRAISE (step 7): verifier 70초 완료, 0 critical → bugfix 검증은 단일 Claude verifier로 충분 [bmb]
[2026-03-13 18:00] PRAISE (step 5): executor completed 3-part infra in 460s → 단일 executor로 atomic 3-part 변경이 효과적 [bmb]
[2026-03-13 18:00] MISTAKE (step 6): cross-model tester timeout 1200s → cross-model-run.sh 자체를 수정하는 세션에서는 cross-model 결과 기대 불가 [bmb]
[2026-03-13 18:00] MISTAKE (step 7): cross-model verifier timeout 1200s → cross-model 100% 실패율 — timeout 600s로 줄이거나 circuit-breaker 필요 [bmb]

실수/학습 사항을 3곳에 동시 기록합니다.

사용자가 $ARGUMENTS 로 전달한 내용을 분석하여:

1. **현재 프로젝트 CLAUDE.md** — `## Learnings` 섹션 하단에 번호 매긴 규칙 추가
   - 형식: `N. **요약** — 상세 설명 (YYYY-MM-DD)`
   - 기존 규칙과 중복되면 기존 항목을 업데이트
   - `## Learnings` 섹션이 없으면 CLAUDE.md 맨 아래에 생성
   - CLAUDE.md 자체가 없으면 이 단계는 건너뛰고 사용자에게 알림

2. **Claude auto-memory** — 현재 프로젝트의 auto-memory 디렉토리 내 `learnings.md`에 기록
   - 경로 탐색: `~/.claude/projects/` 아래에서 현재 작업 디렉토리에 해당하는 `memory/` 폴더를 찾음
   - 형식: `## YYYY-MM-DD: 요약` + 상세 내용
   - 날짜+컨텍스트 포함하여 추후 검색 가능하게
   - memory 디렉토리가 없으면 이 단계는 건너뛰고 사용자에게 알림

3. **Supermemory** — `/distill` 스킬 호출하여 클라우드에 영구 저장
   - 학습 내용을 Supermemory 규칙으로 변환하여 저장

3곳 모두 기록 완료 후 요약을 보여주세요.

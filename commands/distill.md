Supermemory에서 학습된 규칙을 관리한다.

## 사용법
- `/distill` — 기본 모드: 최근 규칙 목록 + Top 5 승격 후보 제안
- `/distill --compact` — CLAUDE.md Top 5 최적화
- `/distill --search [query]` — 특정 주제 규칙 검색

## 기본 모드 (/distill)
1. `~/tools/brain-search.sh "claude_md_rule" --limit 20` 으로 저장된 규칙 검색
2. 최근 규칙 목록을 사용자에게 표시
3. 반복 패턴 식별 → Top 5 승격 후보 제안
4. 사용자 승인 시 `~/.claude/CLAUDE.md`의 Top 5 섹션 업데이트

## --compact 모드 (/distill --compact)
1. 현재 `~/.claude/CLAUDE.md`의 "Top 5 보편 규칙" 섹션 읽기
2. 각 규칙의 현재 관련성 평가
3. 더 이상 관련 없는 규칙 → brain-save.sh로 Supermemory에 아카이브
4. 더 중요한 규칙으로 교체 제안
5. 사용자 승인 시 Top 5 갱신

## --search [query] 모드 (/distill --search [query])
1. `~/tools/brain-search.sh "[query]" --limit 10` 으로 검색
2. 현재 작업에 적용 가능한 규칙 표시
3. 규칙 적용 여부를 사용자에게 확인

## 규칙 저장 템플릿
brain-save.sh로 저장 시 아래 JSON 형식 사용:
```json
{
  "category": "build|code-style|architecture|config|testing|security",
  "trigger": "어떤 상황에서 적용되는지",
  "rule": "구체적으로 무엇을 해야 하는지",
  "severity": "high|medium|low",
  "reason": "왜 이 규칙이 필요한지 (실패 경험)",
  "created": "YYYY-MM-DD",
  "project": "프로젝트명 또는 global"
}
```

## 예시
```bash
# 기본: 최근 규칙 조회 + 승격 후보
/distill

# Top 5 최적화 (오래된 규칙 아카이브, 새 규칙 승격)
/distill --compact

# 특정 주제 검색
/distill --search "Next.js build errors"
/distill --search "MCP config"
```

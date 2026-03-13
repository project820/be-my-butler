---
name: alphaxiv-paper-lookup
description: Retrieve AI-generated summaries of arxiv papers from alphaxiv.org. Triggers on arxiv URLs, paper IDs (e.g. 2401.12345), or requests to explain/summarize research papers.
---

# AlphaXiv Paper Lookup

## Activation Triggers
- arxiv URLs or paper IDs (e.g., `2401.12345`)
- Requests to explain, summarize, or analyze research papers
- alphaxiv URLs

## Process

1. **Extract Paper ID** from user input (e.g., `https://arxiv.org/abs/2401.12345` → `2401.12345`)
2. **Fetch Machine-Readable Report** via WebFetch: `https://alphaxiv.org/overview/{PAPER_ID}.md`
3. **Fallback to Full Text** if needed: `https://alphaxiv.org/abs/{PAPER_ID}.md`

## Error Handling
- 404 → report/full text not yet generated
- Final fallback: direct user to raw PDF at `https://arxiv.org/pdf/{PAPER_ID}`

## Notes
- No authentication required (public endpoints)
- Use overview report for most inquiries; only fetch full text when specific details (equations, tables, sections) are needed

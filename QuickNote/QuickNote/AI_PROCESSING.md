# AI_PROCESSING.md — Processing Pipeline Reference

## Classification Flow

Input → Claude → JSON response → strip markdown → hydrate Note model

```
rawText ──► classify ──► ProcessedNoteResponse { type, tasks, tags, summary }
```

## Enhancement Flow

```
displayText ?? rawText ──► enhance(mode) ──► stripped plain text ──► displayText
```

rawText is **never modified** after creation. displayText is the only mutable field.

## System Prompts

### Classification
Return valid JSON with fields: type ("task"|"idea"|"note"|"link"), tasks (array), tags (array), summary (string).

### Enhancement modes — system role prompts
| Mode | Instruction |
|------|-------------|
| CLARITY | Rewrite in clear, concise prose. Same meaning, no additions, no bullets. Return only rewritten text. |
| EXPAND | Expand to 2-3 sentences + one stated direction. No speculation beyond what's implied. Return only the expanded note. |
| SHARPEN | Rewrite tasks as specific, actionable, time-aware lines. One per line, no bullet characters. Return only the sharpened tasks. |
| REFRAME | Translate anxious or vague note to calm observation or concrete next steps. Don't minimize emotion. Return only the reframed text. |

### Related notes (see also)
Semantic similarity — return JSON array of 2-3 UUID strings. Empty array if no strong match.

## Hard Rules

1. rawText is immutable after first write.
2. displayText is nil until AI or user edit sets it — UI falls back to rawText.
3. enhancementMode records last applied mode string; nil means no enhancement.
4. All API calls go through NoteProcessor — no direct URLSession calls elsewhere.
5. Strip markdown from every API output field before storing or returning.
6. Never use markdown formatting in any output field. No hashtags, no asterisks, no hyphens as bullets, no backticks, no numbered lists with periods. Plain text only in every field.
7. Fail silently on network errors — never block the UI or show modals for API failures.
8. Enhancement respects isPro gate — ProUpgradeSheet fires when isPro is false.

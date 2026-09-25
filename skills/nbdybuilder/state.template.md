# <project> orchestrator state

## Goal and definition of done
<copied from .cursor/nbdybuilder/project.md, plus owner additions>

## Lanes
| Lane | Agent ID | Domain / current item | Branch | Status | Trigger that resumes it |
|---|---|---|---|---|---|
| A | bc-… | notifications: NOT-001, UX-002 | cursor/train-notify-… | building | "#66 merged" → finalise |
| H | bc-… | steward | — | standing order: #71 → #72 | green CI events |

## Merge queue (ordered)
1. #<n> <branch> — <what>
2. <train> — PR opens when #<n> merges

## Numbering map (provisional)
| Sequence | Next free on base | Reserved by |
|---|---|---|
| migrations | 000205 | A 205, E 206–208, B 209+ |

## Triggers
- ON #<n> MERGE → resume <lanes> with "<message>"

## Owner actions (open)
1. <action> — <link> — blocks <items>

## Decisions (provisional unless marked owner)
- <n>. <decision> (<date>, provisional|owner)

## Log
- <date time> <what happened, SHAs, what was dispatched>

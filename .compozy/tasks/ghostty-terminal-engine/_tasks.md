# Ghostty Terminal Engine — Task List

## Tasks

| # | Title | Status | Complexity | Dependencies |
|---|-------|--------|------------|--------------|
| 01 | Add Swift Ghostty wrapper target | pending | high | — |
| 02 | Route GhosttyAdapter through the Swift wrapper runtime | pending | high | task_01 |
| 03 | Extract launch metadata translation from the SwiftTerm driver | pending | medium | — |
| 04 | Replace TerminalHostController SwiftTerm hosting with Ghostty native surface hosting | pending | critical | task_01, task_02, task_03 |
| 05 | Preserve workspace lifecycle, restore, and exit telemetry on the Ghostty path | pending | high | task_04 |
| 06 | Remove SwiftTerm and complete correctness baseline evidence | pending | high | task_04, task_05 |

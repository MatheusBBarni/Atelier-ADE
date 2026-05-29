# Native Mac ADE — Task List

## Tasks

| # | Title | Status | Complexity | Dependencies |
|---|-------|--------|------------|--------------|
| 01 | Scaffold native macOS app workspace | completed | high | — |
| 02 | Pin Ghostty and build the adapter boundary | pending | high | task_01 |
| 03 | Implement workspace domain models and SQLite metadata store | completed | high | task_01 |
| 04 | Implement workspace store and command services | completed | high | task_03 |
| 05 | Build project sidebar, session management UI, and default Nord shell theme | completed | high | task_01, task_04 |
| 06 | Build tab chrome and AppKit terminal host integration | completed | high | task_02, task_04, task_05 |
| 07 | Implement restore coordinator and relaunch recovery flow | completed | high | task_03, task_04, task_05, task_06 |
| 08 | Add lightweight session shortcuts and pilot observability polish | completed | medium | task_04, task_06, task_07 |

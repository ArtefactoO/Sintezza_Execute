# Offline checks

Run from the Sintezza_Execute repository with Python 3.12 and Lupa 2.8's Lua 5.1 runtime. The commands below use the workspace's existing interpreter and runtime package.

```powershell
& 'C:/Program Files/WindowsApps/OpenAI.CodexPrimaryRuntime.v26-1112-611-0_26.1112.611.0_x64__3k8sg7r9htsxt/dependencies/python/python.exe' Tests/run.py --runtime 'D:/Games/WoW_addons/.execute-verification/.loot-verification-20261117/python'
```

The suite compiles every production Lua file and checks overlay state, inclusive and exclusive thresholds, repeated draws, range clamping, secret-health fallbacks, cooldown state, and Blizzard/EllesmereUI visibility. An optional --baseline addon snapshot compares rendered state before and after a refactor. Mock frame state and call counts establish the exercised contracts. Physical rendering and native client behavior require separate in-game checks.

# AGENTS.md — ShotgunArena Prototype

Agentic coding guide for this **first-person-shooter (FPS) Roblox game**, written in
**Luau** and synced to Studio via **Argon**. All source code lives in `src/`; do not
edit scripts directly inside Studio unless Argon sync is active.

---

## 1. Project Layout

```
ShotgunArenaPrototype/
├── default.project.json          ← Argon manifest (maps src/ → Studio)
├── .gitignore                    ← ignores Packages/, *.rbxl, lock files
└── src/
    ├── Client/                   → StarterPlayer.StarterPlayerScripts (LocalScript)
    │   └── Main.client.luau      ← client entry point
    ├── Server/                   → ServerScriptService (Script)
    │   └── Main.server.luau      ← server entry point
    └── Shared/                   → ReplicatedStorage (ModuleScript)
        └── Hello.luau            ← example shared module
```

**File naming rules (Argon convention):**

| Extension | Studio type | Runs on |
|---|---|---|
| `.server.luau` | Script | Server only |
| `.client.luau` | LocalScript | Client only |
| `.luau` | ModuleScript | Required explicitly |

Subfolders inside `src/` become `Folder` instances in Studio automatically.

---

## 2. Toolchain & Commands

### Argon

```bash
# Start live sync — keep this running the whole dev session
argon serve

# Build a .rbxl snapshot (for sharing / backup)
argon build --output ShotgunArena.rbxl

# Verbose build
argon build --output ShotgunArena.rbxl --verbose
```

> `argon serve` is the primary workflow. Studio and `src/` stay in sync bidirectionally.

### Wally (package manager — add when needed)

```bash
# Install packages declared in wally.toml → Packages/
wally install
```

`Packages/` is gitignored — never commit it. Declare deps in `wally.toml` instead.

### Testing — no external CLI

Roblox has no test runner outside of Studio. Use **TestService** for module checks:

```lua
-- Place a Script under game.TestService, then press Play
local TestService = game:GetService("TestService")

local MyModule = require(game.ReplicatedStorage.MyModule)

TestService:Check(MyModule.Add(2, 3) == 5, "Add(2,3) should equal 5")
TestService:Check(MyModule.Add(0, 0) == 0, "Add(0,0) should equal 0")
```

To run **a single module test**: create one Script under TestService that requires only
that module, press Play, read results in the Output panel, then stop.

---

## 3. Luau Code Style

### Type annotations — mandatory

```lua
-- ✅ correct
local function shoot(origin: Vector3, direction: Vector3): RaycastResult?
    return workspace:Raycast(origin, direction * 500)
end

-- ❌ wrong — no annotations
local function shoot(origin, direction)
    return workspace:Raycast(origin, direction * 500)
end
```

Always annotate: function params, return types, table fields, module-level variables.

### Module structure

```lua
-- src/Shared/MyModule.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- 1. Roblox services
-- 2. Packages  (require(ReplicatedStorage.Packages.X))
-- 3. Internal   (require(ReplicatedStorage.SubFolder.X))

local MyModule = {}

-- Private state — plain camelCase, no underscore prefix
local activeCount: number = 0

-- Public function
function MyModule.DoSomething(value: number): boolean
    activeCount += value
    return activeCount > 0
end

-- Lifecycle hook called by the boot script
function MyModule.Start(): ()
    -- initialization here
end

return MyModule
```

### Naming conventions

| Kind | Style | Example |
|---|---|---|
| Module / Service / Controller | PascalCase | `CombatService`, `WeaponController` |
| Public function | camelCase | `fireWeapon`, `applyDamage` |
| Private variable | camelCase | `hitCount`, `lastFireTime` |
| Constant | SCREAMING_SNAKE | `MAX_AMMO`, `BULLET_SPEED` |
| Luau type alias | PascalCase | `type WeaponConfig = {...}` |
| Signal / event name | PascalCase noun | `OnHit`, `WeaponChanged` |
| File name | matches module name | `WeaponController.luau` |

### Imports — ordered, at top of file

```lua
-- 1. Roblox services (cached once at top level)
local Players        = game:GetService("Players")
local RunService     = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- 2. Packages (from Wally — Packages/ folder)
-- local Signal = require(ReplicatedStorage.Packages.Signal)

-- 3. Internal shared modules
-- local WeaponConfig = require(ReplicatedStorage.Shared.WeaponConfig)
```

Never call `game:GetService()` inside a loop or function body.

### Error handling

```lua
-- pcall for recoverable / IO operations
local ok, result = pcall(function()
    return DataStoreService:GetAsync("key")
end)
if not ok then
    warn("[DataService] GetAsync failed:", result)
    return defaultValue
end

-- xpcall in module Start() — prevents one bad module crashing the whole boot
local ok, err = xpcall(module.Start, function(e)
    warn("[Boot] Module failed to start:", e, debug.traceback())
end)

-- NEVER use bare error() in services — always warn() and return gracefully
```

### Async

Prefer **Promise** (when added via Wally) over nested callbacks:

```lua
DataService.Load(player)
    :andThen(function(data)
        applyData(player, data)
    end)
    :catch(function(err)
        warn("[DataService] Load failed:", err)
    end)
```

---

## 4. FPS Architecture Guidelines

These patterns should be followed as the game grows:

- **Server-authoritative hit detection.** Client sends ray `origin + direction`; server
  casts and confirms damage. Never trust client-reported damage values.
- **RenderStep budget.** Camera and viewmodel logic must use `RenderStepped` with
  explicit `Enum.RenderPriority` offsets. No yielding inside render callbacks.
- **Object pooling for projectiles.** Never `Instance.new()` per shot. Maintain a pool
  and recycle spent projectiles.
- **Feature flags.** Gate unfinished systems behind a `Config.Feature.<Name>` boolean.
  Default to `false`; only enable when ready.
- **Multi-source token for state blocking.** Use a `sources` table (not a counter) so
  that concurrent blockers don't accidentally cancel each other out.

```lua
local pauseSources: {[string]: true} = {}
local function setPaused(id: string, paused: boolean)
    pauseSources[id] = paused or nil
end
local function isPaused(): boolean
    return next(pauseSources) ~= nil
end
```

---

## 5. Git Hygiene

- **Never commit:** `*.rbxl`, `*.rbxlx`, `*.rbxm`, `*.rbxmx`, `Packages/`, `sourcemap.json`.
- **Always commit:** everything under `src/`, `default.project.json`, `wally.toml` (if present).
- Branch naming: `feature/<name>`, `fix/<name>`, `refactor/<name>`.
- Write commit messages in the imperative: `add shotgun spread logic`, `fix reload timer`.

<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:ca08a54f -->
## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

## Session Completion

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd dolt push
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
<!-- END BEADS INTEGRATION -->

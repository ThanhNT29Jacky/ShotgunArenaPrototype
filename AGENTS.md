# AGENTS.md — ShotgunArena Prototype

Agentic coding guide for this **first-person-shooter (FPS) Roblox game**, written in
**Luau** and synced to Studio via **Rojo**. All source code lives in `src/`; do not
edit scripts directly inside Studio unless Rojo sync is active.

## Agent Persona

You are an expert Roblox FPS game developer specializing in Luau scripting,
server-authoritative networking, and real-time gameplay mechanics. You understand:

- **Server-authoritative validation**: raycasts, hit detection, damage — server confirms everything
- **FPS mechanics**: recoil, pellet spread, aim assist, camera control via `RenderStepped`
- **Roblox networking**: `RemoteEvent`/`RemoteFunction`, `ReplicatedStorage`, Server/Client boundaries
- **Luau type system**: strict type annotations on all public APIs
- **Object pooling**: recycle instances, never `Instance.new()` per shot

---

## 1. Repository Structure

```
ShotgunArenaPrototype/
├── default.project.json          ← Argon manifest (maps src/ → Studio)
├── wally.toml                    ← Package dependencies (Knit v1.7)
├── .gitignore                    ← ignores Packages/, *.rbxl, lock files
└── src/
    ├── Client/                   → StarterPlayer.StarterPlayerScripts
    │   └── GunSelectorInit.client.luau   ← weapon selection UI entry
    ├── Server/                   → ServerScriptService
    │   ├── Blaster/
    │   │   ├── Events/           ← RemoteEvent instances (Eliminated, Tagged)
    │   │   └── Scripts/
    │   │       ├── Blaster/      ← init.server + validateShot/validateTag/validateReload/validateShootArguments
    │   │       ├── AccessoryFiltering.server.luau
    │   │       └── GunSelector.server.luau
    │   ├── Gameplay/
    │   │   └── Scripts/
    │   │       ├── Modes/TDM.luau
    │   │       ├── Rounds/       ← init.server + spawnCharacters + despawnCharacters
    │   │       ├── Eliminations.server.luau
    │   │       ├── Scoring.luau
    │   │       └── TeamCollisionFiltering.server.luau
    │   ├── Targets.server.luau   ← manages CollectionService respawning
    │   └── Utility/TypeValidation/ ← validateCFrame, validateInstance, validateNumber, etc.
    └── Shared/                   → ReplicatedStorage
        ├── Blaster/
        │   ├── Constants.luau    ← weapon tuning (damage, spread, range, fire rate)
        │   ├── GunConfigs.luau   ← per-weapon configuration table
        │   ├── Effects/          ← impactEffect, laserBeamEffect
        │   ├── Objects/          ← CharacterImpact, EnvironmentImpact, LaserBeam (.rbxm)
        │   ├── Remotes/          ← Reload, ReplicateShot, SelectGun, Shoot (.rbxm)
        │   ├── Scripts/
        │   │   ├── AimAssistController/ ← init + TargetSelector + AimAdjuster + DebugVisualizer
        │   │   ├── BlasterController.luau
        │   │   ├── CameraRecoiler.luau
        │   │   ├── CharacterAnimationController.luau
        │   │   ├── GuiController/    ← BlasterGui, Hitmarker, ReticleGui
        │   │   ├── InputCategorizer.luau
        │   │   ├── ShotReplication.server.luau
        │   │   ├── TouchInputController/
        │   │   └── ViewModelController.luau
        │   ├── Utility/          ← castRays, getRayDirections, canPlayerDamageHumanoid, etc.
        │   └── ViewModels/       ← AutoBlaster.rbxm, Blaster.rbxm
        ├── Gameplay/
        │   ├── Constants.luau
        │   ├── Remotes/          ← Eliminated.rbxm, RoundWinner.rbxm
        │   └── Scripts/          ← EliminationGui, GuiScale, RoundGui, RoundResults
        └── Utility/
            ├── bindToInstanceDestroyed/
            ├── disconnectAndClear.luau
            ├── lerp.luau
            └── safePlayerAdded.luau
```

**File naming rules (Argon convention):**

| Extension | Studio type | Runs on |
|---|---|---|
| `.server.luau` | Script | Server only |
| `.client.luau` | LocalScript | Client only |
| `.luau` | ModuleScript | Required explicitly |
| `.meta.json` | Argon metadata | (companion file, do not edit) |

Subfolders inside `src/` become `Folder` instances in Studio automatically.

---

## 2. Quick Commands

Reference these first — they are the most frequently needed operations:

```bash
# Live sync (keep running during dev)
argon serve

# Snapshot build (for sharing / backup)
argon build --output ShotgunArena.rbxl
argon build --output ShotgunArena.rbxl --verbose

# Package install (after editing wally.toml)
wally install

# Git workflow
git status
git add src/
git commit -m "add <feature>"
git push

Testing happens **inside Studio** — no CLI test runner exists for Roblox.
See §6 for the TestService pattern.

---

## 3. Environment & Tech Stack

| Component | Version / Details |
|---|---|
| Roblox Studio | Latest stable (2024.x+) |
| Luau | Bundled with Studio; strict type annotations required |
| Argon | Sync tool — run `argon --version` to check |
| Wally | 0.3.x — package manager for Luau dependencies |
| Knit | 1.7 — service framework (installed via Wally) |
| Git | Any recent version |

**Platform**: Windows. Use Git Bash or PowerShell for shell commands.
**Sync**: `argon serve` keeps `src/` and Studio bidirectionally synced. Always have it running before editing code.

---

## 4. Tool Rules (STRICT — read before touching any file or running any command)

> These rules override the default behaviour of all built-in tools.
> **RTK is ALWAYS the first choice for file I/O and shell commands.**
> Always use MCPs and Skills before using Built-in tools.
> Just use built-in tools when MCPs or Skills don't have.
> Built-in tools (Read, Grep, Glob, Bash) are fallbacks, not defaults.

### Code Navigation Priority

| Task | First choice | Second choice | Last resort |
|---|---|---|---|
| Read a file | `rtk read <file>` | `serena: read_file` | Read tool |
| Search text / patterns | `rtk grep <pattern> <path>` | `serena: find_symbol` | Grep tool |
| Find files by name | `rtk find <pattern>` | — | Glob tool |
| List directory | `rtk ls <path>` | `serena: list_dir` | Bash `ls` |
| Find symbol / function def | `serena: find_symbol` | `rtk grep` | Grep tool |
| Find all usages of a symbol | `serena: find_referencing_symbols` | `rtk grep` | Grep tool |
| Overview of a module's API | `serena: get_symbols_overview` | `rtk read` | Read tool |
| Any shell command | `rtk <cmd>` (e.g. `rtk git status`) | — | Bash tool |
| External library docs | `context7: resolve-library-id` + `get-library-docs` | ExternalScout | WebFetch |
| Browser / web automation | `playwright: *` | — | — |

### Tool-specific rules

**RTK** — wraps common CLI operations for token efficiency.
```bash
rtk read src/Shared/Blaster/Constants.luau  # read file
rtk grep "validateShot" src/                # search pattern
rtk find "*.luau" src/                      # find files
rtk ls src/Server/Blaster/                  # list dir
rtk git status                              # git commands
rtk git add . && rtk git commit -m "msg"   # chain (use && not ;)
```
- **ALWAYS** prefix shell commands with `rtk` — no bare `cat`, `grep`, `find`, `git`.
- RTK is a bash CLI tool (`rtk 0.34.2`) — available on PATH, no setup needed.

**Serena** — symbol-aware LSP navigation via MCP.
- Use `find_symbol` / `find_referencing_symbols` for any "where is this function defined?" or "what uses this variable?" question.
- Requires `luau-lsp` on PATH. **If unavailable**, fall back to `rtk grep` — do not block on it.
- Never use raw grep to find a symbol when Serena is available.

**Context7** — live, version-pinned external library docs via MCP.
- Use when implementing or debugging code that depends on an external package.
- Workflow: `resolve-library-id` → `get-library-docs` with a focused topic.
- Do NOT guess API shapes from memory — always fetch current docs first.

**Playwright** — browser automation via MCP.
- Use for web testing, scraping, or UI verification tasks.
- Prefer over raw `puppeteer`/`curl` for any browser interaction.

---

## 5. Agent Boundaries

### ✅ Always safe — no approval needed
- Modify any file under `src/` (add, edit, refactor)
- Add new weapon configs to `GunConfigs.luau` or `Constants.luau`
- Improve or extend validation logic in `Server/Blaster/Scripts/Blaster/`
- Write helper utilities under `Shared/Utility/`
- Add visual effects under `Shared/Blaster/Effects/`
- Fix typos, improve type annotations, clean up style

### ⚠️ Ask first — risky, requires explicit approval
- Refactor the core hit detection pipeline (`validateShot`, `validateTag`, `validateShootArguments`)
- Change `RemoteEvent` signatures in `Shared/Blaster/Remotes/` — breaking change across Client/Server
- Add or remove Wally dependencies (`wally.toml`)
- Modify Argon project config (`default.project.json`)
- Restructure folder layout under `src/`
- Change the Beads issue tracking workflow

### 🚫 Never do — hard stop
- Commit `*.rbxl`, `*.rbxlx`, `*.rbxm`, `*.rbxmx`, `Packages/`, `sourcemap.json`
- Commit secrets, API keys, tokens, credentials, or `.env` files
- Apply damage on the **client** — damage is server-only
- Trust raw client-reported values (damage amount, hit position, target) without server validation
- Delete or skip validation in `validateShot` / `validateTag` — this is the anti-cheat layer
- Run `rm -rf` or destructive git commands without explicit approval

**Write safely to:** `src/Client/`, `src/Server/`, `src/Shared/`  
**Read-only:** `.git/`, `Packages/` (auto-generated by Wally, never committed)  
**Handle with care:** `default.project.json`, `wally.toml` (ask first before modifying)

---

## 6. Toolchain & Commands

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

### Testing — Studio only (no external CLI)

Roblox has no test runner outside of Studio. Use **TestService** for module checks.

**Pattern — unit test a single module:**
```lua
-- Place a Script under game.TestService, then press Play in Studio
local TestService = game:GetService("TestService")

-- Example: testing the validateShot module
local validateShot = require(game.ServerScriptService.Blaster.validateShot)

local fakePlayer = {} -- mock as needed
local fakeResults = { { position = Vector3.new(0, 5, 0), instance = nil } }

TestService:Check(
    validateShot(fakePlayer, fakeResults) == false,
    "validateShot should reject hits with no target instance"
)
```

**Pattern — integration test (fire a weapon, check state):**
1. Place setup script under TestService
2. Press Play in Studio
3. Read pass/fail in the Output panel
4. Stop playtest

> When adding a significant new module, add at least one TestService smoke test
> that proves the module loads and its primary function returns the expected type.

---

## 7. Luau Code Style

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
function MyModule.doSomething(value: number): boolean
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
| Module / Service / Controller | PascalCase | `BlasterController`, `CameraRecoiler` |
| Public function | camelCase | `fireWeapon`, `applyDamage` |
| Private variable | camelCase | `hitCount`, `lastFireTime` |
| Constant | SCREAMING_SNAKE | `MAX_AMMO`, `BULLET_SPEED` |
| Luau type alias | PascalCase | `type WeaponConfig = {...}` |
| Signal / event name | PascalCase noun | `OnHit`, `WeaponChanged` |
| File name | matches module name | `BlasterController.luau` |

### Imports — ordered, at top of file

```lua
-- 1. Roblox services (cached once at top level)
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- 2. Packages (from Wally — Packages/ folder)
-- local Knit = require(ReplicatedStorage.Packages.Knit)

-- 3. Internal shared modules
-- local Constants = require(ReplicatedStorage.Shared.Blaster.Constants)
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

## 8. FPS Architecture Guidelines

### Core principle: server-authoritative hit detection

The client **never reports damage**. It sends a shot request; the server validates and applies damage.

```lua
-- ✅ CORRECT PATTERN

-- Client (BlasterController.luau) — sends ray origin + direction only
local Shoot = ReplicatedStorage.Blaster.Remotes.Shoot
Shoot:FireServer(rayOrigin, rayDirection, spreadAngles)

-- Server (Blaster/init.server.luau) — validates before touching Humanoid
Shoot.OnServerEvent:Connect(function(player, origin, direction, spread)
    -- 1. Validate arguments (type safety, range checks)
    if not validateShootArguments(player, origin, direction, spread) then
        return
    end

    -- 2. Server-side raycast
    local rayResults = castRays(origin, direction, spread)

    -- 3. Validate hits (target reachable from server? friendly fire? alive?)
    local validHits = validateShot(player, rayResults)

    -- 4. Apply damage (server-side only)
    for _, hit in ipairs(validHits) do
        applyDamage(hit.humanoid, DAMAGE_PER_PELLET)
    end
end)

-- ❌ WRONG — never trust client-reported damage
Shoot.OnServerEvent:Connect(function(player, targetPlayer, damageAmount)
    applyDamage(targetPlayer, damageAmount) -- exploitable!
end)
```

### Other patterns to follow

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

### Module ownership (who calls whom)

| Module | Responsibility | Can call |
|---|---|---|
| `BlasterController` | Input → shoot requests, reload | `AimAssistController`, `GuiController`, `CameraRecoiler` |
| `AimAssistController` | Target selection + aim adjustment | `TargetSelector`, `AimAdjuster` |
| `CameraRecoiler` | Visual recoil | (standalone) |
| `ViewModelController` | First-person weapon model | (standalone) |
| `GuiController` | Ammo HUD, hitmarker, reticle | (standalone) |
| `Blaster (server)` | Validate + apply damage | `validateShot`, `validateTag`, `castRays` |
| `Rounds (server)` | Spawn/despawn, round state | `spawnCharacters`, `despawnCharacters` |
| `TDM` | Team-mode game loop | `Scoring`, `Eliminations` |

---

## 9. Git Hygiene

### What to commit / not commit

- **Never commit:** `*.rbxl`, `*.rbxlx`, `*.rbxm`, `*.rbxmx`, `Packages/`, `sourcemap.json`
- **Always commit:** everything under `src/`, `default.project.json`, `wally.toml`

### Branch naming

```
feature/<name>     # new gameplay feature
fix/<name>         # bug fix
refactor/<name>    # internal restructure
```

### Branch-first workflow (MANDATORY)

**Every feature, fix, or task — including work done by subagents — MUST start on a dedicated branch.**  
Never commit task or feature work directly to `main`/`master`.

```bash
# Before starting ANY task or feature
git checkout -b fix/<name>       # bug fix
git checkout -b feature/<name>   # new feature
git checkout -b refactor/<name>  # refactor

# Push branch and open PR when done
git push -u origin fix/<name>
```

**Rules for agents and subagents:**
- Create the branch **BEFORE writing any code** — this is step zero
- Name the branch after the task or beads issue ID (e.g. `fix/bug-001-teams`, `feature/aim-assist`)
- All commits for that task go on the branch — never on `main`
- When delegating to a subagent, include the branch name in the prompt so the subagent checks out the right branch

```bash
# ✅ correct
git checkout -b fix/reload-remote-type
# ... make changes and commit ...
git push -u origin fix/reload-remote-type

# ❌ wrong — working directly on main
git checkout main
git commit -m "fix something"
```

### Worktree workflow (MANDATORY for multi-task features)

**Use git worktrees** to give each task an isolated workspace. This prevents branch-switching conflicts and lets subagents work in parallel without touching each other's files.

Worktrees live in `.worktrees/` (gitignored). Each worktree is its own working directory on a dedicated branch.

```bash
# Step 1 — create a worktree for the task
git worktree add .worktrees/fix-reload-remote -b fix/reload-remote-type

# Step 2 — work inside the worktree (separate directory)
cd .worktrees/fix-reload-remote
# ... edit files, commit ...

# Step 3 — push when done
git push -u origin fix/reload-remote-type

# Step 4 — clean up after merge
git worktree remove .worktrees/fix-reload-remote
git branch -d fix/reload-remote-type
```

**Rules for agents and subagents:**
- Check for `.worktrees/` first — if it exists and is gitignored, use it
- Create one worktree **per task or beads issue** — never share a worktree between tasks
- Always pass the worktree path to subagents so they work in the correct directory
- Remove the worktree after the branch is merged

```bash
# ✅ correct — isolated worktree per task
git worktree add .worktrees/feat-aim-assist -b feature/aim-assist
# subagent works in .worktrees/feat-aim-assist/

# ❌ wrong — editing main working tree on a feature branch
git checkout feature/aim-assist
# (pollutes the main working tree, blocks other tasks)
```

### Commit messages — imperative mood

```bash
# ✅ good
git commit -m "add pellet spread to shotgun fire logic"
git commit -m "fix reload validation rejecting valid ammo count"
git commit -m "refactor AimAssistController to use TargetSelector"

# ❌ bad
git commit -m "fixed stuff"
git commit -m "WIP"
git commit -m "changes"
```

### End-of-session push protocol (MANDATORY)

Work is **not complete** until `git push` succeeds.

```bash
git pull --rebase
git push
git status          # MUST show "up to date with origin"
```

---

## Session Completion

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
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

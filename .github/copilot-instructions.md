# Copilot Instructions — ShotgunArena Prototype

First-person-shooter Roblox game written in **Luau**, synced to Roblox Studio via **Rojo**. All source lives in `src/`; never edit scripts directly in Studio unless `rojo serve` is running.

## Dev Commands

```bash
# Install Wally packages (run once per session, or after editing wally.toml)
wally install

# Live sync — keep running the entire dev session; bidirectional src/ ↔ Studio
rojo serve

# Build a .rbxl snapshot
rojo build --output ShotgunArena.rbxl
```

## Tool Rules

Prefer MCP tools and Skills over built-in tools. Built-ins (grep, glob, view, powershell) are fallbacks when an MCP doesn't cover the task.

### Code navigation priority

| Task | First choice | Fallback |
|---|---|---|
| Find symbol / function definition | `serena: find_symbol` | grep |
| Find all usages of a symbol | `serena: find_referencing_symbols` | grep |
| Overview of a module's public API | `serena: get_symbols_overview` | view |
| Read a file | view | — |
| Search text / patterns | grep | — |
| Find files by name | glob | — |

> Serena requires `luau-lsp` on PATH. If unavailable, fall back to grep — do not block on it.

### Roblox Studio MCP

Use Studio MCP tools whenever you need to interact with a running Studio session:

- `execute_luau` — run Luau code inside Studio (create instances, test logic)
- `inspect_instance` — verify instance hierarchy, properties, children
- `screen_capture` — confirm Output panel is error-free after changes
- `start_stop_play` — start/stop a play session for in-game testing

**Creating `.rbxm` files**: never write them as text. Use `execute_luau` to create the instance in Studio, then export to `src/.../[name].rbxm`.

### Context7 MCP

Use Context7 for live, version-accurate docs before writing code against an external package (Roblox API, Knit, Wally packages). Do not guess API shapes from memory.

```
context7: resolve-library-id  →  get-library-docs (focused topic)
```

### Playwright MCP

Use for any browser automation, web scraping, or UI verification tasks.

## Git Workflow

- Run git through `rtk` in shell commands, for example `rtk git status` or `rtk git add src/ && rtk git commit -m "..."`; avoid bare `git`.
- Use git worktrees for multi-task work or parallel subagents. Keep them under `.worktrees/` and give each task its own branch.
- Prefer branch names like `fix/<name>`, `feature/<name>`, or `refactor/<name>`.
- Keep commit messages short and imperative.
- Do not consider work complete until changes are pushed successfully and the branch is clean/up to date.

---

## Testing

No CLI test runner. Tests run inside Studio via **TestService**:

1. Create a Script under `game.TestService`
2. Press **Play** in Studio; check the Output panel
3. Press **Stop** to end

```lua
-- Single-module smoke test pattern
local TestService = game:GetService("TestService")
local myModule = require(game.ReplicatedStorage:WaitForChild("MyModule"))
TestService:Check(myModule ~= nil, "module loaded")
```

## `src/` → Studio Mapping

| `src/` directory | Studio container | Script type |
|---|---|---|
| `src/Server/` | `ServerScriptService` | `.server.luau` = Script |
| `src/Client/` | `StarterPlayer.StarterPlayerScripts` | `.client.luau` = LocalScript |
| `src/Shared/` | `ReplicatedStorage` **(root)** | `.luau` = ModuleScript |

**Critical**: `src/Shared/` maps to the **root** of ReplicatedStorage, not a subfolder. Use:
```lua
ReplicatedStorage:WaitForChild("Blaster")   -- ✅
ReplicatedStorage:WaitForChild("Shared")    -- ❌ doesn't exist
```

Subfolders inside `src/` become `Folder` instances automatically. `.meta.json` files are Rojo metadata — don't edit them manually.

## Architecture Overview

The game is organized around the **blaster/weapon system**, not generic services. There is no active service framework (Knit is installed but not used in current code — the codebase uses direct module requires and controllers).

### Shot lifecycle (server-authoritative)

1. **Client** fires `Shoot` RemoteEvent with: `timestamp`, `blaster` Tool, `origin` CFrame, `tagged` table (`{[string]: Humanoid}`)
2. **Server** (`init.server.luau`) validates arguments → validates shot timing/ammo → **recasts all rays using the same timestamp as the spread seed** → validates each reported hit → applies damage → fires `Tagged`/`Eliminated` BindableEvents → replicates shot to other clients

The `timestamp` doubles as both an anti-spam guard and the random seed for pellet spread, so the server can reproduce the exact spread pattern without trusting client-supplied ray directions.

`tagged` uses `{[string]: Humanoid}` (string keys) because non-contiguous arrays don't replicate reliably over RemoteEvents.

### Key modules

| Module | Location | Role |
|---|---|---|
| `init.server.luau` | `Server/Blaster/Scripts/Blaster/` | Entry point: receives shots, validates, applies damage |
| `validateShot` / `validateTag` | same folder | Anti-cheat validation — never weaken these |
| `BlasterController.luau` | `Shared/Blaster/Scripts/` | Client weapon controller: input, fire-rate, sends ShootRequest |
| `CameraRecoiler.luau` | `Shared/Blaster/Scripts/` | Applies recoil to camera via RenderStepped |
| `ViewModelController.luau` | `Shared/Blaster/Scripts/` | Viewmodel animation and offset, RenderStepped |
| `AimAssistController/` | `Shared/Blaster/Scripts/` | 5-module aim assist system (geometric math) |
| `Constants.luau` | `Shared/Blaster/` | All weapon tuning constants and attribute name strings |
| `GunConfigs.luau` | `Shared/Blaster/` | Per-weapon config table (damage, spread, ROF, etc.) |
| `castRays.luau` | `Shared/Blaster/Utility/` | Object-pooled raycasting |
| `getRayDirections.luau` | `Shared/Blaster/Utility/` | Pellet spread generation (seeded by timestamp) |

### `.rbxm` files in `src/`

These are **committed binary Roblox assets**, not build outputs:
- `Shared/Blaster/Remotes/*.rbxm` — RemoteEvent/RemoteFunction instances
- `Shared/Blaster/Objects/*.rbxm` — Effect models (impacts, laser beam)
- `Shared/Blaster/ViewModels/*.rbxm` — Viewmodel rigs
- `Server/Blaster/Events/*.rbxm` — BindableEvent instances

Never edit `.rbxm` files as text. To create/modify them, use Studio and export the instance. Never delete them unless intentionally removing the feature.

### Weapon attributes

Weapon stats live as **Roblox Instance attributes** on the Tool object, not as Lua variables. The server always reads attributes from the Tool on the server side — never from client-supplied values. Attribute names are defined as constants in `Constants.luau` (e.g., `Constants.DAMAGE_ATTRIBUTE = "damage"`).

To add a new weapon, add an entry to `GunConfigs.luau` matching the attribute names in `Constants.luau`.

### RenderStepped ordering

`CameraRecoiler` and `ViewModelController` both bind to `RenderStepped` with explicit priority names (`"Recoiler"`, `"BlasterViewModel"`). The order matters for smooth FPS feel — don't change priorities without testing in-game.

## Luau Conventions

### Type annotations — mandatory on all public APIs

```lua
-- ✅ correct
local function shoot(origin: Vector3, direction: Vector3): RaycastResult?

-- ❌ wrong
local function shoot(origin, direction)
```

Annotate: function params, return types, table fields, and module-level variables.

### Module structure

```lua
-- 1. Roblox services (cached at top level — NEVER inside loops or functions)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- 2. Internal requires
local Constants = require(ReplicatedStorage.Blaster.Constants)

local MyModule = {}

-- Private: camelCase
local activeCount: number = 0

-- Public: PascalCase
function MyModule.DoSomething(value: number): boolean
    ...
end

function MyModule.Start(): ()  -- lifecycle hook
    ...
end

return MyModule
```

### Naming

| Kind | Style |
|---|---|
| Module / Controller / Type | PascalCase |
| Public function | PascalCase (on module table) |
| Private variable / local function | camelCase |
| Constant | `SCREAMING_SNAKE` |
| Signal / event name | PascalCase noun |

### Error handling

```lua
-- Use xpcall in server event handlers
local ok, err = xpcall(onShootEvent, function(e)
    warn("[Blaster] error:", e, debug.traceback())
    return e
end, player, ...)

-- Use pcall for IO; warn() + graceful return on failure — never bare error()
```

## Hard Rules

- **Never apply damage on the client.** Only the server calls `Humanoid:TakeDamage()`.
- **Never trust client-supplied damage, hit positions, or target identity** without server-side ray revalidation.
- **Never weaken `validateShot` or `validateTag`** — these are the anti-cheat layer.
- **Never commit**: `*.rbxl`, `*.rbxlx`, `Packages/`, `sourcemap.json`, `wally.lock` (all gitignored). `.rbxm` files *inside `src/`* are the exception — commit those.
- **Never call `game:GetService()` inside a loop or function** — cache at top of file.
- **Never edit `.rbxm` files as text** — use Studio to create/modify Roblox instances.

## Ask Before Changing

- `RemoteEvent` signatures in `Shared/Blaster/Remotes/` — breaking change across Client/Server boundary
- Core hit detection pipeline (`validateShot`, `validateTag`, `validateShootArguments`)
- `default.project.json` (Rojo project/container mappings)
- `wally.toml` (package dependencies)
- Folder structure under `src/`

## Known Issues

- **`AimAdjuster.luau` line ~154**: `subjectVelocity` should use `CFrame.identity` but a Roblox TweenService bug prevents it — awaiting platform fix.
- **No linter/formatter**: No Selene or StyLua configured. Style is maintained manually.
- **Knit declared but unused**: `wally.toml` declares Knit; the codebase uses direct module requires instead. New code should follow the controller pattern, not Knit services.

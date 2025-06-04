📦 Project: SynRNG
SynRNG is a modular Roblox game framework built around a synergy-based idle combat system. Players build Astral Webs by linking together synergy components—Cores, Modifiers, Chains, and Artifacts—to generate damage output against a shared boss entity. Every 60 seconds, the server triggers a global evaluation tick where all player webs are processed simultaneously.

The project includes:

- 🔁 Server-side tick timer with synced client UI
- 🧠 Synergy evaluation engine for processing node chains
- 🎰 Randomized loot/roll system with a rarity-weighted item pool
- 💀 Global boss system with health syncing and damage contribution
- 💾 Persistent player data storage for inventory and configurations
- ⚙️ Fully modular services (server/services/) and shared data modules (shared/data/)
- 📡 Decoupled RemoteEvents (shared/remotes/) for clean client-server communication

Designed with Rojo, module encapsulation, and long-term scalability in mind.

---

Root layout:
src/
- client/ → StarterPlayerScripts/Client
- server/ → ServerScriptService/Server
- shared/ → ReplicatedStorage/Shared

---

client/
For all LocalScripts and player-facing GUI logic:

- AstralWebClient.client.lua — handles astral node dragging, linking, and UI
- TickTimerGui.client.lua — displays synced countdown
- BossInfoGui.client.lua — shows boss health/name
- SFXController.client.lua — manages local sounds and mute toggle

client/
├── astral/
│   └── AstralWebClient.client.lua
├── gui/
│   ├── TickTimerGui.client.lua ✅
│   └── BossInfoGui.client.lua
└── sfx/
    └── SFXController.client.lua

---

server/
For all ModuleScripts that run on the server:

- SynergyEvaluationService.server.lua — evaluates Astral Webs on tick
- TickTimerService.server.lua — manages global 60s timer
- BossService.server.lua — tracks boss health/damage
- SpinService.server.lua — handles loot rolls
- PlayerDataService.server.lua — loads/saves player configs

server/
└── services/
    ├── SynergyEvaluationService.server.lua ✅
    ├── TickTimerService.server.lua ✅
    ├── BossService.server.lua
    ├── SpinService.server.lua
    ├── PlayerDataService.server.lua

---

shared/
For everything both client and server can access:

- SynergyComponentsDB.lua — holds component definitions ✅
- ItemData.lua — master loot table
- EnemyRegistry.lua — current boss data (eventually EnemyRegistry)
- Remotes/ — contains all RemoteEvents and RemoteFunctions ✅ (setup using init.lua)

shared/
├── data/
│   ├── SynergyComponentsDB.lua ✅
│   ├── ItemData.lua
│   ├── EnemyRegistry.lua
├── remotes/
│   ├── RequestPlayerDataFunction (RemoteFunction)
│   ├── RequestInventoryFunction (RemoteFunction)
│   ├── RequestBossInfoFunction (RemoteFunction)
│   ├── NodeActivationEvent (RemoteEvent)
│   ├── BossHealthUpdateEvent (RemoteEvent)
│   ├── ConfirmRollEvent (RemoteEvent)
│   ├── AwardComponentEvent (RemoteEvent)
│   ├── LiveEvaluationUpdateEvent (RemoteEvent)
│   ├── ChatMessageReceivedEvent (RemoteEvent)
│   ├── ErrorNotificationEvent (RemoteEvent)
│   ├── SendChatMessageEvent (RemoteEvent)
│   ├── TickResultsEvent (RemoteEvent)
│   ├── UpdatePlayerSettingsEvent (RemoteEvent)
│   ├── RequestRollEvent (RemoteEvent)
│   ├── SubmitAstralWebConfigurationEvent (RemoteEvent)
│   └── UpdateAstralWebTimerEvent (RemoteEvent)
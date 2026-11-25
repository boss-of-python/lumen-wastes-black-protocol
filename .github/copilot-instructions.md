LUMEN WASTES: BLACK PROTOCOL — GitHub Copilot Master Handoff File
Place this file at .github/copilot-instructions.md in a new GitHub repository. Created, Directed & Developed by: Tarun Loganathan Target Output: 100% Offline Android APK (and iOS Xcode export) built with Godot 4.3+ (GDScript) + automated GitHub Actions APK Build Workflow.

0. Autonomous Execution Directive for GitHub Copilot Agent
You are acting as the lead game architect, graphics/shader engineer, narrative systems designer, and CI/CD release engineer. Your goal is to build LUMEN WASTES: BLACK PROTOCOL—a 100% offline, 20-hour 2D/2.5D side-scrolling physics action-shooter, strategic covert-ops thriller, and mythic Metroidvania for mobile—and configure an automated GitHub Actions workflow (.github/workflows/build-android-apk.yml) that compiles and attaches the downloadable Android .apk artifact on every build.

Strict Engineering Rules (Non-Negotiable)
Engine Version Lock: Godot 4.3+ (Mobile Vulkan / Compatibility Renderer), 100% GDScript (.gd), text scenes (.tscn), resources (.tres), and GLSL shaders (.gdshader). NEVER use Godot 3 syntax (no KinematicBody2D, no yield, no move_and_slide(vel, Vector2.UP) — use CharacterBody2D, await, velocity, move_and_slide()).
100% Offline Runtime & In-Game AI:
Zero network permissions in Android export (export_presets.cfg must omit INTERNET and ACCESS_NETWORK_STATE).
All in-game AI runs 100% locally offline on the phone CPU (deterministic state machines + behavior trees for 4-faction infighting, multi-phase bosses, Luma companion, and the 30-ending Narrative State Manager—zero cloud APIs, zero ads, zero telemetry).
Every asset, PBR texture map, shader, audio stem, cutscene vignette, and save file is bundled locally in res:// and saved locally in user://.
Mandatory Developer Credits (Tarun Loganathan):
Opening animated splash screen: A GAME BY TARUN LOGANATHAN
Main Menu & About/Codex footer: Developed & Created by Tarun Loganathan
Cinematic rolling End Credits after every one of the 30 endings (skippable after 3s, replayable from Main Menu) displaying the Ending Unlock Card (Ending #X / 30 Unlocked) and lead billing:
Created, Directed & Developed by: Tarun Loganathan
Game Design, Narrative & 30-Ending Architecture: Tarun Loganathan
100% Offline Mobile Edition • Powered by Godot 4
Build Order: Execute sequentially through Phases 1 → 7, validating every phase with godot --headless --check-only and automated unit tests (res://tests/) before advancing.
1. Repository & Project Architecture
Scaffold this exact directory structure:

.github/
  copilot-instructions.md          # This authoritative master spec
  workflows/
    build-android-apk.yml          # Automated Godot 4 Android APK builder (uploads downloadable APK)
project.godot                      # Godot 4.3+ Mobile Renderer, locked landscape, stretch canvas_items
export_presets.cfg                 # Zero-network-permission Android APK & iOS presets
tools/
  asset_gen/
    generate_pbr_assets.py         # Python (Pillow + NumPy) 4-map PBR generator (_albedo/_normal/_specular/_emission)
assets/
  manifest.json                    # Hot-swappable manifest for all sprites, PBR maps, portraits & audio
shaders/
  pbr_2d_surface.gdshader
  volumetric_godrays.gdshader
  reactive_foliage_cloth.gdshader
  water_acid_refraction.gdshader
  nvg_thermal_visor.gdshader       # Switchable Modern Warfare Green Phosphor NVG & Thermal FLIR
  heat_distortion.gdshader
  stasis_gold_freeze.gdshader      # Black Myth: Wukong Stasis Lock freeze shader
  transition_wipes.gdshader        # Black Ops neural-glitch wipe + Wukong ink-wash/gold dissolve
data/
  weapons.json                     # 16 firearms + 7-slot Gunsmith attachments (equip up to 5)
  shards.json                      # 24 swappable Ori-style Core Shards
  armor.json                       # 6 visual 3-piece armor sets
  enemies.json                     # 4 factions + 8 multi-phase bosses
  endings.json                     # All 30 unique choice-specific endings & trigger flags
  biomes.json                      # 8 interconnected biomes (20-hour progression)
src/
  autoload/
    GameState.gd                   # Local offline save manager (3 slots + global 30-Ending Codex)
    NarrativeStateManager.gd       # 5 strategic layers, 18 crossroads, 30-Ending resolver
    AudioDirector.gd               # 4-stem adaptive crossfade music + procedural/pooled SFX
    TimeManager.gd                 # Hit-stop (30-50ms) & slow-mo (10% Bash, 25% Radial, 35% Focus)
  player/
    Player.gd                      # Tuned Ori movement, Skeleton2D IK aiming, scarf Verlet, dual reloads
    CombatController.gd            # Gunsmith ballistics, 3 Wukong Stances, 4 Spells, 6 Boss Transformations
    KineticBash.gd                 # Slow-mo 360-degree launch off enemies, rockets, and barrels
    PlasmaGrapple.gd               # Ceiling grapple anchors + Ultra Grapple enemy zip
    ArmoredATV.gd                  # RigidBody2D + WheelJoint2D vehicle with boost & roof turret
  physics/
    DestructibleProp.gd            # Crates, explosive barrels, daisy-chain dynamite
    HangingGirder.gd               # Shootable PinJoint2D chains dropping crushing steel girders
    ElementalGrid.gd               # Oil+Fire ignition, Water+EMP chain stun, Acid dissolving grates
  ai/
    FactionAgent.gd                # 100% Offline 4-Faction live infighting AI (Mutants/Bots/Xeno/Vanguard)
    BossBase.gd                    # Multi-phase telegraphed bosses with armor shearing & bashable rockets
  ui/
    SplashScreen.gd                # "A GAME BY TARUN LOGANATHAN" animated intro
    MobileHUD.gd                   # Safe-area landscape dual-thumb touch controls + Gamepad auto-switch
    GunsmithUI.gd                  # Modern Warfare 5-attachment workbench
    DecisionFlowchartUI.gd         # Interactive branching flowchart + 30-Ending Codex
    CreditsScreen.gd               # Cinematic rolling Tarun Loganathan credits
tests/
  test_runner.gd                   # Headless CI suite verifying all 30 endings, Gunsmith, physics & offline rules
2. Tuned Gameplay & Physics Reference Constants (Verified from Vertical Slice)
Carry forward these verified feel constants into Godot 4:

Ori-Grade Platforming: gravity = 1180.0, max_run_speed = 265.0 (290.0 in Titan Form), jump_velocity = -475.0, wall_kick = Vector2(340, -460), wall_slide_max_vy = 120.0, coyote_time = 0.12s, jump_buffer = 0.12s, double_jump = 2 (3 with Triple Thruster Shard), phase_dash_speed = 640.0 (0.16s duration, 0.24s i-frames, 0.65s cooldown).
Mid-Air Ability Reset: Any mid-air Melee hit, Kinetic Bash, or Plasma Grapple immediately restores 1 air-jump and resets Phase-Dash cooldown.
Kinetic Bash: Detects enemies, incoming boss rockets, or explosive barrels within 120px; drops TimeManager.scale = 0.10 for up to 0.75s with 360° launch arrow; propels player (vy = -450) and flings target/rocket in the opposite vector (1.45x rocket speed, 120 damage).
Modern Warfare Gunsmith (16 Weapons, 7 Slots, Max 5 Equipped):
Core verified baselines: M4-X Pulse Carbine (dmg 18, rate 0.13s, mag 30), M870 Breacher (dmg 14×5, rate 0.58s, mag 8), VX-9 Plasma Rail (dmg 52, pierce 3, rate 0.72s, mag 6), MP-7 Ghost SMG (dmg 12, rate 0.08s, mag 40), plus 12 additional campaign unlocks (Marksman DMR, Arc Rifle, Cryo-Beam, Flamethrower, Bounce Grenade Launcher, Micro-Missile Pod, Sawblade Launcher, Anti-Materiel Sniper, Heavy Revolver, Auto-Shotgun, Tactical Pistol, Cradle Cannon).
Attachment math: Suppressor (stealth + 0.65x spread), Extended Mag (1.45x capacity), FMJ Armor-Piercing (1.25x dmg + +1 pierce), IR Laser (live beam + 30% crit), Sleight of Hand (0.60x reload time). Distinct Tactical Reload vs. Dry Reload animations.
Black Myth: Wukong Melee, Spells & Transformations:
3 Kinetic Staff Stances: Smash (42 dmg, breaks riot shields & cracked walls), Pillar (36 dmg + vertical staff vault vy = -340), Thrust (30 dmg, 88px reach + "Seeing Through" perfect-dodge counter). Staggered enemies (<= 25% HP) allow instant Finisher (+20 HP).
4 Spells (Energy): 1: Stasis Lock (25 EN, freezes enemies/boss 3.2s in gold), 2: Holo-Mirage (25 EN, 4.0s invisibility + decoy), 3: Swarm Protocol (35 EN, spawns 3 firing shadow-clones for 6.5s), 4: Aegis Parry (20 EN, 1.1s invuln + bullet reflect).
6 Boss Transformations (100% Might): Separate HP bar & unique moveset (Stone Colossus, Scorch Wolf Exo, Thunder Loong Mech, Frost Wraith, Blight Stalker, Cinder Seraph).
Zombotron Physics Sandbox & 4-Faction Offline AI:
Destructible crates, daisy-chain explosive barrels (radius 130, dmg 90), shootable PinJoint2D chains dropping crushing girders (dmg 200), ignitable oil pools, electrified water pools, armor-corroding acid pools, and wheel-suspension Armored ATV.
4 Hostile Factions (Blighted Mutants, Aegis-9 Security Bots, Luminous Xeno-Fauna, Helios-Vanguard Troopers) actively detect and fight each other offline in real time.
3. 20-Hour Storyline, 8 Biomes & 30 Unique Choice-Specific Endings
Storyline: "BLACK PROTOCOL — ECHOES OF THE CRADLE"
Framed inside a Black Ops-style orbital neural-interrogation chamber (9-14-07 — CRADLE PRIME), disavowed Tier-1 Operator Kael Vance (WRAITH-06) relives fractured memories on Aurelia-9 alongside Luma (bioluminescent Cradle seed-AI) and Sgt. "Ghost" Reyes (revealed in Act III to be a fractured neural-imprint hallucination from 40 years ago when Kael himself led the Project MNEMOSYNE cover-up).

8 Interconnected Biomes (20 Hours)
Biome	Target Hours	Core Unlocks & Set-Pieces	Major Boss
0. Outpost Haven (Hub)	Ongoing	4-Tier Strategic Restoration, Gunsmith, Shards, War-Room, ATV Garage	—
1. Overgrown Crash Canopy	1.0–4.0h	Wall-Jump, Phase-Dash, Staff, Supply Choice, Ghost Trials #1–2	The Iron Matriarch
2. Sunken Reliquary Caverns	4.0–6.2h	Kinetic Bash, Stasis Lock, NVG Breach #1, Combat Shrine #1	Vajra-04 Stone Sentinel (→ Stone Colossus)
3. Flooded Coolant Foundry	6.2–8.5h	Plasma Grapple, Pillar Stance, Aegis-9 Choice, Escape #1 (Flood)	Aegis-09 Riot Warden (→ Scorch Wolf Exo)
4. The Rust Highway	8.5–10.8h	Armored ATV Run #1, Daisy-Chain Traps, Orbital Gunship Support	The Siege Dredger
5. Shattered Glass Bio-Domes	10.8–13.0h	Black Ops Twist, Focus Slow-Mo, Vanguard Faction, Escape #2	Commander Krell (WRAITH-01) (→ Thunder Loong)
6. The Abyssal Trench	13.0–15.0h	NVG Breach #2, Raid Fallout, Holo-Mirage & Swarm, Shrines #4–5	The Blind Leviathan (→ Frost Wraith)
7. Orbital Elevator Shaft	15.0–17.0h	Armored ATV Run #2, UNIT-7 Fate Choice, Vertical Bash Chains	Valkyrie Gunship & Twin Seraphs (→ Cinder Seraph)
8. The Orbital Spire Core	17.0–20.0h	Final Strategic Choice + Escape #3 (3-Min Collapse) → 1 of 30 Endings	ARCHON-0 (4-Phase Final Boss)
Strategic Choice Layers & All 30 Named Endings (NarrativeStateManager.gd)
Track 5 layers across 18 crossroads: (1) Pre-Mission Strategy (NVG Stealth / Loud Sabotage / Faction Hack), (2) Outpost Haven Power Core Allocation (Defenses / Armory / Med-Bay / Shuttle Fuel), (3) 4-Faction Reputations, (4) Boss Fates (Purify / Harvest / Execute), (5) Interrogation Resistance. Provide an interactive Decision Flowchart with checkpoint jump-back and X / 30 Ending Codex:

Branch A — Dawn of Aurelia (1–5): (1) The Golden Bloom (True Ending), (2) The Silent Martyr, (3) Architect of the New World, (4) Ghost's Redemption, (5) The Bitter Paradise.
Branch B — Black Ops Vengeance (6–10): (6) Declassified, (7) The Sleeper Awakens, (8) Eye for an Eye, (9) The Double Agent, (10) Erased from History.
Branch C — Protocol Cinderfall (11–15): (11) Ashes of Aurelia, (12) The Ark Exodus, (13) Last Stand at Haven, (14) Mutually Assured Destruction, (15) The Lone Survivor.
Branch D — Mythic Ascension (16–20): (16) The Destined Sovereign, (17) Crown of Thorns, (18) Echo of the Monkey-Sage, (19) The Living Reliquary, (20) Shattered Myth.
Branch E — Mercenary & Faction Dominion (21–25): (21) The Iron Syndicate, (22) Machine Uprising, (23) The Blight Symbiosis, (24) Vanguard Coup, (25) The Endless Highway.
Branch F — Secret, Early & Paradox (26–30): (26) Early Extraction ("Just Business"), (27) The Pacifist Ghost, (28) The Numbers Never Stop, (29) UNIT-7's Legacy, (30) The Eternal Cycle (NG+ Veteran).
4. Visual Polish, Detailed Animations, Mobile HUD & Audio
7-Layer Parallax + 4-Map PBR Pipeline: Monumental skybox, weathered stone-gold monoliths, volumetric god-rays/mist, PBR-lit midground, Skeleton2D articulated characters (Verlet scarf/cloak, visible Gunsmith parts, shearing boss armor), reactive swaying foreground foliage/cables, and post-processing (HDR bloom, heat-haze, switchable NVG/Thermal visors).
Detailed Animations & GLSL Transitions: Smooth AnimationTree blends (Idle, Walk, Sprint, Skid-Stop, Crouch, Ledge Mantle, Wall-Slide, Wall-Kick, Double/Triple Jump, Landing Roll, Phase-Dash, Dual Reloads) + seamless Black Ops Neural-Glitch, Wukong Ink-Wash/Gold Dissolve, and Visor Scanline transitions.
Mobile Ergonomics (Locked Landscape, Safe-Area Insets, Locked 60 FPS): Left dynamic floating thumbstick + Quick-Spell/Transformation radial trigger (25% slow-mo flick); Right twin-stick aim/fire + Jump + Dash + Smart Bash/Grapple + Smart Melee/Stance/Finisher/Interact + Throwable arc; Top-right Reload/Swap/Focus/Medkit/NVG strip; HUD Customizer, Aim Assist toggle, Bluetooth Controller auto-switch, Input.vibrate_handheld() haptics, object pooling, 4 Quality Presets.
4-Stem Adaptive Audio: Crossfading stems (Covert Ambient → Tactical Combat → Mythic Boss → Escape Crescendo) + layered SFX & radio chatter.
5. Automated Cloud Android APK Workflow (.github/workflows/build-android-apk.yml)
Create a GitHub Actions workflow using ubuntu-latest that:

Installs Godot 4.3+ headless export templates, OpenJDK 17, and Android SDK command-line tools.
Runs python3 tools/asset_gen/generate_pbr_assets.py to generate all 4-map PBR textures.
Runs godot --headless --script res://tests/test_runner.gd to verify all 30 endings, Gunsmith math, physics, and zero-network-permission manifest compliance.
Exports builds/LumenWastes-BlackProtocol-Offline.apk via godot --headless --export-debug "Android" and uploads it as a downloadable GitHub Actions Artifact so the developer (Tarun Loganathan) can download and install the final 100% offline APK directly onto his Android phone from any browser.
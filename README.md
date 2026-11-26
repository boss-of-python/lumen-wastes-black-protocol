# LUMEN WASTES: BLACK PROTOCOL

A **100% offline, 20-hour 2D/2.5D side-scrolling physics action-shooter, strategic
covert-ops thriller, and mythic Metroidvania** for mobile, built with **Godot 4.3+
(GDScript)** and an automated **GitHub Actions APK build workflow**.

**Created, Directed & Developed by: Tarun Loganathan**

## Core Identity

- **100% Offline Runtime** — zero network permissions in the Android export
  (`export_presets.cfg` omits `INTERNET` and `ACCESS_NETWORK_STATE`). All AI,
  narrative, saves, and assets run locally on the phone CPU. No cloud, no ads,
  no telemetry.
- **Godot 4.3+** — 100% GDScript (`.gd`), text scenes (`.tscn`), resources
  (`.tres`), and GLSL shaders (`.gdshader`). No Godot 3 syntax.
- **30 Choice-Specific Endings** — resolved by the offline Narrative State
  Manager across 5 strategic layers and 18 crossroads.
- **Mandatory Developer Credits** — animated splash (`A GAME BY TARUN LOGANATHAN`),
  menu footer, and cinematic rolling end credits after every ending.

## Project Layout

```
.github/
  copilot-instructions.md          # Authoritative master spec
  workflows/
    build-android-apk.yml          # Automated Godot 4 Android APK builder
project.godot                      # Godot 4.3 Mobile Renderer, locked landscape
export_presets.cfg                 # Zero-network-permission Android & iOS presets
tools/
  asset_gen/generate_pbr_assets.py # Pillow+NumPy 4-map PBR generator
  validate_gdscript.py             # Offline static GDScript/scene validator
assets/
  manifest.json                    # Hot-swappable asset manifest
  pbr/                             # Generated _albedo/_normal/_specular/_emission maps
  portraits/, audio/               # Generated portraits & stem placeholders
shaders/                           # 7 GLSL shaders (PBR, god-rays, NVG, stasis, wipes...)
data/                              # weapons, shards, armor, enemies, endings, biomes
src/
  autoload/    # GameState, NarrativeStateManager, AudioDirector, TimeManager
  player/      # Player, CombatController, KineticBash, PlasmaGrapple, ArmoredATV
  physics/     # DestructibleProp, HangingGirder, ElementalGrid, BossRocket
  ai/          # FactionAgent (4-faction infighting), BossBase (multi-phase)
  ui/          # SplashScreen, MainMenu, MobileHUD, GunsmithUI, DecisionFlowchartUI, CreditsScreen
tests/
  test_runner.gd                   # Headless CI suite (30 endings, Gunsmith, physics, offline)
```

## Build the Android APK (GitHub Actions)

The workflow `.github/workflows/build-android-apk.yml` runs on every push and PR:

1. Installs Godot 4.3 headless, OpenJDK 17, and the Android SDK command-line tools.
2. Runs `python3 tools/asset_gen/generate_pbr_assets.py` to generate all 4-map PBR textures.
3. Runs `godot --headless --script res://tests/test_runner.gd` to verify all 30
   endings, Gunsmith math, physics, and zero-network-permission compliance.
4. Exports `build/LumenWastes-BlackProtocol-Offline.apk` via
   `godot --headless --export-debug "Android"`.
5. Uploads the APK as a downloadable GitHub Actions artifact (and to the release
   on tag pushes) so it can be installed directly onto an Android phone.

## Local Development

```bash
# 1. Generate PBR assets (requires Pillow + NumPy)
pip install Pillow numpy
python3 tools/asset_gen/generate_pbr_assets.py

# 2. Validate scripts/scenes offline
python3 tools/validate_gdscript.py

# 3. Open in Godot 4.3+ editor and run, or export:
godot --headless --export-debug "Android" build/LumenWastes-BlackProtocol-Offline.apk
```

## Verification

The headless test suite (`res://tests/test_runner.gd`) validates:

- **Offline manifest compliance** — no `INTERNET` / `ACCESS_NETWORK_STATE`.
- **30 Endings** — data completeness + narrative resolver (True Ending, NG+ secret, early extraction).
- **Gunsmith math** — 16 weapons, 7 attachment slots, 5 max equipped, verified baselines.
- **Physics constants** — gravity 1180, canvas_items stretch, mobile renderer, 60 Hz.
- **Data integrity** — shards, armor, factions, bosses, biomes.

---

Created, Directed & Developed by **Tarun Loganathan**.
100% Offline Mobile Edition • Powered by Godot 4.

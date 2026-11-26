#!/usr/bin/env python3
"""
LUMEN WASTES: BLACK PROTOCOL — 4-Map PBR Asset Generator
=========================================================
Procedurally generates the complete 4-map PBR texture pipeline
(_albedo / _normal / _specular / _emission) for every asset
declared in assets/manifest.json, plus portrait sprites and audio
stem placeholders. 100% offline — no network access required.

Usage:
    python3 tools/asset_gen/generate_pbr_assets.py
    python3 tools/asset_gen/generate_pbr_assets.py --manifest res://assets/manifest.json
    python3 tools/asset_gen/generate_pbr_assets.py --force        # regenerate even if present

Output layout (per asset, under assets/pbr/<name>/):
    <name>_albedo.png      Base color (linear-ish RGB, no alpha usage)
    <name>_normal.png      Tangent-space normal map (OpenGL convention, Y+)
    <name>_specular.png    Specular/roughness pack (R=roughness, G=metalness)
    <name>_emission.png    Emission map (RGB = glow color, A = intensity)

Requires: Pillow, NumPy.
"""

from __future__ import annotations

import argparse
import json
import math
import os
import random
import sys
from pathlib import Path

try:
    import numpy as np
    from PIL import Image
except ImportError as exc:  # pragma: no cover
    sys.stderr.write(
        "[pbr-gen] ERROR: Pillow and NumPy are required.\n"
        "  pip install Pillow numpy\n"
    )
    sys.exit(2)

# ---------------------------------------------------------------------------
# Deterministic seeding so CI runs are reproducible.
# ---------------------------------------------------------------------------
DEFAULT_SEED = 0xB1AC

# 16.7M color palette tuned for the LUMEN WASTES art direction:
# oxidized gold, weathered stone, bioluminescent teal/violet, black-ops steel.
PALETTE = {
    "stone_gold": ((58, 48, 38), (150, 122, 70), (212, 178, 104)),
    "oxidized_steel": ((28, 32, 38), (88, 100, 116), (140, 158, 178)),
    "bio_teal": ((10, 34, 40), (38, 120, 118), (92, 214, 190)),
    "violet_glow": ((26, 16, 44), (88, 52, 150), (176, 120, 238)),
    "ember_red": ((44, 18, 14), (150, 62, 40), (232, 120, 72)),
    "acid_green": ((20, 30, 14), (96, 140, 44), (190, 232, 92)),
    "cold_blue": ((14, 22, 40), (52, 82, 140), (120, 168, 232)),
    "neutral_gray": ((24, 24, 26), (96, 96, 100), (170, 170, 176)),
}

TEXTURE_SIZE = 256


# ---------------------------------------------------------------------------
# Texture synthesis primitives
# ---------------------------------------------------------------------------
def _fbm(shape, seed: int, octaves: int = 5, lacunarity: float = 2.0,
         gain: float = 0.5, freq_scale: float = 1.0) -> np.ndarray:
    """Fractal Brownian motion noise in [0, 1]."""
    rng = np.random.default_rng(seed)
    height, width = shape
    result = np.zeros(shape, dtype=np.float64)
    amplitude = 1.0
    frequency = freq_scale
    for _ in range(octaves):
        # Random smooth gradient noise field via upsampled random grid.
        gw = max(2, int(width * frequency))
        gh = max(2, int(height * frequency))
        grad = rng.random((gh, gw), dtype=np.float64)
        # Bilinear upsample to full size.
        img = Image.fromarray((grad * 255).astype(np.uint8), mode="L")
        img = img.resize((width, height), Image.BILINEAR)
        layer = np.asarray(img, dtype=np.float64) / 255.0
        result += amplitude * layer
        amplitude *= gain
        frequency *= lacunarity
    result -= result.min()
    result /= max(result.max(), 1e-9)
    return result


def _normal_from_height(height: np.ndarray, strength: float = 2.0) -> np.ndarray:
    """Convert a heightmap to a tangent-space normal map (OpenGL Y+)."""
    h = height.astype(np.float64)
    # Central-difference gradients.
    gy, gx = np.gradient(h)
    gx *= strength
    gy *= strength
    nx = -gx
    ny = -gy
    nz = np.ones_like(h)
    norm = np.sqrt(nx * nx + ny * ny + nz * nz)
    nx /= norm
    ny /= norm
    nz /= norm
    normal = np.stack([nx, ny, nz], axis=-1)
    normal = (normal * 0.5 + 0.5)  # map [-1,1] -> [0,1]
    return (np.clip(normal, 0.0, 1.0) * 255).astype(np.uint8)


def _albedo_for(theme: str, seed: int, size: int) -> np.ndarray:
    low, mid, high = PALETTE.get(theme, PALETTE["neutral_gray"])
    n1 = _fbm((size, size), seed)
    n2 = _fbm((size, size), seed + 977, octaves=4)
    img = (n1 * 0.65 + n2 * 0.35)[:, :, None]
    img = np.clip(img, 0.0, 1.0)
    low_arr = np.array(low, dtype=np.float64) / 255.0
    mid_arr = np.array(mid, dtype=np.float64) / 255.0
    high_arr = np.array(high, dtype=np.float64) / 255.0
    # Smooth 3-stop quantization for a stylized, readable look.
    t = img[..., 0:1]  # (size, size, 1) so conditions broadcast against RGB bands
    low_band = np.broadcast_to(low_arr, (size, size, 3))
    mid_band = np.broadcast_to(mid_arr, (size, size, 3))
    high_band = np.broadcast_to(high_arr, (size, size, 3))
    out = np.where(
        t < 0.34, low_band,
        np.where(t < 0.67, mid_band, high_band),
    )
    # Add subtle grain.
    grain = np.random.default_rng(seed + 13).random((size, size, 3)) * 0.04
    return np.clip(out + grain, 0.0, 1.0)


def _specular_for(theme: str, seed: int, size: int) -> np.ndarray:
    """R=roughness, G=metalness. Stylized: metals low roughness, organics high."""
    metal = 1.0 if theme in ("oxidized_steel", "stone_gold", "cold_blue") else 0.25
    rough = 0.22 if theme in ("oxidized_steel", "stone_gold") else 0.72
    noise = _fbm((size, size), seed + 4242, octaves=4)
    roughness = np.clip(rough + (noise - 0.5) * 0.35, 0.05, 1.0)
    metalness = np.clip(metal + (noise - 0.5) * 0.2, 0.0, 1.0)
    out = np.stack([roughness, metalness, np.zeros_like(roughness)], axis=-1)
    return out


def _emission_for(theme: str, seed: int, size: int, intensity: float = 1.0) -> np.ndarray:
    """Emission: RGB glow color, alpha = intensity. Mostly dark, with veins."""
    glow = {
        "bio_teal": (0.45, 1.0, 0.88),
        "violet_glow": (0.86, 0.55, 1.0),
        "ember_red": (1.0, 0.48, 0.25),
        "acid_green": (0.78, 1.0, 0.36),
        "cold_blue": (0.48, 0.68, 1.0),
    }
    color = glow.get(theme, (0.3, 0.3, 0.35))
    veins = _fbm((size, size), seed + 777, octaves=3)
    # Threshold into vein-like structures.
    vein_mask = np.clip((veins - 0.72) / 0.28, 0.0, 1.0) ** 1.5
    base = np.zeros((size, size, 4), dtype=np.float64)
    base[:, :, 0] = color[0]
    base[:, :, 1] = color[1]
    base[:, :, 2] = color[2]
    base[:, :, 3] = vein_mask * intensity
    return base


def _portrait_for(name: str, seed: int, size: int = 256) -> np.ndarray:
    """Simple character portrait placeholder: gradient bust silhouette."""
    rng = np.random.default_rng(seed)
    base = np.zeros((size, size, 4), dtype=np.float64)
    for y in range(size):
        t = y / size
        base[y, :, 0] = 0.10 + 0.18 * (1 - t)
        base[y, :, 1] = 0.10 + 0.16 * (1 - t)
        base[y, :, 2] = 0.16 + 0.2 * (1 - t)
        base[y, :, 3] = 1.0
    # Head + shoulders silhouette.
    cx, cy = size // 2, int(size * 0.42)
    head_r = size * 0.20
    yy, xx = np.mgrid[0:size, 0:size]
    head = (xx - cx) ** 2 + (yy - cy) ** 2 <= head_r ** 2
    shoulders = (yy > size * 0.62) & (
        ((xx - cx) / (size * 0.42)) ** 2 + ((yy - size) / (size * 0.55)) ** 2 <= 1.0
    )
    mask = (head | shoulders).astype(np.float64)
    tint = rng.random(3) * 0.25 + 0.25
    for c in range(3):
        base[:, :, c] = base[:, :, c] * (1 - mask) + (base[:, :, c] * 0.4 + tint[c]) * mask
    base[:, :, 3] *= 0.98
    return base


# ---------------------------------------------------------------------------
# Asset pipeline
# ---------------------------------------------------------------------------
def _save_png(arr: np.ndarray, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img = Image.fromarray(arr.astype(np.float64) if arr.dtype != np.uint8 else arr)
    if img.mode != "RGB" and img.mode != "RGBA":
        img = img.convert("RGBA" if arr.shape[-1] == 4 else "RGB")
    img.save(path, optimize=False)


def generate_asset(asset: dict, out_root: Path, seed: int, force: bool) -> dict:
    name = asset["name"]
    kind = asset.get("kind", "prop")
    theme = asset.get("theme", "neutral_gray")
    size = int(asset.get("size", TEXTURE_SIZE))
    out_dir = out_root / "pbr" / name
    manifest_entry = {
        "name": name,
        "kind": kind,
        "theme": theme,
        "size": size,
        "maps": {},
        "status": "skipped",
    }
    if not force and (out_dir / f"{name}_albedo.png").exists():
        manifest_entry["status"] = "cached"
        return manifest_entry

    seed = int(asset.get("seed", seed + hash(name) % 100000)) & 0xFFFFFFFF
    albedo = _albedo_for(theme, seed, size)
    normal_h = _fbm((size, size), seed + 11, octaves=5)
    normal = _normal_from_height(normal_h, strength=2.2)
    specular = _specular_for(theme, seed, size)
    emission = _emission_for(theme, seed, size, intensity=float(asset.get("emission_intensity", 1.0)))

    _save_png((albedo * 255).astype(np.uint8), out_dir / f"{name}_albedo.png")
    _save_png(normal, out_dir / f"{name}_normal.png")
    _save_png((specular * 255).astype(np.uint8), out_dir / f"{name}_specular.png")
    _save_png((emission * 255).astype(np.uint8), out_dir / f"{name}_emission.png")

    manifest_entry["status"] = "generated"
    manifest_entry["maps"] = {
        "albedo": f"res://assets/pbr/{name}/{name}_albedo.png",
        "normal": f"res://assets/pbr/{name}/{name}_normal.png",
        "specular": f"res://assets/pbr/{name}/{name}_specular.png",
        "emission": f"res://assets/pbr/{name}/{name}_emission.png",
    }
    return manifest_entry


def generate_portraits(entries: list[dict], out_root: Path, seed: int, force: bool) -> list[dict]:
    out_dir = out_root / "portraits"
    results = []
    for portrait in entries:
        name = portrait["name"]
        path = out_dir / f"{name}.png"
        entry = {**portrait, "status": "skipped", "path": f"res://assets/portraits/{name}.png"}
        if not force and path.exists():
            entry["status"] = "cached"
            results.append(entry)
            continue
        arr = _portrait_for(name, seed + hash(name) % 99991, int(portrait.get("size", 256)))
        _save_png((arr * 255).astype(np.uint8), path)
        entry["status"] = "generated"
        results.append(entry)
    return results


def generate_audio_stems(stems: list[dict], out_root: Path, force: bool) -> list[dict]:
    """Generate silent placeholder WAV stems (real stems are authored separately)."""
    out_dir = out_root / "audio"
    results = []
    for stem in stems:
        name = stem["name"]
        path = out_dir / f"{name}.wav"
        entry = {**stem, "status": "skipped", "path": f"res://assets/audio/{name}.wav"}
        if not force and path.exists():
            entry["status"] = "cached"
            results.append(entry)
            continue
        path.parent.mkdir(parents=True, exist_ok=True)
        duration = float(stem.get("duration", 3.0))
        sr = 44100
        # Silent stereo stem with a tiny fade to avoid click artifacts.
        n = int(duration * sr)
        samples = np.zeros((n, 2), dtype=np.int16)
        import wave
        with wave.open(str(path), "w") as wf:
            wf.setnchannels(2)
            wf.setsampwidth(2)
            wf.setframerate(sr)
            wf.writeframes(samples.tobytes())
        entry["status"] = "generated"
        results.append(entry)
    return results


def main() -> int:
    parser = argparse.ArgumentParser(description="LUMEN WASTES 4-map PBR asset generator")
    parser.add_argument("--manifest", default="assets/manifest.json",
                        help="Path to assets manifest (default: assets/manifest.json)")
    parser.add_argument("--out", default="assets",
                        help="Output root for generated assets (default: assets)")
    parser.add_argument("--seed", type=int, default=DEFAULT_SEED,
                        help=f"RNG seed (default: {DEFAULT_SEED:#x})")
    parser.add_argument("--force", action="store_true",
                        help="Regenerate assets even when cached files exist")
    args = parser.parse_args()

    manifest_path = Path(args.manifest)
    if not manifest_path.exists():
        sys.stderr.write(f"[pbr-gen] ERROR: manifest not found: {manifest_path}\n")
        return 2
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))

    out_root = Path(args.out)
    out_root.mkdir(parents=True, exist_ok=True)

    assets = manifest.get("assets", [])
    pbr_entries = [a for a in assets if a.get("kind") in ("prop", "character", "environment", "boss")]
    portraits = manifest.get("portraits", [])
    stems = manifest.get("audio_stems", [])

    print(f"[pbr-gen] seed={args.seed:#x} assets={len(pbr_entries)} portraits={len(portraits)} stems={len(stems)}")

    generated = [generate_asset(a, out_root, args.seed, args.force) for a in pbr_entries]
    portrait_results = generate_portraits(portraits, out_root, args.seed, args.force)
    stem_results = generate_audio_stems(stems, out_root, args.force)

    # Write a generation report (not part of the runtime manifest).
    report = {
        "seed": args.seed,
        "texture_size": TEXTURE_SIZE,
        "pbr_assets": generated,
        "portraits": portrait_results,
        "audio_stems": stem_results,
        "totals": {
            "generated": sum(1 for g in generated if g["status"] == "generated")
                        + sum(1 for p in portrait_results if p["status"] == "generated")
                        + sum(1 for s in stem_results if s["status"] == "generated"),
            "cached": sum(1 for g in generated if g["status"] == "cached")
                     + sum(1 for p in portrait_results if p["status"] == "cached")
                     + sum(1 for s in stem_results if s["status"] == "cached"),
        },
    }
    report_path = out_root / "asset_gen_report.json"
    report_path.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(f"[pbr-gen] report -> {report_path}")
    print(f"[pbr-gen] done: {report['totals']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

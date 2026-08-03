# Standalone MCL Signs (`mod_mcl_signs`)

- [Japanese Documentation (README.md)](./README.md)
- [ORIGINAL REAMDE.md (README.upstream.md)](./README.upstream.md)

A data-driven, standalone, lightweight signs mod for **Luanti** (formerly Minetest). This mod extracts the feature-rich sign mechanics from **Mineclonia** (VoxeLibre) and expands them into a fully dynamic, multi-game compatible solution.

All dependencies on Mineclonia's core APIs (`mcl_core`, `mcl_worlds`, etc.) have been removed. It dynamically adapts to the host game environment upon launch.

## ✨ Features

- **2 Material Variants**: Streamlined into **Wood** and **Iron** to match Minetest Game specifications.
- **Multi-Game Adaptability**: Uses a data-driven JSON architecture. Automatically detects the running Game ID (`minetest`, `voxellibre`, etc.) and loads its corresponding configuration file.
- **Dynamic Placement**: Smartly switches between **Standing Signs** and **Wall Signs** depending on where you place them.
- **Hanging Signs**: Can be placed on the ceilings or walls of air-suspended blocks (fixes the vanilla issue where signs cannot be placed next to air).
- **Pixel-Perfect Text Rendering**: Bundled with the original high-compatibility UTF-8 text processing library for perfect text alignment and formatting.
- **Localization**: Full support for both **English** and **Japanese** languages out of the box via Luanti's translation system. (excluding player-written text on signs)

## 🛠️ Installation

1. Download this repository as a ZIP file or clone it using git.
2. Extract/move the folder into your Luanti `mods/` directory.
3. Rename the folder to exactly `mod_mcl_signs`.
4. Enable the mod in your world configuration menu.

## 📦 Dynamic Loadouts & Recipes

Depending on your running game, the configuration will fall back or switch between item profiles:

- **Minetest Game (`minetest.json`)**: Streamlined into standard **Wood** and **Iron** using vanilla resources (`default:wood`, `default:steel_ingot`).
- **VoxeLibre(MineClone2) (`mineclone2.json`)**: Expands into **11 authentic types** (Oak, Spruce, Birch, Jungle, Acacia, Dark Oak, Mangrove, Cherry, Bamboo, Crimson, Warped) using accurate game-specific nodes and craft recipes.

## 📂 Folder Structure

```text
mod_mcl_signs/
├─ games/             # JSON data files per Game ID (minetest.json, mineclone2.json)
├─ locale/            # English & Japanese translation files (PO/POT)
├─ models/            # Original 3D mesh models (.obj)
├─ textures/          # Textures for wood/iron signs and custom fonts
├─ init.lua           # Optimized standalone mod script
├─ mod.conf           # Mod configuration (depends on `default`)
├─ utf8.lua           # Bundled UTF-8 text processing helper
├─ README.upstream.md # Original README.md
├─ README.en.md       # This file (English Translate)
└─ README.md          # This file
```

## 💻 Supported Environments

- **Minimum Requirement**: **Luanti v5.4.0 or later** (Required for core Game ID detection APIs).
- **Recommended Requirement**: **Luanti v5.15.2 or later** (Highly recommended for optimal engine performance and patch-level security updates).

## ⚖️ License

Since this mod is derived from Mineclonia/VoxeLibre, it inherits the same open-source licenses:

**Code:** MIT
* `utf8.lua` is from `modlib`, by Lars Mueller alias LMD or appguru(eu) [(source)](https://github.com/appgurueu/modlib/blob/master/utf8.lua)
* See `LICENSE` file for details

**Font:** CC0
* Originally by PilzAdam (WTFPL)
* Modified and massively extended by rudzik8
* Can be found in the `/textures` sub-directory of game root, prefixed with `_`
* See <https://creativecommons.org/publicdomain/zero/1.0/> for details

**Models:** GPLv3
* by 22i: <https://github.com/22i/amc>
* See <https://www.gnu.org/licenses/gpl-3.0.html> for details

**AI-generated**: This package contains AI-generated assets or code

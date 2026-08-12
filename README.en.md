# Standalone & Data-Driven mcl Signs (`mod_mcl_signs`)

- [Japanese Documentation (README.md)](./README.md)
- [ORIGINAL REAMDE.md (README.upstream.md)](./README.upstream.md)

A standalone, data-driven signs mod for **Luanti** (formerly Minetest). Extracted from the robust sign mechanisms of **Mineclonia**, this mod has been heavily extended and refactored to achieve seamless compatibility across multiple game environments.

All hard dependencies on Mineclonia's core APIs have been completely removed. Upon server launch, the mod automatically detects the running game environment and dynamically loads the optimal configuration.

This mod utilizes a font-atlas rendering method for text image generation.

## ✨ Features

- **Consolidated Material Variations**: Smartly unifies sign variations into **"Wood"** and **"Iron"** when running under Minetest Game specifications.
- **Dynamic Multi-Game Adaptation**: Built on a data-driven JSON architecture. It leverages `core.get_game_info()` to automatically detect the Game ID (`minetest`, `voxellibre`, etc.) and dynamically loads the corresponding configuration file.
- **Smart Attachment Switching**: Automatically switches between a **standing sign** and a **wall-mounted sign** depending on where it is placed (floor vs. wall), unifying the inventory item into a single sleek stack.
- **Mid-Air Hanging Signs**: Can be reliably placed on the side or bottom of floating blocks, fixing the vanilla bug where placing signs next to air blocks was blocked.
- **Beautiful Text Rendering**: Embeds a highly compatible internal UTF-8 text processing library (`utf8.lua`) originating from Mineclonia, preventing text clipping, misalignment, and character corruption.
- **Advanced I18n**: Fully compatible with Luanti's native translation system, offering out-of-the-box support for both **English** and **Japanese** (excluding player-written text on signs).

~~## ⚙️ Initial Configuration~~

~~1. Execute the bundled `mcl_sign_to_atlas.py` script beforehand to generate your font-atlas texture image.~~

~~Note: Characters beyond Unicode U+0500 are not included. You will need to convert and merge the fonts.~~

## 🚀 Installation

1. Download this repository as a `.ZIP` file or clone it using git.
2. Move the extracted folder into your Luanti `mods/` directory.
3. Ensure the folder name is strictly renamed to **`mod_mcl_signs`**.
4. Enable the mod in your world configuration menu.

## 🔧 Post-Installation Setup

1. Navigate to Luanti's `Settings` -> `Content` -> `Mods` -> `Standalone mcl Signs`. You can switch atlas textures and finely adjust text display coordinates here.

## 📦 Game Configurations & Crafting Recipes

The recipes and inventory profiles adapt dynamically based on the launched game environment:

- **Minetest Game (`minetest.json`)**: Condensed into basic "Wood" and "Iron" recipes to align with standard criteria (utilizes `default:wood` and `default:steel_ingot`).
- **VoxeLibre / MineClone2 (`mineclone2.json`)**: Expanded into **11 unique wood variations** from Oak to Warped. It purges the glitchy vanilla legacy sign recipes and safely overwrites them with this newly fixed standalone system.

## 📂 Folder Structure

```text
mod_mcl_signs/
├─ games/               # Game-specific configuration JSONs (minetest.json, mineclone2.json)
├─ locale/              # English and Japanese translation files (PO/POT)
├─ models/              # Original 3D mesh assets (.obj)
├─ textures/            # Textures for wood/iron signs and custom font sheets
├─ font_pipeline.lua    # Font Atlas Engine
├─ init.lua             # Refactored, high-performance main script
├─ mod.conf             # Mod configuration file (depends on `default` if available)
├─ settingtypes.txt     # In-game configurable setting schema
├─ utf8.lua             # Internal unique UTF-8 text helper
~~├─ mcl_sign_to_atlas.py # Python script for converting font sheets into Atlas textures~~
├─ README.upstream.md   # The original base upstream README
├─ README.en.md         # This file
└─ README.md            # Japanese documentation
```

## 💻 Supported Environments

- **Minimum Requirement**: **Luanti v5.4.0 or later** (Required for core Game ID detection APIs).
- **Recommended Requirement**: **Luanti v5.15.2 or later** (Highly recommended for optimal engine performance and patch-level security updates).

## 📄 License

Since this mod is built upon the collective works of Mineclonia and VoxeLibre, it inherits their respective open-source licensing:

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

**AI Generation**: This package contains assets or source code code generated by AI.

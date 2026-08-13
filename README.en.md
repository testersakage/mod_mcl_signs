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

## 🚀 Installation

1. Download this repository as a `.ZIP` file or clone it using git.
2. Move the extracted folder into your Luanti `mods/` directory.
3. Ensure the folder name is strictly renamed to **`mod_mcl_signs`**.
4. Enable the mod in your world configuration menu.

## 🛠️ Preparing the Atlas Textures
An atlas image profile is required if you want to display characters beyond U+0500 (such as Japanese) or if you prefer not to use the default `mcl_signs` font sheets.
The supported font size is strictly locked to a monospaced **12x12px**, which perfectly matches the scaling of the standard `mcl_signs` specifications.

1. Generate a complete set of 256 atlas page images (`00` to `FF`) with a grid size of **16x16 characters** (each character slot being **12x12px**) using my [fonttools](https://github.com/testersakage/fonttools) repository or an equivalent conversion utility.
2. Place the generated image files directly inside the `mod_mcl_signs/textures/` directory.
3. Refer to the configuration section below, enter your file naming convention into the **Main Atlas Filename Pattern** field, and click the "Apply" button.
4. To utilize the font fallback pipeline, generate an integration TSV file that lists all valid font characters inside your main atlas, and place it directly under the `mod_mcl_signs/` root directory.
5. Configure the **Main Atlas Registry TSV Name** and **Fallback Sub-Atlas Pattern** fields, then click the "Apply" button.

## 🔧 Post-Installation Setup

Navigate to Luanti's **Settings -> Content -> Mods -> Standalone mcl Signs** to switch atlas profiles and finely adjust the textual display coordinates.

- **Enable Legacy Compatibility Mode (`mcl_signs_char_image_file`)**:
  Mimics the exact rendering logic of the original `mcl_signs`. Characters up to `U+04FF` will be rendered using the discrete character images inside the `textures/` root directory.
- **Main Atlas Filename Pattern (`mcl_signs_main_atlas_pattern`)**:
  Specifies the file naming convention for your primary font atlases. The `%02x` or `%02X` wildcards will be dynamically replaced by the hex page numbers.
- **Main Atlas Registry TSV Name (`mcl_signs_main_atlas_list`)**:
  Specifies the filename of the integration TSV that registers all "existing characters" in your primary font. If this field is left blank or the file is missing, the system will automatically route all character queries strictly to the Main Atlas.
- **Fallback Sub-Atlas Pattern (`mcl_signs_sub_atlas_pattern`)**:
  Specifies the file naming convention for your secondary (fallback) font atlases. If this field is left blank or the specified files are missing, the TSV configurations will be ignored, and the system will fall back entirely to the Main Atlas.
- **UAX #11 Ambiguous is Wide (`mcl_signs_uax11_wide`)**:
  Treats Greek and Cyrillic ambiguous characters uniformly as full-width (12px) text layouts.
- **Global Text Vertical Offset (`mcl_signs_y_offset`)**:
  Finely adjusts the vertical rendering offset (Y-axis) for all text on the signboards.
- **Global Text Horizontal Padding (`mcl_signs_center_padding`)**:
  Finely adjusts the horizontal rendering padding (X-axis) for all text on the signboards.
- **Proportional Font Mode (`mcl_signs_propotional`)**:
  Enables character-specific width adjustments mapped from `characters.tsv`. *(Under Development / Unimplemented)*

## 📦 Game Configurations & Crafting Recipes

The recipes and inventory profiles adapt dynamically based on the launched game environment:

- **Minetest Game (`minetest.json`)**: Condensed into basic "Wood" and "Iron" recipes to align with standard criteria (utilizes `default:wood` and `default:steel_ingot`).
- **VoxeLibre / MineClone2 (`mineclone2.json`)**: Expanded into **11 unique wood variations** from Oak to Warped. It purges the glitchy vanilla legacy sign recipes and safely overwrites them with this newly fixed standalone system.

## 📂 Folder Structure

```text
mod_mcl_signs/
├─ games/              # Game-specific configuration JSONs (minetest.json, mineclone2.json)
├─ locale/             # English and Japanese translation files (PO/POT)
├─ models/             # Original 3D mesh assets (.obj)
├─ textures/           # Textures for wood/iron signs and custom font sheets
├─ atlas_sample.tsv    # Sample .tsv file
├─ font_pipeline.lua   # Font Atlas Engine
├─ init.lua            # Refactored, high-performance main script
├─ mod.conf            # Mod configuration file (depends on `default` if available)
├─ settingtypes.txt    # In-game configurable setting schema
├─ utf8.lua            # Internal unique UTF-8 text helper
├─ README.upstream.md  # The original base upstream README
├─ README.en.md        # This file
└─ README.md           # Japanese documentation
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

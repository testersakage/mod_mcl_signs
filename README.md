# 独立・データ駆動型 MCL 看板MOD (`mod_mcl_signs`)

- [English Documentation (README.en.md)](./README.en.md)
- [ORIGINAL REAMDE.md (README.upstream.md)](./README.upstream.md)

**Luanti**（旧Minetest）向けの、単体で動作するデータ駆動型の看板MODです。**Mineclonia** の優れた看板メカニズムをベースに抽出し、複数のゲーム環境へ柔軟に対応できるように大幅な拡張を施しています。

MinecloniaのコアAPIへの依存関係は完全に排除されており、起動時に実行中のゲームを自動判別して最適な設定を読み込みます。

文字画像生成にフォントアトラス方式を採用

## 主な機能

- **2種類の素材バリエーション**: Minetest Gameの仕様に合わせて、**「木」**と**「鉄」**の2種類にスマートに統合。
- **複数ゲームへの自動適応**: JSONベースのデータ駆動アーキテクチャを採用。`core.get_game_info()` を用いて Game ID（`minetest`、`voxellibre` など）を自動検出し、対応する設定ファイルを動的にロードします。
- **スマートな設置切り替え**: 看板を設置する場所（上面または側面）に応じて、**立て看板**と**壁掛け看板**が自動的に切り替わります（手持ちアイテムは1種類に統一）。
- **空中の吊り下げ看板**: 空中に浮いているブロックの側面や下面にも確実に設置可能（真下が空気ブロックだと設置できないバニラの不具合を解消）。
- **美しい文字レンダリング**: Mineclonia固有の高互換性UTF-8テキスト処理ライブラリ（`utf8.lua`）を内蔵し、文字のズレや文字化けを防止。
- **他言語対応**: Luantiの標準翻訳システムに対応し、**日本語**と**英語**に完全対応。（プレイヤーが看板に書いた文字を除く）

## 初期設定

1. 同梱の mcl_sign_to_atlas.py を実行してAtlas画像を生成してください。

※unicode U+0500 以降の文字は含まれていません。フォントを変換・結合する必要があります。

## 導入方法

1. このリポジトリをZIP形式でダウンロードするか、gitを使用してクローンします。
2. 展開したフォルダを、Luantiの `mods/` ディレクトリに移動します。
3. フォルダ名を正確に **`mod_mcl_signs`** に変更します。
4. ワールドの設定画面からMODを**有効**にします。

## 導入後の設定

1. Luantiの［設定］->［コンテンツ：MOD］［Standalone MCL Signs］でAtlas画像の切り替えと表示位置の微調整が可能です。

## 各ゲームの構成とクラフト

起動したゲームの環境に応じて、インベントリの内容とレシピが自動で切り替わります：

- **Minetest Game時 (`minetest.json`)**: 標準仕様に合わせ「木」と「鉄」の2種類に集約（`default:wood`, `default:steel_ingot` を使用）。
- **VoxeLibre(MineClone2)時 (`mineclone2.json`)**: オークから歪んだ木まで**全11種類のバリエーション**へ拡張。元の古い看板のレシピを削除し、バグの直ったこの新看板へ完全に置き換えます。

## フォルダ構成

```text
mod_mcl_signs/
├─ games/               # ゲームごとの設定JSONを格納 (minetest.json, mineclone2.json)
├─ locale/              # 英語および日本語の翻訳ファイル (PO/POT)
├─ models/              # オリジナルの3Dメッシュモデル (.obj)
├─ textures/            # 木/鉄の看板用テクスチャおよびカスタムフォント画像
├─ init.lua             # 独立化・最適化済みのメインスクリプト
├─ mod.conf             # MOD設定ファイル (`default` MODに依存)
├─ settingtypes.txt     # 動作設定ファイル (Luantiの設定から変更可能)
├─ utf8.lua             # 内蔵された独自UTF-8テキスト処理ヘルパー
├─ mcl_sign_to_atlas.py # 文字画像からAtlas画像を生成するPythonスクリプト
├─ README.upstream.md   # オリジナルのREADME.md
├─ README.en.md         # このファイルの英語訳
└─ README.md            # このファイル
```

## 動作環境

- **最低環境**: **Luanti v5.4.0 以上** (`core.get_game_info()` による自動Game ID判定APIを使用しているため必須)。
- **推奨環境**: **Luanti v5.15.2 以上** (エンジンの最適化および、重要なセキュリティ対策パッチが適用されているため推奨)。

## ライセンス

このMODはMineclonia / VoxeLibreの成果物をベースにしているため、元のオープンソースライセンスを継承します：

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

**AI生成**:このパッケージにはAI生成のアセットまたはコードが含まれています

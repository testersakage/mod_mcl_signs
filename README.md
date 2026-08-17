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

## 導入方法

1. このリポジトリをZIP形式でダウンロードするか、gitを使用してクローンします。
2. 展開したフォルダを、Luantiの `mods/` ディレクトリに移動します。
3. フォルダ名を正確に **`mod_mcl_signs`** に変更します。
4. ワールドの設定画面からMODを**有効**にします。

## アトラス画像の準備
U+0500以降の文字を表示したい、あるいはmcl_signsのフォントを使いたくない場合はアトラス画像が必要です。
対応しているフォントサイズは固定幅の12x12pxのみです。これはmcl_signsの標準フォントに合わせたサイズです。

1. 拙作[fonttools](https://github.com/testersakage/fonttools)あるいは同等の変換プログラムを利用して 1文字12x12px 16x16文字で1ページのAtlas画像256枚(00~FF)を生成してください。
2. 生成したファイル群を mod_mcl_signs/textures/ 下に配置してください。
3. 以下を参照して**Main Atlas Filename Pattern**にファイル名規則を入力して「適用」ボタンを押してください。
4. フォールバックを利用する場合はメインアトラスの文字情報をリスト化したTSVファイルを mod_mcl_signs に配置してください。
5. **Main Atlas Registry TSV Name**と**Fallback Sub-Atlas Pattern**を設定して「適用」ボタンを押してください。

## 導入後の設定

Luantiの［設定］->［コンテンツ：MOD］［Standalone MCL Signs］でAtlas画像の切り替えと表示位置の微調整が可能です。
- **Enable Legacy Compatibility Mode**: オリジナルのmcl_signsと同等の処理を行います。 U+04FF までの文字が texturs/ の文字画像で表示されます。
- **Main Atlas Filename Pattern**: メインフォントアトラスのファイル名規則を記述します。 %02xおよび%02Xはページ番号に置換されます。
- **Main Atlas Registry TSV Name**: メインフォントに「実在する文字」を記録した統合TSVのファイル名を記述します。無指定および間違えた場合は、メインアトラスを参照します。
- **Fallback Sub-Atlas Pattern**: サブフォントアトラスのファイル名規則を記述します。無指定および間違えた場合はTSVファイルの設定が無効になり、メインアトラスを参照します。
- **UAX #11 Ambiguous is Wide**: ギリシャ・キリル文字の扱いを全角にします。
- **Global Text Vertical Offset**: 看板全体の表示位置（縦方向）を微調整します。
- **Global Text Horizontal Padding**: 看板全体の表示位置（横方向）を微調整します。
- **Propotional Font Mode**: characters.tsvの文字幅を有効にします。（未実装）

## 各ゲーム環境への適応とクラフトレシピ

起動したゲーム環境を自動で検知し、インベントリの内容とクラフトレシピが以下のように動的に切り替わります。

- **VoxeLibre / MineClone2 環境時 (`mineclone2.json`)**: 
  オークから歪んだ木まで、**全11種類のバリエーション**へ看板を拡張します。元の古い看板のレシピを自動で消去し、バグの修正されたこの新しい看板システムへと完全に置き換えます。
- **Mineclonia 環境時 (`mineclonia.json`)**: 
  ゲーム本体側との競合（二重登録）を防ぐため、本MOD側からはレシピの重複登録を行いませんが、新規及び設置済みの看板は本modの処理に置き換わります。
- **上記以外の環境 ＆ Minetest Game 環境時 (`minetest.json`)**: 
  標準の仕様に合わせ、「木」と「鉄」の2種類のみに素材を集約します（`default:wood`、`default:steel_ingot` を使用）。

### 💡 独自ゲームへの対応と拡張方法
お使いの環境に合わせて独自に看板の種類やレシピを追加したい場合は、`games/` フォルダ内にある各JSONファイルを参考にして、新しい定義ファイルを追加してください。

クラフトレシピを構築する際、必要なアイテムの正確なItemID（内部ネーム）がわからない場合は、[Recipe_Maker](https://github.com/testersakage/recipe_maker) で調査してください。

## フォルダ構成

```text
mod_mcl_signs/
├─ games/              # ゲームごとの設定JSONを格納 (minetest.json, mineclone2.json)
├─ locale/             # 英語および日本語の翻訳ファイル (PO/POT)
├─ models/             # オリジナルの3Dメッシュモデル (.obj)
├─ textures/           # 木/鉄の看板用テクスチャおよびカスタムフォント画像
├─ atlas_sample.tsv    # tsvファイルのサンプル
├─ font_pipeline.lua   # フォントアトラスエンジン
├─ init.lua            # 独立化・最適化済みのメインスクリプト
├─ mod.conf            # MOD設定ファイル (`default` MODに依存)
├─ settingtypes.txt    # 動作設定ファイル (Luantiの設定から変更可能)
├─ utf8.lua            # 内蔵された独自UTF-8テキスト処理ヘルパー
├─ README.upstream.md  # オリジナルのREADME.md
├─ README.en.md        # このファイルの英語訳
└─ README.md           # このファイル
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

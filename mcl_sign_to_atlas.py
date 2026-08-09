#!/usr/bin/env python3
import os
import sys
from PIL import Image

def load_characters_csv(csv_path):
    """
    characters.csv を解析し、{ コードポイント: 画像ファイル名 } の辞書を返す
    """
    mapping = {}
    if not os.path.exists(csv_path):
        print(f"[!] Error: 設定ファイル '{csv_path}' が見つかりません。")
        return mapping

    with open(csv_path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\r\n")
            if not line:
                continue
            
            # タブ区切りで分解
            parts = line.split("\t")
            if len(parts) < 2:
                # タブでない場合のフォールバック（スペース区切り）
                parts = [p for p in line.split(" ") if p]
                if len(parts) < 2:
                    continue

            char_str = parts[0]
            img_id = parts[1].strip()

            if len(char_str) == 1:
                mapping[ord(char_str)] = img_id
            elif char_str == "" and line.startswith("\t"):
                # タブ文字自体が定義されている特殊ケースの救済
                mapping[9] = img_id

    print(f" [*] CSVの解析に成功しました。登録文字数: {len(mapping)} 文字")
    return mapping

def build_mcl_sign_atlas(csv_path, src_dir, out_dir):
    print("="*60)
    print(" Mineclonia Sign Atlas Factory (Pure Left-Align Model) ")
    print("="*60)
    print(f" [CSV] Metrics File    : {csv_path}")
    print(f" [Src] Textures Folder : {src_dir}")
    print(f" [Out] Output Folder   : {out_dir}")
    print("-" * 60)

    # 1. CSVから「文字名 ➔ コードポイント」の翻訳マップを生成
    csv_map = load_characters_csv(csv_path)
    if not csv_map:
        return

    if not os.path.exists(src_dir):
        print(f"[!] Error: 看板画像フォルダ '{src_dir}' が見つかりません。")
        return

    os.makedirs(out_dir, exist_ok=True)

    # 1マス12x12px（16x16グリッド ➔ 192x192px）の固定幅仕様
    cell_w = 12
    cell_h = 12
    columns = 16
    rows = 16
    atlas_w = columns * cell_w
    atlas_h = rows * cell_h

    success_count = 0

    # 2. 0x00 から 0xFF までの全256ページを完全出力（欠番なし）
    for page in range(256):
        start_code = page * 256
        page_hex = f"{page:02X}"
        
        # アルファチャンネル付き完全透明キャンバス
        atlas_img = Image.new("RGBA", (atlas_w, atlas_h), (0, 0, 0, 0))
        output_txt_lines = [f"cell_size_w={cell_w}\ncell_size_h={cell_h}\ncolumns={columns}\nrows={rows}\n"]
        
        has_page_data = False

        for row in range(rows):
            for col in range(columns):
                code = start_code + (row * columns) + col
                dst_x = col * cell_w
                dst_y = row * cell_h
                
                if code in csv_map:
                    img_name = csv_map[code]
                    potential_filenames = [f"{img_name}.png", f"{img_name.lower()}.png", f"{img_name.upper()}.png"]
                    
                    actual_path = None
                    for pf in potential_filenames:
                        test_path = os.path.join(src_dir, pf)
                        if os.path.exists(test_path):
                            actual_path = test_path
                            break
                    
                    # 画像ファイルが実在する場合
                    if actual_path:
                        has_page_data = True
                        try:
                            char_img = Image.open(actual_path).convert("RGBA")
                            
                            # 【解決：完全左寄せ仕様】
                            # 余計な中央寄せ計算や余白の補正を一切行わず、
                            # 12x12pxの器の左上端（0, 0）を原点として、文字画像を100%素直にプロットします。
                            char_crop = char_img.crop((0, 0, cell_w, cell_h))
                            atlas_img.paste(char_crop, (dst_x, dst_y), char_crop)
                            
                            output_txt_lines.append(f"0x{code:04x}:{col},{row}\n")
                            success_count += 1
                        except Exception as e:
                            output_txt_lines.append(f"0x{code:04x}:empty\n")
                    else:
                        output_txt_lines.append(f"0x{code:04x}:empty\n")
                else:
                    output_txt_lines.append(f"0x{code:04x}:empty\n")

        # 3. 命名規則の統一: atlas_mcl_p<2桁16進数>.png
        file_base = f"atlas_mcl_p{page_hex}"
        png_path = os.path.join(out_dir, file_base + ".png")
        txt_path = os.path.join(out_dir, file_base + ".png.txt")
        
        atlas_img.save(png_path, "PNG")
        with open(txt_path, "w", encoding="utf-8") as f:
            f.writelines(output_txt_lines)

    print("-" * 60)
    print(f" [!] すべて完了しました！計 {success_count} 文字の看板画像を左寄せアトラス化しました。")
    print(f" ➔ 成果物は '{out_dir}' フォルダ内に保存されています。")
    print("="*60)

if __name__ == "__main__":
    csv_file   = "./characters.tsv"       # 提供されたCSVデータファイル
    src_folder = "./textures"             # 看板の素となる個別画像フォルダ (_a_.png 等)
    out_folder = "./textures/atlas_mcl"   # アトラスの出力先フォルダ
    
    build_mcl_sign_atlas(csv_file, src_folder, out_folder)

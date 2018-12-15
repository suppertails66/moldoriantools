
echo "*******************************************************************************"
echo "Setting up environment..."
echo "*******************************************************************************"

set -o errexit

BASE_PWD=$PWD
PATH=".:./asm/bin/:$PATH"
INROM="moldorian.gg"
OUTROM="moldorian_en.gg"
WLADX="./wla-dx/binaries/wla-z80"
WLALINK="./wla-dx/binaries/wlalink"

cp "$INROM" "$OUTROM"

mkdir -p out

echo "*******************************************************************************"
echo "Building tools..."
echo "*******************************************************************************"

make blackt
make libsms
make

if [ ! -f $WLADX ]; then
  
  echo "********************************************************************************"
  echo "Building WLA-DX..."
  echo "********************************************************************************"
  
  cd wla-dx
    cmake -G "Unix Makefiles" .
    make
  cd $BASE_PWD
  
fi

echo "*******************************************************************************"
echo "Doing initial ROM prep..."
echo "*******************************************************************************"

mkdir -p out
mold_romprep "$OUTROM" "$OUTROM"

echo "*******************************************************************************"
echo "Building font..."
echo "*******************************************************************************"

mkdir -p out/font
mold_fontbuild rsrc/font_vwf/ out/font/

echo "*******************************************************************************"
echo "Building graphics..."
echo "*******************************************************************************"

mkdir -p out/precmp
mkdir -p out/grp
mkdir -p out/script/intro
grpundmp_gg rsrc/font.png out/precmp/font.bin 0x90
grpundmp_gg rsrc/battle_font.png out/grp/battle_font.bin 0x17
mold_introbuild script/ table/moldorian_en.tbl out/script/

#nes_tileundmp rsrc/font/font_0x1000.png 256 out/grp/font_0x1000.bin
#filepatch out/villgust_chr.bin 0x1000 out/grp/font_0x1000.bin out/villgust_chr.bin

echo "*******************************************************************************"
echo "Building tilemaps..."
echo "*******************************************************************************"
mkdir -p out/maps
mkdir -p out/grp
tilemapper_gg tilemappers/title.txt

cat out/grp/title_grp.bin out/maps/title.bin rsrc_raw/title_pal.bin > out/precmp/title_data.bin

echo "*******************************************************************************"
echo "Compressing graphics..."
echo "*******************************************************************************"

mkdir -p out/cmp
for file in out/precmp/*; do
  mold_grpcmp "$file" "out/cmp/$(basename $file)"
done

# echo "*******************************************************************************"
# echo "Building tilemaps..."
# echo "*******************************************************************************"
# 
# #mkdir -p out/maps_raw
# #tilemapper_nes tilemappers/title.txt
# mkdir -p out/maps
# tilemapper_nes tilemappers/title.txt
# 
# #mkdir -p out/maps_conv
# #mapconv out/maps_conv/
# 
# filepatch out/villgust_chr.bin 0x1D010 out/grp/title_grp.bin out/villgust_chr.bin
# filepatch "$OUTROM" 0x15292 out/maps/title.bin "$OUTROM"
# filepatch "$OUTROM" 0x154D5 rsrc_raw/title_attrmap.bin "$OUTROM"
# 
# # echo "*******************************************************************************"
# # echo "Patching other graphics..."
# # echo "*******************************************************************************"
# # 
# # #rawgrpconv rsrc/misc/shiro.png rsrc/misc/shiro.txt out/sanma_chr.bin out/sanma_chr.bin
# # #rawgrpconv rsrc/misc/kyojin.png rsrc/misc/kyojin.txt out/sanma_chr.bin out/sanma_chr.bin
# # 
# # for file in rsrc/misc/*.txt; do
# #   bname=$(basename $file .txt)
# #   rawgrpconv rsrc/misc/$bname.png rsrc/misc/$bname.txt out/villgust_chr.bin out/villgust_chr.bin
# # done

echo "*******************************************************************************"
echo "Patching graphics..."
echo "*******************************************************************************"

filepatch "$OUTROM" 0x5401C out/cmp/font.bin "$OUTROM" -l 2432
filepatch "$OUTROM" 0x56D22 out/grp/battle_font.bin "$OUTROM"

echo "*******************************************************************************"
echo "Building script..."
echo "*******************************************************************************"

mkdir -p out/script
mkdir -p out/script/strings
mold_scriptbuild script/ table/moldorian_en.tbl out/script/

# echo "*******************************************************************************"
# echo "Building compression table..."
# echo "*******************************************************************************"
# 
# mkdir -p out/cmptbl
# cmptablebuild table/villgust_en.tbl out/cmptbl/cmptbl.bin

echo "********************************************************************************"
echo "Applying ASM patches..."
echo "********************************************************************************"

mkdir -p "out/asm"
cp "$OUTROM" "asm/moldorian.gg"

cd asm
  # apply hacks
  ../$WLADX -I ".." -o "main.o" "main.s"
  ../$WLALINK -s -v linkfile moldorian_patched.gg
  
  mv -f "moldorian_patched.gg" "moldorian.gg"
  
  # update region code in header (WLA-DX forces it to 4,
  # for "export SMS", when the .smstag directive is used
  # -- we want 7, for "international GG")
  ../$WLADX -o "main2.o" "main2.s"
  ../$WLALINK -v linkfile2 moldorian_patched.gg
cd "$BASE_PWD"

mv -f "asm/moldorian_patched.gg" "$OUTROM"
mv -f "asm/moldorian_patched.sym" "$(basename $OUTROM .gg).sym"
rm "asm/moldorian.gg"
rm "asm/main.o"
rm "asm/main2.o"

# echo "*******************************************************************************"
# echo "Finalizing ROM..."
# echo "*******************************************************************************"
# 
# romfinalize "$OUTROM" "out/villgust_chr.bin" "$OUTROM"

echo "*******************************************************************************"
echo "Success!"
echo "Output file:" $OUTROM
echo "*******************************************************************************"

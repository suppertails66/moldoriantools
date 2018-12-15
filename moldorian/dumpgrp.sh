mkdir -p rsrc
mkdir -p rsrc/orig

# title
# cmp size: 3858 bytes
./mold_grpdecmp moldorian.gg 0x6A0F6 0x2328 rsrc_raw/title_data.bin
#./moldgrpdmp moldorian.gg test.png 0x6A0F6 0x2000
./tilemapdmp_gg rsrc_raw/title_data.bin 0x2000 full 0x14 0x13 rsrc_raw/title_data.bin 0x0 rsrc/orig/title.png

# main font
# cmp size: 2432 bytes
#./moldgrpdmp moldorian.gg rsrc/orig/font.png 0x5401C 0x1200

# battle font
#./grpdmp_gg moldorian.gg rsrc/battle_font.png 0x56D22 0x17


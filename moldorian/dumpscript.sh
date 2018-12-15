mkdir -p script/orig

#make libsms && make mold_scriptsrch
#./mold_scriptsrch moldorian.gg table/moldorian.tbl script/orig/

make libsms && make mold_scriptdmp
./mold_scriptdmp moldorian.gg table/moldorian.tbl script/orig/

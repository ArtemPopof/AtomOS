fasm src/boot.asm AtomOS_boot_0.03.bin;
cp AtomOS_boot_0.03.bin bin/;
rm AtomOS_boot_0.03.bin;
./listfs_maker.out of=boot/boot.img src=root boot=bin/AtomOS_boot_0.03.bin size=10;

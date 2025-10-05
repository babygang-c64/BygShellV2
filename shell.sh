
pprint() {
  case "$1" in
    green) color=$(tput setaf 2) ;;
    red)   color=$(tput setaf 1) ;;
    blue)  color=$(tput setaf 4) ;;
    *)     color=$(tput sgr0)    ;;
  esac
  shift
  printf '\n%s%s%s\n' "$color" "$*" "$(tput sgr0)"
}

kickass() {
    java -jar ${KICK_PATH}/KickAss.jar $*
    if [[ $? == 0 ]]
    then
        pprint green "Compile OK 💾"
    else
        pprint red "💣💣💣 Boom, compile error !"
        exit 1
    fi
}

build_command()
{
    CMD=$1
    uv run ppkick.py ${CMD}.asm ${CMD}_pp.asm
    kickass ${CMD}_pp.asm $2
    ${VICE_PATH}/c1541 -attach ${disk} -write ${CMD}_pp.prg ${CMD} -silent
    [ -f ${CMD}.hlp ] && ${VICE_PATH}/c1541 -attach ${disk} -write ${CMD}.hlp ${CMD}.hlp -silent
}

copy_to_d64()
{
    FILEIN=$1
    FILEOUT=$2
    ${VICE_PATH}/c1541 -attach ${disk} -write "${FILEIN}" "${FILEOUT}" -silent
}

VICE_PATH=/home/prod/c64/bin
KICK_PATH=/home/prod/c64/bin
disk=byg_shell.d64

uv run ppkick.py shell.asm shell_pp.asm
uv run ppkick.py bios.asm bios_pp.asm
uv run ppkick.py bios_entries.asm bios_entries_pp.asm

kickass shell_pp.asm -symbolfile
dd if=shell_pp.prg of=bygshell.bin bs=1 skip=2
kickass cartridge_header.asm -binfile -o bygshell.crt

cat bygshell.bin >> bygshell.crt

rm -f ${disk}
${VICE_PATH}/c1541 -format "byg-shell",2025 d64 ${disk} -silent

copy_to_d64 shell_pp.prg "shell"
copy_to_d64 test2.asm "test2.asm"
copy_to_d64 test.txt "test"
copy_to_d64 file1.txt "file1"
copy_to_d64 file2.txt "file2"
copy_to_d64 test2.txt "test2"
copy_to_d64 edit.hlp "edit.hlp"
copy_to_d64 empty.txt "empty"
copy_to_d64 cartridge_header.asm "crt.asm"
copy_to_d64 cat.asm "cat.asm"
copy_to_d64 wc.asm "wc.asm"
copy_to_d64 samsara.koa "samsara.koa"
copy_to_d64 image.koa "image.koa"
copy_to_d64 commando.sid "commando.sid"
copy_to_d64 "jiffymon v2" "jiffymonv2"
copy_to_d64 commands.hlp commands.hlp
copy_to_d64 keys.hlp keys.hlp

build_command cat
build_command wc
build_command search
build_command hw -symbolfile
build_command koala
build_command head
build_command mon
build_command edit -symbolfile
build_command menu
build_command chars
build_command touch
build_command diff
build_command lsblk 
build_command join
build_command checksum
build_command xform -symbolfile
build_command unit -symbolfile

rm -f *_pp.asm

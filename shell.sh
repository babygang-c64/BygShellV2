
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
${VICE_PATH}/c1541 -attach ${disk} -write shell_pp.prg "shell" -silent

${VICE_PATH}/c1541 -attach ${disk} -write test2.asm "test2.asm" -silent
${VICE_PATH}/c1541 -attach ${disk} -write test.txt "test" -silent
${VICE_PATH}/c1541 -attach ${disk} -write file1.txt "file1" -silent
${VICE_PATH}/c1541 -attach ${disk} -write file2.txt "file2" -silent
${VICE_PATH}/c1541 -attach ${disk} -write test2.txt "test2" -silent
${VICE_PATH}/c1541 -attach ${disk} -write edit.hlp "edit.hlp" -silent
${VICE_PATH}/c1541 -attach ${disk} -write empty.txt "empty" -silent
${VICE_PATH}/c1541 -attach ${disk} -write cartridge_header.asm "crt.asm" -silent
${VICE_PATH}/c1541 -attach ${disk} -write cat.asm "cat.asm" -silent
${VICE_PATH}/c1541 -attach ${disk} -write wc.asm "wc.asm" -silent
${VICE_PATH}/c1541 -attach ${disk} -write samsara.koa "samsara.koa" -silent
${VICE_PATH}/c1541 -attach ${disk} -write image.koa "image.koa" -silent
${VICE_PATH}/c1541 -attach ${disk} -write commando.sid "commando.sid" -silent
${VICE_PATH}/c1541 -attach ${disk} -write "jiffymon v2" "jiffymonv2" -silent
${VICE_PATH}/c1541 -attach ${disk} -write commands.hlp commands.hlp -silent
${VICE_PATH}/c1541 -attach ${disk} -write keys.hlp keys.hlp -silent

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

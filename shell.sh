
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

VICE_PATH=/home/prod/c64/bin
KICK_PATH=/home/prod/c64/bin
disk=byg_shell.d64

uv run ppkick.py shell.asm shell_pp.asm
uv run ppkick.py bios.asm bios_pp.asm
uv run ppkick.py cat.asm cat_pp.asm
uv run ppkick.py wc.asm wc_pp.asm
uv run ppkick.py search.asm search_pp.asm
uv run ppkick.py hw.asm hw_pp.asm
uv run ppkick.py koala.asm koala_pp.asm
uv run ppkick.py bios_entries.asm bios_entries_pp.asm

kickass shell_pp.asm -symbolfile
kickass hw_pp.asm
kickass wc_pp.asm
kickass search_pp.asm
kickass cat_pp.asm
kickass koala_pp.asm
dd if=shell_pp.prg of=bygshell.bin bs=1 skip=2
kickass cartridge_header.asm -binfile -o bygshell.crt

cat bygshell.bin >> bygshell.crt

if [[ $? == 0 ]]
then
    rm -f ${disk}
    ${VICE_PATH}/c1541 -format "byg-shell",2025 d64 ${disk} -silent
    ${VICE_PATH}/c1541 -attach ${disk} -write shell_pp.prg "shell" -silent
    ${VICE_PATH}/c1541 -attach ${disk} -write hw_pp.prg "hw" -silent
    ${VICE_PATH}/c1541 -attach ${disk} -write cat_pp.prg "cat" -silent
    ${VICE_PATH}/c1541 -attach ${disk} -write wc_pp.prg "wc" -silent
    ${VICE_PATH}/c1541 -attach ${disk} -write search_pp.prg "search" -silent
    ${VICE_PATH}/c1541 -attach ${disk} -write koala_pp.prg "koala" -silent
    ${VICE_PATH}/c1541 -attach ${disk} -write test.txt "test" -silent
    ${VICE_PATH}/c1541 -attach ${disk} -write cartridge_header.asm "crt.asm" -silent
    ${VICE_PATH}/c1541 -attach ${disk} -write cat.asm "cat.asm" -silent
    ${VICE_PATH}/c1541 -attach ${disk} -write samsara.koa "samsara.koa" -silent
    ${VICE_PATH}/c1541 -attach ${disk} -write image.koa "image.koa" -silent
    pprint green "Compile OK 💾"
else
    pprint red "💣💣💣 Boom, compile error !"
fi

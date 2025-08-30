#!/usr/bin/env python3
# ppkick : kickassembler pre-processor (fully table-driven)

import sys


def get_size(value: str) -> int:
    """Return operand size in bits (8 or 16)."""
    if value.startswith("$") and len(value) <= 3:
        return 8
    if value.isdigit() and int(value) < 256:
        return 8
    return 16


# --------------------------------------------------------------------
# PARAMETER DECODER (table-driven)
# --------------------------------------------------------------------

def param_type(param: str):
    """Return (ptype, pval) for operand."""

    special_regs = {"rdest": "reg_zdest", "rsrc": "reg_zsrc"}

    rules = [
        # Immediate
        (lambda p: p.startswith("#"),
         lambda p: ("i", p[1:])),
        # Accumulator
        (lambda p: p.lower() == "a",
         lambda p: ("a", "")),
        # Register
        (lambda p: p[0].lower() == "r" and (p[1:].isdigit() or p.lower() in special_regs),
         lambda p: ("r", special_regs.get(p.lower(), p[1:].lower()))),
        # Indirect / Sub
        (lambda p: p.startswith("("),
         lambda p: (
             "si" if p[2:-1].endswith("++") else "s",
             special_regs.get(
                 p[2:-1].rstrip("+").lower(),
                 p[2:-1].rstrip("+").lower()
             )
         )),
    ]

    for cond, action in rules:
        if cond(param):
            return action(param)

    # Default: word/address
    return "w", param


# --------------------------------------------------------------------
# MOV
# --------------------------------------------------------------------

def handle_mov(elems):
    p0, v0 = param_type(elems[1])
    p1, v1 = param_type(elems[3])

    table = {
        ("a", "s"):   lambda: f"getbyte({v1})",
        ("a", "si"):  lambda: f"getbyte_r({v1})",
        ("s", "a"):   lambda: f"setbyte({v0})",
        ("si", "a"):  lambda: f"setbyte_r({v0})",
        ("r", "a"):   lambda: f"sta_r({v0})",
    }
    if (p0, p1) in table:
        return table[(p0, p1)]()
    if p0 != "a" and p1 != "a":
        return f"st{p1}_{p0}({v0}, {v1})"
    return f"st_{p0}{p1}({v0}, {v1})"


# --------------------------------------------------------------------
# ADD
# --------------------------------------------------------------------

def handle_add(elems):
    p0, v0 = param_type(elems[1])
    p1, v1 = param_type(elems[3])
    size = get_size(v1) if p1 == "i" else None

    table = {
        ("r", "a"): lambda: f"add_r({v0})",
        ("r", "i"): lambda: f"{'addi' if size == 8 else 'addw'}_r({v0}, {v1})",
        ("w", "a"): lambda: f"add8({v0})",
        ("w", "i"): lambda: f"{'addi' if size == 8 else 'addw'}_w({v0}, {v1})",
        ("w", "w"): lambda: f"adda_w({v0}, {v1})",
    }
    if (p0, p1) in table:
        return table[(p0, p1)]()
    raise ValueError(f"Invalid ADD instruction: {' '.join(elems)}")


# --------------------------------------------------------------------
# Other handlers
# --------------------------------------------------------------------

def handle_movi(elems):
    p0, v0 = param_type(elems[1])
    p1, v1 = param_type(elems[3])
    if p0 == "s" and p1 == "r":
        return f"stir_s({v0},{v1})"
    raise ValueError("Invalid MOVI instruction")


def handle_single_reg(elems, instr):
    p0, v0 = param_type(elems[1])
    return f"{instr}_r({v0})" if p0 == "r" else " ".join(elems)


def handle_incdecw(elems, instr):
    instr = {"inw": "incw", "dew": "decw"}.get(instr, instr)
    p0, v0 = param_type(elems[1])
    return f"{instr[:3]}_w({v0})" if p0 == "w" else " ".join(elems)


def handle_swap(elems):
    p0, v0 = param_type(elems[1])
    p1, v1 = param_type(elems[3])
    if p0 == p1 == "r":
        return f"swapr_r({v0},{v1})"
    raise ValueError(f"Invalid SWAP instruction: {' '.join(elems)}")


def handle_simple(elems, instr):
    return f"{instr}({elems[1]})"


def handle_swi(elems):
    _, v0 = param_type(elems[1])
    if len(elems) == 2:
        return f"bios(bios.{v0})"
    if len(elems) == 4:
        _, v1 = param_type(elems[3])
        return f"call_bios(bios.{v0}, {v1})"
    if len(elems) == 6:
        return f"call_bios2(bios.{v0}, {elems[3]}, {elems[5]})"
    raise ValueError(f"Invalid SWI instruction: {' '.join(elems)}")


# --------------------------------------------------------------------
# Dispatch table
# --------------------------------------------------------------------

handlers = {
    "mov": handle_mov,
    "movi": handle_movi,
    "push": lambda e: handle_single_reg(e, "push"),
    "pop":  lambda e: handle_single_reg(e, "pop"),
    "inc":  lambda e: handle_single_reg(e, "inc"),
    "dec":  lambda e: handle_single_reg(e, "dec"),
    "incw": lambda e: handle_incdecw(e, "incw"),
    "decw": lambda e: handle_incdecw(e, "decw"),
    "inw":  lambda e: handle_incdecw(e, "inw"),
    "dew":  lambda e: handle_incdecw(e, "dew"),
    "swp":  lambda e: "swp()",
    "sxy":  lambda e: "sxy()",
    "add":  handle_add,
    "swap": handle_swap,
    "stc":  lambda e: handle_simple(e, "stc"),
    "ldc":  lambda e: handle_simple(e, "ldc"),
    "jne":  lambda e: handle_simple(e, "jne"),
    "jeq":  lambda e: handle_simple(e, "jeq"),
    "jcc":  lambda e: handle_simple(e, "jcc"),
    "jcs":  lambda e: handle_simple(e, "jcs"),
    "swi":  handle_swi,
}


# --------------------------------------------------------------------
# Main
# --------------------------------------------------------------------

def main():
    if len(sys.argv) != 3:
        print("PPKICK v0.2\nBabygang extended 6510 instruction set pre-processor\n")
        print("Usage: ppkick <filein> <fileout>")
        sys.exit(1)

    filein, fileout = sys.argv[1:3]
    print(f"ppkick {filein} → {fileout}")

    with open(filein) as hin, open(fileout, "w") as hout:
        for line in hin:
            elems = line.replace(",", " , ").split()
            if not elems:
                hout.write(line)
                continue

            instr = elems[0].lower()
            try:
                if instr in handlers:
                    hout.write(handlers[instr](elems) + "\n")
                else:
                    hout.write(line)
            except Exception as e:
                print("Error:", e)
                print("Line:", line.strip())
                sys.exit(1)


if __name__ == "__main__":
    main()

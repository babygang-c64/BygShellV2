.label vars=$cf00
.label buffer=$cf80
.label nb_params=$cfff
.label options_params=$cffe
.label OPT_PIPE=128

.namespace bios 
{
    .label bios_exec=$cf70
    
    .label reset=9
    .label str_split=11
    .label str_len=13
    .label pprint=15
    .label str_next=17
    .label file_open=19
    .label file_close=21
    .label file_readline=23
    .label param_init=25
    .label error=27
    .label pprint_int=29
    .label pprint_hex=31
    .label key_wait=33
    .label buffer_read=35
    .label pprint_lines=37
    .label str_cmp=39
    .label get_device_status=41
    .label pprinthex8a=43
    .label file_load=45
    .label lines_find=47
    .label lines_goto=49
    .label pprint_nl=51
    .label hex2int=53
    .label print_hex_buffer=55
}

//===============================================================
// call_bios : call bios function with word parameter in r0
//===============================================================

.macro call_bios(bios_func, word_param)
{
    mov r0, #word_param
    lda #bios_func
    jsr bios.bios_exec
}

//===============================================================
// call_bios2 : call bios function with parameters in r0, r1
//===============================================================

.macro call_bios2(bios_func, word_param, word_param2)
{
    mov r0, #word_param
    mov r1, #word_param2
    lda #bios_func
    jsr bios.bios_exec
}

//===============================================================
// bios : call bios function without parameters
//===============================================================

.macro bios(bios_func)
{
    lda #bios_func
    jsr bios.bios_exec
}

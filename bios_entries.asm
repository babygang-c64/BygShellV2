#importonce

.encoding "ascii"

.label vars=$cf00
.label buffer=$cf80
.label nb_params=$cfff
.label options_params=$cffe
.label scan_params=$cffd
.label options_values=$cfe0
.label OPT_PIPE=128

.namespace bios 
{
    .label bios_exec=$cf70
    
    .label reset=9
    .label str_split=11
    .label str_len=13
    .label pprint=15
    .label str_next=17
    .label param_next=17
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
    .label param_top=57
    .label pipe_init=59
    .label pipe_end=61
    .label pipe_output=63
    .label str_pat=65
    .label str_expand=67
    .label is_filter=69
    .label str_cpy=71
    .label str_cat=73
    .label str_ins=75
    .label directory_open=77
    .label directory_get_entry=79
    .label directory_close=81
    .label param_process=83
    .label set_basic_string=85
    .label param_get_value=87
    .label mult10=89
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

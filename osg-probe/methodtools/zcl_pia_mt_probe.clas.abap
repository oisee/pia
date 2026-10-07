CLASS zcl_pia_mt_probe DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.

CLASS zcl_pia_mt_probe IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.
    " the method tools against the system's own ranges, on whatever backend this system has
    DATA(lo_backend) = zcl_pia_20_backend=>default( ).
    out->write( |backend { lo_backend->get_name( ) }| ).
    DATA(lo_outline) = NEW zcl_pia_15_t_outline( ).
    lo_outline->set_backend( lo_backend ).
    DATA(lo_read) = NEW zcl_pia_15_t_read_method( ).
    lo_read->set_backend( lo_backend ).
    DATA(lo_write) = NEW zcl_pia_15_t_write_method( ).
    lo_write->set_backend( lo_backend ).
    DATA(lv_cls) = to_upper( `ZCL_PIA_DEMO` ).
    out->write( lo_outline->zif_pia_00_tool~invoke( |\{"name":"{ lv_cls }"\}| )-output ).
    out->write( lo_read->zif_pia_00_tool~invoke( |\{"name":"{ lv_cls }","method":"ADD"\}| )-output ).
    out->write( lo_read->zif_pia_00_tool~invoke( |\{"name":"{ lv_cls }","method":"ADD_2_3"\}| )-output ).
    " write ADD back unchanged: the source must come out identical
    DATA(lv_before) = lo_backend->read_object( lv_cls )-source.
    DATA(lv_block) = lo_read->zif_pia_00_tool~invoke( |\{"name":"{ lv_cls }","method":"ADD"\}| )-output.
    lv_block = substring_after( val = lv_block sub = cl_abap_char_utilities=>newline ).
    " as the model sends it: newlines as \n in the JSON string
    DATA(lv_arg) = replace( val = lv_block sub = cl_abap_char_utilities=>newline with = `\n` occ = 0 ).
    DATA(ls_w) = lo_write->zif_pia_00_tool~invoke( |\{"name":"{ lv_cls }","method":"ADD","source":"| && lv_arg && `"}` ).
    out->write( ls_w-output ).
    DATA(lv_after) = lo_backend->read_object( lv_cls )-source.
    out->write( COND string( WHEN replace( val = lv_after sub = cl_abap_char_utilities=>cr_lf with = cl_abap_char_utilities=>newline occ = 0 )
                              = replace( val = lv_before sub = cl_abap_char_utilities=>cr_lf with = cl_abap_char_utilities=>newline occ = 0 )
                             THEN `round trip: identical` ELSE `round trip: DIFFERENT` ) ).
  ENDMETHOD.
ENDCLASS.

CLASS zcl_pia_mt_probe2 DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.

CLASS zcl_pia_mt_probe2 IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.
    DATA lt TYPE string_table.
    DATA(lv_u) = zcl_pia_00_json_util=>unescape( `a\nb\nc` ).
    out->write( |unescaped length { strlen( lv_u ) }| ).
    SPLIT lv_u AT cl_abap_char_utilities=>newline INTO TABLE lt.
    out->write( |split plain: { lines( lt ) }| ).
    SPLIT replace( val = lv_u sub = cl_abap_char_utilities=>cr_lf with = cl_abap_char_utilities=>newline occ = 0 )
      AT cl_abap_char_utilities=>newline INTO TABLE lt.
    out->write( |split after replace: { lines( lt ) }| ).
    DATA(lv_args) = `{"name":"ZCL_PIA_DEMO","method":"ADD","source":"  METHOD add.\n    rv_ = a + b.\n  ENDMETHOD."}`.
    DATA(lv_x) = zcl_pia_00_json_util=>extract_str( iv_json = lv_args iv_name = 'source' ).
    out->write( |extract_str: [{ lv_x }] length { strlen( lv_x ) }| ).
    DATA(lv_y) = zcl_pia_00_json_util=>unescape( lv_x ).
    SPLIT lv_y AT cl_abap_char_utilities=>newline INTO TABLE lt.
    out->write( |get_arg lines: { lines( lt ) }| ).
    DATA(lo_w) = NEW zcl_pia_15_t_write_method( ).
    lo_w->set_backend( zcl_pia_20_backend=>default( ) ).
    out->write( lo_w->zif_pia_00_tool~invoke( lv_args )-output ).
    DATA(lv_r) = replace( val = lv_u sub = cl_abap_char_utilities=>cr_lf with = cl_abap_char_utilities=>newline occ = 0 ).
    out->write( |replace result length { strlen( lv_r ) }| ).
  ENDMETHOD.
ENDCLASS.

CLASS zcl_pia_sg_probe DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.

CLASS zcl_pia_sg_probe IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.
    " step 1 (no breakage file yet): self_check on the live code, then remember + write the broken version
    " step 2: check_and_restore with the broken version live
    DATA(lo_backend) = zcl_pia_20_backend=>default( ).
    DATA(lv_check) = zcl_pia_15_self_guard=>self_check( ).
    out->write( |self_check: { COND string( WHEN lv_check IS INITIAL THEN `ok` ELSE lv_check ) }| ).
    DATA(lt_flag) = zcl_pia_00_session_store=>read_lines( `pia-sg-step.txt` ).
    IF lt_flag IS INITIAL.
      zcl_pia_15_self_guard=>remember( io_backend = lo_backend iv_name = `ZCL_PIA_00_CONFIG` ).
      DATA(lv_broken) = concat_lines_of( table = zcl_pia_00_session_store=>read_lines( `pia-sg-broken-config.abap` )
                                         sep = cl_abap_char_utilities=>newline ).
      out->write( lo_backend->write_source( iv_name = `ZCL_PIA_00_CONFIG` iv_source = lv_broken )-message ).
      out->write( |activate: { lo_backend->activate( `ZCL_PIA_00_CONFIG` )-state }| ).
      zcl_pia_00_session_store=>write_lines( iv_file = `pia-sg-step.txt` it_ = VALUE #( ( `2` ) ) ).
    ELSE.
      out->write( |check_and_restore: { zcl_pia_15_self_guard=>check_and_restore( lo_backend ) }| ).
      zcl_pia_00_session_store=>write_lines( iv_file = `pia-sg-step.txt` it_ = VALUE #( ) ).
    ENDIF.
  ENDMETHOD.
ENDCLASS.

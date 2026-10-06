CLASS zcl_pia_race_run DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.

CLASS zcl_pia_race_run IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.
    DATA lv_t0 TYPE timestampl.
    DATA lv_t1 TYPE timestampl.
    GET TIME STAMP FIELD lv_t0.
    TRY.
        out->write( |RUN_TESTS: { zcl_osd_adt_host=>store( iv_command = `RUN_TESTS`
          iv_json = `{"targets":[{"type":"CLAS","name":"ZCL_PIA_RACE"}]}` )-json }| ).
      CATCH cx_root INTO DATA(lx).
        out->write( |RUN_TESTS EXCEPTION: { lx->get_text( ) }| ).
    ENDTRY.
    GET TIME STAMP FIELD lv_t1.
    out->write( |started { lv_t0 } finished { lv_t1 }| ).
    TRY.
        out->write( |next STORE READ: { strlen( zcl_osd_adt_host=>store( iv_command = `READ` iv_type = `CLAS` iv_name = `ZCL_PIA_RACE` )-source ) } chars| ).
      CATCH cx_root INTO DATA(lx2).
        out->write( |next STORE EXCEPTION: { lx2->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.
ENDCLASS.

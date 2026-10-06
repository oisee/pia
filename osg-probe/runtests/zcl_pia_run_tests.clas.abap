CLASS zcl_pia_run_tests DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.

CLASS zcl_pia_run_tests IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.
    TRY.
        out->write( zcl_osd_adt_host=>store( iv_command = `RUN_TESTS`
          iv_json = `{"targets":[{"type":"CLAS","name":"ZCL_PIA_00_JSON_UTIL"}]}` )-json ).
      CATCH cx_root INTO DATA(lx).
        out->write( |EXCEPTION { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.
ENDCLASS.

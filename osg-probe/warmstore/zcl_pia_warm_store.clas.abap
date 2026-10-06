CLASS zcl_pia_warm_store DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.

CLASS zcl_pia_warm_store IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.
    " STORE edit of an existing, long-published class: touch a comment, WRITE, ACTIVATE
    DATA lv_src TYPE string.
    DATA lv_json TYPE string.
    TRY.
        lv_src = zcl_osd_adt_host=>store( iv_command = `READ` iv_type = `CLAS` iv_name = `ZCL_PIA_DEMO` )-source.
        IF lv_src CS `" warm-touch`.
          REPLACE FIRST OCCURRENCE OF REGEX `" warm-touch [0-9]+` IN lv_src WITH |" warm-touch { sy-uzeit }|.
        ELSE.
          lv_src = lv_src && |\n" warm-touch { sy-uzeit }|.
        ENDIF.
        out->write( |write: { zcl_osd_adt_host=>store( iv_command = `WRITE` iv_type = `CLAS` iv_name = `ZCL_PIA_DEMO`
                                                       iv_include = `main` iv_source = lv_src )-json }| ).
        lv_json = zcl_osd_adt_host=>store( iv_command = `ACTIVATE` iv_type = `CLAS` iv_name = `ZCL_PIA_DEMO` )-json.
        out->write( |activate: { lv_json }| ).
      CATCH cx_root INTO DATA(lx).
        out->write( |EXCEPTION { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.
ENDCLASS.

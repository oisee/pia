CLASS zcl_pia_p3a_recov DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
  PRIVATE SECTION.
    CONSTANTS c_state TYPE string VALUE `/home/alice/dev/pia/.state/recov.state`.
    DATA mo_out TYPE REF TO if_oo_adt_classrun_out.
    METHODS store IMPORTING iv_command TYPE string iv_name TYPE string OPTIONAL
                            iv_json TYPE string OPTIONAL iv_source TYPE string OPTIONAL
                  RETURNING VALUE(rv_) TYPE string.
    METHODS live IMPORTING iv_class TYPE string RETURNING VALUE(rv_) TYPE string.
    METHODS src IMPORTING iv_name TYPE string iv_body TYPE string RETURNING VALUE(rv_) TYPE string.
    METHODS field IMPORTING iv_json TYPE string iv_name TYPE string RETURNING VALUE(rv_) TYPE string.
    METHODS read_state RETURNING VALUE(rv_) TYPE string.
    METHODS write_state IMPORTING iv_ TYPE string.
ENDCLASS.

CLASS zcl_pia_p3a_recov IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.
    DATA lv_state TYPE string.
    DATA lv_step TYPE string.
    DATA lv_op TYPE string.
    DATA lv_act TYPE string.
    mo_out = out.
    lv_state = read_state( ).
    SPLIT lv_state AT `;` INTO lv_step lv_op.
    CASE lv_step.
      WHEN ``.
        mo_out->write( `STEP1: broken draft (never activated) + OK class, activate OK, then KILL during pending` ).
        mo_out->write( |create BAD: { store( iv_command = `CREATE` iv_name = `ZCL_PIA_RC_BAD` iv_json = `{"package":"$TMP","description":"rc bad"}`
                                             iv_source = src( iv_name = `zcl_pia_rc_bad` iv_body = `r = lv_undefined.` ) ) }| ).
        mo_out->write( |create OK: { store( iv_command = `CREATE` iv_name = `ZCL_PIA_RC_OK` iv_json = `{"package":"$TMP","description":"rc ok"}`
                                            iv_source = src( iv_name = `zcl_pia_rc_ok` iv_body = `r = 'rc-v1'.` ) ) }| ).
        lv_act = store( iv_command = `ACTIVATE` iv_name = `ZCL_PIA_RC_OK` ).
        mo_out->write( |activate OK: { lv_act }| ).
        write_state( |2;{ field( iv_json = lv_act iv_name = `op_id` ) }| ).
      WHEN `2`.
        mo_out->write( `STEP2 (after restart): status of interrupted op, liveness, re-activate` ).
        mo_out->write( |status: { store( iv_command = `ACTIVATION_STATUS` iv_json = |\{"op_id":"{ lv_op }"\}| ) }| ).
        mo_out->write( |live OK (expect not live: never published): { live( `ZCL_PIA_RC_OK` ) }| ).
        mo_out->write( |live BAD (expect not live): { live( `ZCL_PIA_RC_BAD` ) }| ).
        mo_out->write( |read BAD draft (expect inactive source kept): { strlen( store( iv_command = `READ` iv_name = `ZCL_PIA_RC_BAD` ) ) } chars json| ).
        lv_act = store( iv_command = `ACTIVATE` iv_name = `ZCL_PIA_RC_OK` ).
        mo_out->write( |re-activate OK: { lv_act }| ).
        write_state( |3;{ field( iv_json = lv_act iv_name = `op_id` ) }| ).
      WHEN `3`.
        mo_out->write( `STEP3: published + live, then RESTART again` ).
        mo_out->write( |status: { store( iv_command = `ACTIVATION_STATUS` iv_json = |\{"op_id":"{ lv_op }"\}| ) }| ).
        mo_out->write( |live OK (expect rc-v1): { live( `ZCL_PIA_RC_OK` ) }| ).
        write_state( |4;{ lv_op }| ).
      WHEN `4`.
        mo_out->write( `STEP4 (after second restart): published op survives, OK still live, BAD still excluded` ).
        mo_out->write( |status: { store( iv_command = `ACTIVATION_STATUS` iv_json = |\{"op_id":"{ lv_op }"\}| ) }| ).
        mo_out->write( |live OK (expect rc-v1): { live( `ZCL_PIA_RC_OK` ) }| ).
        mo_out->write( |live BAD (expect not live): { live( `ZCL_PIA_RC_BAD` ) }| ).
        mo_out->write( |delete OK: { store( iv_command = `DELETE` iv_name = `ZCL_PIA_RC_OK` ) }| ).
        mo_out->write( |delete BAD: { store( iv_command = `DELETE` iv_name = `ZCL_PIA_RC_BAD` ) }| ).
        write_state( `` ).
        mo_out->write( `DONE` ).
    ENDCASE.
  ENDMETHOD.

  METHOD src.
    rv_ = |CLASS { iv_name } DEFINITION PUBLIC FINAL CREATE PUBLIC. PUBLIC SECTION. CLASS-METHODS v RETURNING VALUE(r) TYPE string. ENDCLASS. | &&
          |CLASS { iv_name } IMPLEMENTATION. METHOD v. { iv_body } ENDMETHOD. ENDCLASS.|.
  ENDMETHOD.

  METHOD live.
    TRY.
        CALL METHOD (iv_class)=>(`V`) RECEIVING r = rv_.
      CATCH cx_root INTO DATA(lx).
        rv_ = |not live ({ lx->get_text( ) })|.
    ENDTRY.
  ENDMETHOD.

  METHOD store.
    TRY.
        rv_ = zcl_osd_adt_host=>store( iv_command = iv_command iv_type = `CLAS` iv_name = iv_name
                                       iv_json = iv_json iv_source = iv_source )-json.
      CATCH cx_root INTO DATA(lx).
        rv_ = |EXCEPTION { lx->get_text( ) }|.
    ENDTRY.
  ENDMETHOD.

  METHOD field.
    rv_ = zcl_pia_00_json_util=>extract_str( iv_json = iv_json iv_name = iv_name ).
  ENDMETHOD.

  METHOD read_state.
    TRY.
        OPEN DATASET c_state FOR INPUT IN TEXT MODE ENCODING UTF-8.
        IF sy-subrc = 0.
          READ DATASET c_state INTO rv_.
          CLOSE DATASET c_state.
        ENDIF.
      CATCH cx_root.
        CLEAR rv_.
    ENDTRY.
  ENDMETHOD.

  METHOD write_state.
    TRY.
        OPEN DATASET c_state FOR OUTPUT IN TEXT MODE ENCODING UTF-8.
        IF sy-subrc = 0.
          IF iv_ IS NOT INITIAL.
            TRANSFER iv_ TO c_state.
          ENDIF.
          CLOSE DATASET c_state.
        ENDIF.
      CATCH cx_root INTO DATA(lx).
        mo_out->write( |state write failed: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.
ENDCLASS.

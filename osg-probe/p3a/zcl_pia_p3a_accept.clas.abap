CLASS zcl_pia_p3a_accept DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
  PRIVATE SECTION.
    CONSTANTS c_state TYPE string VALUE `/home/alice/dev/pia/.state/p3a.state`.
    DATA mo_out TYPE REF TO if_oo_adt_classrun_out.
    METHODS step1.
    METHODS step2 IMPORTING iv_state TYPE string.
    METHODS raw IMPORTING iv_command TYPE string iv_name TYPE string OPTIONAL
                          iv_json TYPE string OPTIONAL iv_source TYPE string OPTIONAL
                RETURNING VALUE(rv_) TYPE string.
    METHODS show IMPORTING iv_label TYPE string is_ TYPE zif_pia_20_dev_backend=>ts_activation.
    METHODS read_state RETURNING VALUE(rv_) TYPE string.
    METHODS write_state IMPORTING iv_ TYPE string.
ENDCLASS.

CLASS zcl_pia_p3a_accept IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.
    DATA lv_state TYPE string.
    mo_out = out.
    lv_state = read_state( ).
    IF lv_state IS INITIAL.
      step1( ).
    ELSE.
      step2( lv_state ).
    ENDIF.
  ENDMETHOD.

  METHOD step1.
    DATA lo_be TYPE REF TO zif_pia_20_dev_backend.
    DATA ls_ok TYPE zif_pia_20_dev_backend=>ts_activation.
    DATA ls_bad TYPE zif_pia_20_dev_backend=>ts_activation.
    lo_be = zcl_pia_20_b_osg_store=>new( ).
    mo_out->write( `STEP1` ).
    mo_out->write( |create OK: { raw( iv_command = `CREATE` iv_name = `ZCL_PIA_P3A_OK`
      iv_json = `{"package":"$TMP","description":"p3a ok"}`
      iv_source = `CLASS zcl_pia_p3a_ok DEFINITION PUBLIC FINAL CREATE PUBLIC. PUBLIC SECTION. CLASS-METHODS v RETURNING VALUE(r) TYPE string. ENDCLASS. CLASS zcl_pia_p3a_ok IMPLEMENTATION. METHOD v. r = 'p3a-ok'. ENDMETHOD. ENDCLASS.` ) }| ).
    mo_out->write( |create BAD: { raw( iv_command = `CREATE` iv_name = `ZCL_PIA_P3A_BAD`
      iv_json = `{"package":"$TMP","description":"p3a bad"}`
      iv_source = `CLASS zcl_pia_p3a_bad DEFINITION PUBLIC FINAL CREATE PUBLIC. PUBLIC SECTION. CLASS-METHODS v RETURNING VALUE(r) TYPE string. ENDCLASS. CLASS zcl_pia_p3a_bad IMPLEMENTATION. METHOD v. r = lv_undefined. ENDMETHOD. ENDCLASS.` ) }| ).
    ls_ok = lo_be->activate( `ZCL_PIA_P3A_OK` ).
    show( iv_label = `activate OK` is_ = ls_ok ).
    ls_bad = lo_be->activate( `ZCL_PIA_P3A_BAD` ).
    show( iv_label = `activate BAD` is_ = ls_bad ).
    write_state( |{ ls_ok-op_id };{ ls_bad-op_id }| ).
    mo_out->write( `STEP1 done: run classrun again for STEP2` ).
  ENDMETHOD.

  METHOD step2.
    DATA lo_be TYPE REF TO zif_pia_20_dev_backend.
    DATA lv_op_ok TYPE string.
    DATA lv_op_bad TYPE string.
    DATA lv_v TYPE string.
    lo_be = zcl_pia_20_b_osg_store=>new( ).
    SPLIT iv_state AT `;` INTO lv_op_ok lv_op_bad.
    mo_out->write( `STEP2` ).
    show( iv_label = `status OK` is_ = lo_be->get_activation_status( lv_op_ok ) ).
    mo_out->write( |raw status OK: { raw( iv_command = `ACTIVATION_STATUS` iv_json = |\{"op_id":"{ lv_op_ok }"\}| ) }| ).
    IF lv_op_bad IS NOT INITIAL.
      show( iv_label = `status BAD` is_ = lo_be->get_activation_status( lv_op_bad ) ).
    ENDIF.
    show( iv_label = `status unknown` is_ = lo_be->get_activation_status( `00000000-0000-0000-0000-000000000000` ) ).
    mo_out->write( |raw status unknown: { raw( iv_command = `ACTIVATION_STATUS` iv_json = `{"op_id":"00000000-0000-0000-0000-000000000000"}` ) }| ).
    TRY.
        CALL METHOD (`ZCL_PIA_P3A_OK`)=>(`V`) RECEIVING r = lv_v.
        mo_out->write( |live call ZCL_PIA_P3A_OK=>V: { lv_v }| ).
      CATCH cx_root INTO DATA(lx).
        mo_out->write( |live call failed: { lx->get_text( ) }| ).
    ENDTRY.
    mo_out->write( |delete OK: { raw( iv_command = `DELETE` iv_name = `ZCL_PIA_P3A_OK` ) }| ).
    mo_out->write( |delete BAD: { raw( iv_command = `DELETE` iv_name = `ZCL_PIA_P3A_BAD` ) }| ).
    write_state( `` ).
    mo_out->write( `STEP2 done` ).
  ENDMETHOD.

  METHOD raw.
    TRY.
        rv_ = zcl_osd_adt_host=>store( iv_command = iv_command iv_type = `CLAS` iv_name = iv_name
                                       iv_json = iv_json iv_source = iv_source )-json.
      CATCH cx_root INTO DATA(lx).
        rv_ = |EXCEPTION { lx->get_text( ) }|.
    ENDTRY.
  ENDMETHOD.

  METHOD show.
    mo_out->write( |{ iv_label }: ok={ is_-ok } state={ is_-state } op_id={ is_-op_id } gen={ is_-generation_id } stage={ is_-failure_stage } issues={ is_-issues }| ).
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

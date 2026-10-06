CLASS zcl_pia_20_b_osg_store DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_pia_20_dev_backend.

    CLASS-METHODS new RETURNING VALUE(ro_) TYPE REF TO zcl_pia_20_b_osg_store.

ENDCLASS.

CLASS zcl_pia_20_b_osg_store IMPLEMENTATION.

  METHOD new.
    ro_ = NEW #( ).
  ENDMETHOD.

  METHOD zif_pia_20_dev_backend~get_name.
    rv_ = 'OSG-STORE'.
  ENDMETHOD.

  METHOD zif_pia_20_dev_backend~read_object.
    TRY.
        DATA(ls) = zcl_osd_adt_host=>store(
          iv_command = 'READ'
          iv_type    = 'CLAS'
          iv_name    = to_upper( iv_name )
          iv_include = 'main' ).
        rs_-ok = abap_true.
        rs_-source = ls-source.
        rs_-message = |read { iv_name } ({ strlen( ls-source ) } chars)|.
      CATCH cx_root INTO DATA(lx).
        rs_-ok = abap_false.
        rs_-message = lx->get_text( ).
    ENDTRY.
  ENDMETHOD.

  METHOD zif_pia_20_dev_backend~write_source.
    TRY.
        DATA(ls) = zcl_osd_adt_host=>store(
          iv_command = 'WRITE'
          iv_type    = 'CLAS'
          iv_name    = to_upper( iv_name )
          iv_include = COND string( WHEN iv_include IS INITIAL THEN `main` ELSE iv_include )
          iv_source  = iv_source ).
        rs_-ok = abap_true.
        rs_-message = |written { iv_name } { iv_include } ({ strlen( iv_source ) } chars)|.
      CATCH cx_root INTO DATA(lx).
        rs_-ok = abap_false.
        rs_-message = lx->get_text( ).
    ENDTRY.
  ENDMETHOD.

  METHOD zif_pia_20_dev_backend~activate.
    CLEAR rs_.
    TRY.
        DATA(ls) = zcl_osd_adt_host=>store(
          iv_command = 'ACTIVATE'
          iv_type    = 'CLAS'
          iv_name    = to_upper( iv_name ) ).

        " P3a: parse EV_JSON {state, op_id, generation_id, issues}
        " (empty EV_JSON = pre-P3a seam, treat as accepted)
        IF ls-json IS INITIAL.
          rs_-state = 'accepted'.
          rs_-ok = abap_true.
          RETURN.
        ENDIF.

        rs_-state = zcl_pia_00_json_util=>extract_str(
          iv_json = ls-json iv_name = 'state' ).
        rs_-op_id = zcl_pia_00_json_util=>extract_str(
          iv_json = ls-json iv_name = 'op_id' ).
        rs_-generation_id = zcl_pia_00_json_util=>extract_str(
          iv_json = ls-json iv_name = 'generation_id' ).
        rs_-issues = zcl_pia_00_json_util=>extract_balanced(
          iv_json = ls-json iv_key = 'issues' iv_open = '[' iv_close = ']' ).
        rs_-failure_stage = zcl_pia_00_json_util=>extract_str(
          iv_json = ls-json iv_name = 'failure_stage' ).

        " state=published or no refusal = ok
        IF rs_-state = 'failed' OR
           ( rs_-issues IS NOT INITIAL AND strlen( rs_-issues ) > 2 ).
          rs_-ok = abap_false.
        ELSE.
          rs_-ok = abap_true.
        ENDIF.
      CATCH cx_root INTO DATA(lx).
        rs_-ok = abap_false.
        rs_-state = 'error'.
        rs_-issues = lx->get_text( ).
    ENDTRY.
  ENDMETHOD.

  METHOD zif_pia_20_dev_backend~run_tests.
    DATA lt_t TYPE string_table.
    DATA lv_json TYPE string.
    DATA lv_state TYPE string.
    DATA lv_counts TYPE string.
    LOOP AT it_classes INTO DATA(lv_cls).
      APPEND `{"type":"CLAS","name":"` && to_upper( lv_cls ) && `"}` TO lt_t.
    ENDLOOP.
    lv_json = `{"targets":[` && concat_lines_of( table = lt_t sep = `,` ) && `]`.
    IF iv_expected_generation IS NOT INITIAL.
      lv_json = lv_json && `,"expected_generation":"` && iv_expected_generation && `"`.
    ENDIF.
    lv_json = lv_json && `}`.
    TRY.
        rs_-source = zcl_osd_adt_host=>store( iv_command = 'RUN_TESTS' iv_json = lv_json )-json.
        lv_state = zcl_pia_00_json_util=>extract_str( iv_json = rs_-source iv_name = 'state' ).
        lv_counts = zcl_pia_00_json_util=>extract_balanced(
          iv_json = rs_-source iv_key = 'counts' iv_open = '{' iv_close = '}' ).
        rs_-ok = xsdbool( lv_state = 'ran'
                          AND lv_counts CS '"fail":0' AND lv_counts CS '"error":0'
                          AND rs_-source NS '"state":"error"' ).
        IF lv_state = 'ran'.
          rs_-message = |tests ran: { lv_counts }|.
        ELSE.
          rs_-message = |tests { lv_state }: { zcl_pia_00_json_util=>extract_str( iv_json = rs_-source iv_name = 'code' ) }|.
        ENDIF.
      CATCH cx_root INTO DATA(lx).
        rs_-ok = abap_false.
        rs_-message = |run_tests error: { lx->get_text( ) }|.
    ENDTRY.
  ENDMETHOD.

  METHOD zif_pia_20_dev_backend~get_activation_status.
    CLEAR rs_.
    TRY.
        DATA(lv_json) = '{"op_id":"' && iv_op_id && '"}'.
        DATA(ls) = zcl_osd_adt_host=>store(
          iv_command = 'ACTIVATION_STATUS'
          iv_json    = lv_json ).

        rs_-state = zcl_pia_00_json_util=>extract_str(
          iv_json = ls-json iv_name = 'state' ).
        rs_-op_id = iv_op_id.
        rs_-generation_id = zcl_pia_00_json_util=>extract_str(
          iv_json = ls-json iv_name = 'generation_id' ).
        rs_-failure_stage = zcl_pia_00_json_util=>extract_str(
          iv_json = ls-json iv_name = 'failure_stage' ).
        rs_-issues = zcl_pia_00_json_util=>extract_balanced(
          iv_json = ls-json iv_key = 'issues' iv_open = '[' iv_close = ']' ).
        rs_-ok = xsdbool( rs_-state = 'published' ).
      CATCH cx_root INTO DATA(lx).
        " unknown/expired op_id is NOT_FOUND, not a backend error
        rs_-ok = abap_false.
        rs_-op_id = iv_op_id.
        rs_-issues = lx->get_text( ).
        IF rs_-issues CS 'not found'.
          rs_-state = 'not_found'.
        ELSE.
          rs_-state = 'error'.
        ENDIF.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.

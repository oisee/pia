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
          iv_include = 'main'
          iv_source  = iv_source ).
        rs_-ok = abap_true.
        rs_-message = |written { iv_name } ({ strlen( iv_source ) } chars)|.
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
        rs_-ok = xsdbool( rs_-state = 'published' ).
      CATCH cx_root INTO DATA(lx).
        rs_-ok = abap_false.
        rs_-state = 'error'.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.

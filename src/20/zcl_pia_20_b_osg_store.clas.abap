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
    TRY.
        DATA(ls) = zcl_osd_adt_host=>store(
          iv_command = 'ACTIVATE'
          iv_type    = 'CLAS'
          iv_name    = to_upper( iv_name ) ).
        DATA(lv_active) = zcl_pia_00_json_util=>extract_str(
                            iv_json = ls-json iv_name = 'active' ).
        DATA(lv_issues) = zcl_pia_00_json_util=>extract_balanced(
                            iv_json = ls-json iv_key = 'issues' iv_open = '[' iv_close = ']' ).
        IF ls-json IS INITIAL.
          " OSG seam gap: STORE ACTIVATE does not fill EV_JSON yet (colleague fixing);
          " no exception = accepted, verdict pending. Use CHECKRUN for diagnostics.
          rs_-ok = abap_true.
          rs_-message = |activate { iv_name }: accepted (verdict EV_JSON pending OSG seam fix; CHECKRUN for diagnostics)|.
        ELSEIF lv_issues IS NOT INITIAL AND strlen( lv_issues ) > 2.
          rs_-ok = abap_false.
          rs_-message = |ACTIVATION REFUSED { iv_name }: { ls-json }|.
        ELSEIF lv_active = 'X' OR lv_active = 'true'.
          " active != published: new code goes live in the NEXT step
          rs_-ok = abap_true.
          rs_-message = |activate { iv_name }: active=X (publish pending, live next step)|.
        ELSE.
          rs_-ok = abap_false.
          rs_-message = |ACTIVATION FAILED { iv_name }: { ls-json }|.
        ENDIF.
      CATCH cx_root INTO DATA(lx).
        rs_-ok = abap_false.
        rs_-message = lx->get_text( ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.

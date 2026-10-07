CLASS zcl_pia_15_self_guard DEFINITION PUBLIC FINAL CREATE PUBLIC.

  " Insurance for self-hosting: PIA may change the code it runs on. Before the first write to one of its own
  " objects (ZCL_PIA_*, ZIF_PIA_*) the write tools keep the current source in a backup file next to pia.env.
  " At the start of every turn, while backups exist, a self-check parses a fixed LLM response with the code
  " that is now live. If PIA can no longer read its own tool calls, the backups are written and activated
  " again and the turn ends with a note to the model; if the check passes, the backups are dropped.
  PUBLIC SECTION.
    CLASS-METHODS remember
      IMPORTING io_backend TYPE REF TO zif_pia_20_dev_backend
                iv_name    TYPE string
                iv_include TYPE string OPTIONAL.

    " '' when nothing was rolled back; otherwise what failed and what was restored
    " iv_failure: a failure seen at runtime (e.g. the LLM refused the request): restore without the parse check
    CLASS-METHODS check_and_restore
      IMPORTING io_backend TYPE REF TO zif_pia_20_dev_backend
                iv_failure TYPE string OPTIONAL
      RETURNING VALUE(rv_) TYPE string.

    " the self-check alone: '' when tool calls still parse
    CLASS-METHODS self_check RETURNING VALUE(rv_) TYPE string.

  PRIVATE SECTION.
    CONSTANTS c_index TYPE string VALUE `pia-backups.txt`.
    CLASS-METHODS backup_file
      IMPORTING iv_name    TYPE string
                iv_include TYPE string
      RETURNING VALUE(rv_) TYPE string.

ENDCLASS.

CLASS zcl_pia_15_self_guard IMPLEMENTATION.

  METHOD backup_file.
    rv_ = |pia-backup-{ to_lower( iv_name ) }-{ COND string( WHEN iv_include IS INITIAL THEN `main` ELSE to_lower( iv_include ) ) }.abap|.
  ENDMETHOD.

  METHOD remember.
    DATA(lv_name) = to_upper( iv_name ).
    IF lv_name NP 'ZCL_PIA_*' AND lv_name NP 'ZIF_PIA_*'.
      RETURN.
    ENDIF.
    DATA(lv_include) = COND string( WHEN iv_include IS INITIAL OR to_lower( iv_include ) = `main` THEN `` ELSE to_lower( iv_include ) ).
    DATA(lv_entry) = lv_name && cl_abap_char_utilities=>horizontal_tab && lv_include.
    DATA(lt_index) = zcl_pia_00_session_store=>read_lines( c_index ).
    READ TABLE lt_index WITH KEY table_line = lv_entry TRANSPORTING NO FIELDS.
    IF sy-subrc = 0.
      RETURN.   " the oldest version since the last good check is the one to go back to
    ENDIF.
    DATA(ls_read) = io_backend->read_object( iv_name = lv_name iv_include = lv_include ).
    DATA lt_src TYPE string_table.
    IF ls_read-ok = abap_true.
      SPLIT ls_read-source AT cl_abap_char_utilities=>newline INTO TABLE lt_src.
    ENDIF.
    " a new include has no previous source: an empty backup restores it as empty
    zcl_pia_00_session_store=>write_lines( iv_file = backup_file( iv_name = lv_name iv_include = lv_include ) it_ = lt_src ).
    zcl_pia_00_session_store=>append_line( iv_file = c_index iv_line = lv_entry ).
  ENDMETHOD.

  METHOD self_check.
    " two calls as the LLM sends them (Responses and Chat); the arguments must come back exactly
    DATA(lv_a1) = `{"name":"ZCL_PIA_DEMO"}`.
    DATA(lv_a2) = `{"name":"ZCL_PIA_DEMO","source":"x = 1."}`.
    DATA(lv_e1) = zcl_pia_00_json_util=>escape( lv_a1 ).
    DATA(lv_e2) = zcl_pia_00_json_util=>escape( lv_a2 ).
    DATA(lv_resp) = `{"output":[{"type":"function_call","name":"read_object","arguments":"` && lv_e1
      && `","call_id":"c1","status":"completed"},{"type":"function_call","name":"write_source","arguments":"` && lv_e2
      && `","call_id":"c2","status":"completed"}],"status":"completed"}`.
    DATA(lv_chat) = `{"choices":[{"message":{"role":"assistant","content":"","tool_calls":[`
      && `{"id":"c1","type":"function","function":{"name":"read_object","arguments":"` && lv_e1 && `"}},`
      && `{"id":"c2","type":"function","function":{"name":"write_source","arguments":"` && lv_e2 && `"}}]}}]}`.
    TRY.
        DATA(lt_r) = zcl_pia_00_llm_http=>parse_calls_responses( lv_resp ).
        DATA(lt_c) = zcl_pia_00_llm_http=>parse_calls_chat( lv_chat ).
      CATCH cx_root INTO DATA(lx).
        rv_ = |parsing tool calls raised { lx->get_text( ) }|.
        RETURN.
    ENDTRY.
    IF lines( lt_r ) <> 2 OR lt_r[ 1 ]-name <> `read_object` OR lt_r[ 1 ]-arguments <> lv_a1 OR lt_r[ 2 ]-arguments <> lv_a2.
      rv_ = |a Responses answer with two function_call items (arguments { lv_a1 } and { lv_a2 }) gave { lines( lt_r ) } calls|
         && COND string( WHEN lines( lt_r ) > 0 THEN |, call 1 { lt_r[ 1 ]-name } with arguments [{ lt_r[ 1 ]-arguments }]| ).
      RETURN.
    ENDIF.
    IF lines( lt_c ) <> 2 OR lt_c[ 1 ]-arguments <> lv_a1 OR lt_c[ 2 ]-arguments <> lv_a2.
      rv_ = |a Chat answer with two tool_calls (arguments { lv_a1 } and { lv_a2 }) gave { lines( lt_c ) } calls|
         && COND string( WHEN lines( lt_c ) > 0 THEN |, call 1 with arguments [{ lt_c[ 1 ]-arguments }]| ).
    ENDIF.
  ENDMETHOD.

  METHOD check_and_restore.
    DATA(lt_index) = zcl_pia_00_session_store=>read_lines( c_index ).
    DELETE lt_index WHERE table_line IS INITIAL.
    IF lt_index IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lv_fail) = COND string( WHEN iv_failure IS NOT INITIAL THEN iv_failure ELSE self_check( ) ).
    IF lv_fail IS INITIAL.
      " the live code still works: the backups are not needed any more
      zcl_pia_00_session_store=>write_lines( iv_file = c_index it_ = VALUE #( ) ).
      RETURN.
    ENDIF.
    DATA lt_done TYPE string_table.
    LOOP AT lt_index INTO DATA(lv_entry).
      DATA lv_name TYPE string.
      DATA lv_include TYPE string.
      SPLIT lv_entry AT cl_abap_char_utilities=>horizontal_tab INTO lv_name lv_include.
      DATA(lt_src) = zcl_pia_00_session_store=>read_lines( backup_file( iv_name = lv_name iv_include = lv_include ) ).
      DATA(lv_src) = concat_lines_of( table = lt_src sep = cl_abap_char_utilities=>newline ).
      DATA(ls_w) = io_backend->write_source( iv_name = lv_name iv_source = lv_src iv_include = lv_include ).
      APPEND |{ lv_name }{ COND string( WHEN lv_include IS NOT INITIAL THEN | { lv_include }| ) }|
          && COND string( WHEN ls_w-ok = abap_false THEN | (restore failed: { ls_w-message })| ) TO lt_done.
    ENDLOOP.
    LOOP AT lt_index INTO lv_entry.
      SPLIT lv_entry AT cl_abap_char_utilities=>horizontal_tab INTO lv_name lv_include.
      io_backend->activate( lv_name ).
    ENDLOOP.
    zcl_pia_00_session_store=>write_lines( iv_file = c_index it_ = VALUE #( ) ).
    rv_ = |after your change to your own code: { lv_fail }. |
       && |So that you can work again, the previous versions were written back and activated: { concat_lines_of( table = lt_done sep = `, ` ) }. |
       && `They go live when this turn ends. Make the change again so that tool calls still parse at every step.`.
  ENDMETHOD.

ENDCLASS.

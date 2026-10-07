CLASS zcl_pia_00_executor DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES: BEGIN OF ts_result,
             answer     TYPE string,
             iterations TYPE i,
             tool_calls TYPE i,
             ok         TYPE abap_bool,
             error      TYPE string,
           END OF ts_result.

    CLASS-METHODS new
      IMPORTING io_llm      TYPE REF TO zif_pia_00_llm
                io_registry TYPE REF TO zcl_pia_00_registry
                io_session  TYPE REF TO zcl_pia_00_session
                io_listener TYPE REF TO zif_pia_00_listener OPTIONAL
      RETURNING VALUE(ro_)  TYPE REF TO zcl_pia_00_executor.

    METHODS run
      IMPORTING iv_task           TYPE string
                iv_system         TYPE string
                iv_max_iterations TYPE i DEFAULT 8
                iv_continue       TYPE abap_bool DEFAULT abap_false
      RETURNING VALUE(rs_)        TYPE ts_result.

  PRIVATE SECTION.
    DATA mo_llm      TYPE REF TO zif_pia_00_llm.
    DATA mo_registry TYPE REF TO zcl_pia_00_registry.
    DATA mo_session  TYPE REF TO zcl_pia_00_session.
    DATA mo_listener TYPE REF TO zif_pia_00_listener.

    METHODS fire
      IMPORTING iv_type TYPE string
                iv_data TYPE string DEFAULT ''.

ENDCLASS.

CLASS zcl_pia_00_executor IMPLEMENTATION.

  METHOD new.
    ro_ = NEW #( ).
    ro_->mo_llm = io_llm.
    ro_->mo_registry = io_registry.
    ro_->mo_session = io_session.
    ro_->mo_listener = io_listener.
  ENDMETHOD.

  METHOD fire.
    IF mo_listener IS BOUND.
      TRY.
          mo_listener->on_event( iv_type = iv_type iv_data = iv_data ).
        CATCH cx_root.
      ENDTRY.
    ENDIF.
  ENDMETHOD.

  METHOD run.
    IF iv_continue = abap_false.
      mo_session->push_message( iv_role = 'system' iv_content = iv_system ).
    ENDIF.
    mo_session->push_message( iv_role = 'user' iv_content = iv_task ).
    mo_session->evt( 'session_start' ).

    " the iteration limit is per turn; the session keeps the running total
    DATA lv_iter TYPE i.
    DATA(lv_tools0) = mo_session->mv_tool_calls.
    WHILE lv_iter < iv_max_iterations.
      lv_iter = lv_iter + 1.
      mo_session->inc_iteration( ).

      mo_llm->chat(
        EXPORTING
          it_messages   = mo_session->get_messages( )
          iv_tools_json = mo_registry->get_tools_json_openai( )
        IMPORTING
          et_calls          = DATA(lt_calls)
          ev_answer         = DATA(lv_answer)
          ev_assistant_raw  = DATA(lv_raw)
          ev_status         = DATA(lv_status)
          ev_error          = DATA(lv_error) ).

      IF lv_error IS NOT INITIAL.
        rs_-ok = abap_false.
        rs_-error = lv_error.
        mo_session->evt( |llm_error { lv_error }| ).
        RETURN.
      ENDIF.

      IF lt_calls IS INITIAL.
        fire( iv_type = 'answer' iv_data = lv_answer ).
        rs_-answer = lv_answer.
        rs_-ok = abap_true.
        rs_-iterations = lv_iter.
        rs_-tool_calls = mo_session->mv_tool_calls - lv_tools0.
        mo_session->push_message( iv_role = 'assistant' iv_content = lv_answer ).
        mo_session->evt( 'turn_complete' ).
        RETURN.
      ENDIF.

      mo_session->push_message( iv_role = 'assistant' iv_content = lv_raw ).

      LOOP AT lt_calls INTO DATA(ls_call).
        mo_session->inc_tool_call( ).
        mo_session->evt( |tool_started { ls_call-name }| ).
        fire( iv_type = 'tool_start' iv_data = |{ ls_call-name } { ls_call-arguments }| ).

        DATA(ls_result) = mo_registry->invoke_call( ls_call ).

        mo_session->log_tool(
          iv_tool = ls_call-name iv_args = ls_call-arguments
          iv_ok = ls_result-ok iv_output = ls_result-output ).

        DATA lv_out TYPE string.
        lv_out = ls_result-output.
        " 8000 cut PIA's own larger classes (json_util, llm_http) in read_object, so the agent could not
        " write them back in full (found by the first F1 run); 60000 still bounds a runaway tool
        IF strlen( lv_out ) > 60000.
          lv_out = lv_out+0(60000) && '...[truncated]'.
        ENDIF.

        mo_session->push_message(
          iv_role = 'tool'
          iv_content = '"tool_call_id":"' && ls_call-id &&
                       '","content":"' && zcl_pia_00_json_util=>escape( lv_out ) && '"' ).

        mo_session->evt( |tool_finished { ls_call-name } ok={ ls_result-ok }| ).
        fire( iv_type = 'tool_done' iv_data = ls_call-name && COND #( WHEN ls_result-ok = abap_true THEN ' ok' ELSE ' FAIL' ) ).
      ENDLOOP.
    ENDWHILE.

    rs_-ok = abap_true.
    rs_-answer = 'MAX ITERATIONS REACHED'.
    rs_-iterations = lv_iter.
    rs_-tool_calls = mo_session->mv_tool_calls - lv_tools0.
  ENDMETHOD.

ENDCLASS.

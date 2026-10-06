CLASS zcl_pia_30_f_tui_apc DEFINITION
  PUBLIC
  INHERITING FROM cl_apc_wsp_ext_stateful_base
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS if_apc_wsp_extension~on_accept REDEFINITION.
    METHODS if_apc_wsp_extension~on_start REDEFINITION.
    METHODS if_apc_wsp_extension~on_message REDEFINITION.
    METHODS if_apc_wsp_extension~on_close REDEFINITION.
    METHODS if_apc_wsp_extension~on_error REDEFINITION.
    CLASS-METHODS class_constructor.

  PRIVATE SECTION.
    CONSTANTS c_crlf TYPE string VALUE cl_abap_char_utilities=>cr_lf.
    CLASS-DATA gv_esc   TYPE string.
    CLASS-DATA gv_cyan  TYPE string.
    CLASS-DATA gv_green TYPE string.
    CLASS-DATA gv_dim   TYPE string.
    CLASS-DATA gv_red   TYPE string.
    CLASS-DATA gv_bold  TYPE string.
    CLASS-DATA gv_reset TYPE string.

    DATA mo_msg_mgr TYPE REF TO if_apc_wsp_message_manager.
    DATA mv_running TYPE abap_bool.
    DATA mv_started TYPE abap_bool.

    CLASS-DATA go_session  TYPE REF TO zcl_pia_00_session.
    CLASS-DATA go_registry TYPE REF TO zcl_pia_00_registry.
    CLASS-DATA go_llm      TYPE REF TO zif_pia_00_llm.

    METHODS send IMPORTING iv_text TYPE string.
    METHODS boot.
    METHODS run_task IMPORTING iv_task TYPE string.

ENDCLASS.

CLASS zcl_pia_30_f_tui_apc IMPLEMENTATION.

  METHOD class_constructor.
    DATA lv_xstr TYPE xstring.
    lv_xstr = '1B'.
    gv_esc = cl_abap_conv_codepage=>create_in( )->convert( source = lv_xstr ).
    gv_cyan   = gv_esc && '[36m'.
    gv_green  = gv_esc && '[32m'.
    gv_dim    = gv_esc && '[2m'.
    gv_red    = gv_esc && '[31m'.
    gv_bold   = gv_esc && '[1m'.
    gv_reset  = gv_esc && '[0m'.
  ENDMETHOD.

  METHOD if_apc_wsp_extension~on_accept.
    e_connect_mode = co_connect_mode_accept.
  ENDMETHOD.

  METHOD if_apc_wsp_extension~on_start.
    mo_msg_mgr = i_message_manager.
    mv_running = abap_false.
    boot( ).
    send( |{ gv_bold }{ gv_cyan }PIA - pi, writing itself in ABAP{ gv_reset }{ c_crlf }| ).
    send( gv_dim && 'Tools: read/write/activate' && gv_reset && c_crlf ).
    send( |{ gv_dim }Type a task and press Enter{ gv_reset }{ c_crlf }{ c_crlf }| ).
  ENDMETHOD.

  METHOD if_apc_wsp_extension~on_message.
    TRY.
        DATA(lv_input) = i_message->get_text( ).
        IF lv_input IS INITIAL. RETURN. ENDIF.
        IF mv_running = abap_true.
          send( |{ gv_red }Still processing...{ gv_reset }{ c_crlf }| ).
          RETURN.
        ENDIF.
        run_task( lv_input ).
      CATCH cx_apc_error.
    ENDTRY.
  ENDMETHOD.

  METHOD if_apc_wsp_extension~on_close.
  ENDMETHOD.

  METHOD if_apc_wsp_extension~on_error.
  ENDMETHOD.

  METHOD boot.
    IF go_session IS BOUND. RETURN. ENDIF.
    DATA(lo_backend) = zcl_pia_20_b_osg_store=>new( ).
    go_registry = zcl_pia_00_registry=>new( ).
    DATA(lo_read) = NEW zcl_pia_10_t_read_object( ).
    lo_read->set_backend( lo_backend ).
    go_registry->register( lo_read ).
    DATA(lo_write) = NEW zcl_pia_15_t_write_source( ).
    lo_write->set_backend( lo_backend ).
    go_registry->register( lo_write ).
    DATA(lo_act) = NEW zcl_pia_15_t_activate( ).
    lo_act->set_backend( lo_backend ).
    go_registry->register( lo_act ).
    go_llm = zcl_pia_00_llm_http=>new( VALUE #(
      base_url = 'https://api.z.ai/api/v1/responses'
      model    = 'glm-5.3-flash'
      api_key  = 'd8***********************************************'
      api_type = 'responses' ) ).
    go_session = zcl_pia_00_session=>new( 'tui' ).
  ENDMETHOD.

  METHOD run_task.
    mv_running = abap_true.
    send( |{ c_crlf }{ gv_cyan }{ gv_bold }Task:{ gv_reset } { iv_task }{ c_crlf }{ c_crlf }| ).

    DATA(lo_exec) = zcl_pia_00_executor=>new(
      io_llm      = go_llm
      io_registry = go_registry
      io_session  = go_session ).

    " stream tool events: check events before/after
    DATA(lv_ev_before) = lines( go_session->get_events( ) ).

    DATA(ls_result) = lo_exec->run(
      iv_task = iv_task
      iv_system = 'You are PIA, an ABAP coding agent inside an ABAP runtime. '
               && 'Tools: read_object(name), write_source(name, source - FULL source), activate(name). '
               && 'Rules: read before write; write full source; always activate after write; '
               && 'new code goes live NEXT step. Answer briefly in the user language.'
      iv_max_iterations = 8
      iv_continue = abap_true ).

    " stream tool trace
    LOOP AT go_session->get_trace( ) INTO DATA(ls_t).
      DATA(lv_status) = COND #( WHEN ls_t-ok = abap_true THEN '{ gv_green }ok{ gv_reset }'
                                ELSE '{ gv_red }FAIL{ gv_reset }' ).
      send( |  { gv_dim }[{ ls_t-tool }] { lv_status }: { ls_t-args }{ gv_reset }{ c_crlf }| ).
    ENDLOOP.

    send( |{ c_crlf }{ gv_green }{ ls_result-answer }{ gv_reset }{ c_crlf }{ c_crlf }| ).
    send( |{ gv_dim }iters={ ls_result-iterations } tools={ ls_result-tool_calls }{ gv_reset }{ c_crlf }| ).
    mv_running = abap_false.
  ENDMETHOD.

  METHOD send.
    TRY.
        DATA(lo_msg) = mo_msg_mgr->create_message( ).
        lo_msg->set_text( iv_text ).
        mo_msg_mgr->send( lo_msg ).
      CATCH cx_apc_error.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.

CLASS zcl_pia_30_f_tui_apc DEFINITION
  PUBLIC
  INHERITING FROM cl_apc_wsp_ext_stateful_base
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_pia_00_listener.
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
    CLASS-DATA gv_done  TYPE string.  " OSC marker: turn finished (stops the client status line)

    DATA mo_msg_mgr TYPE REF TO if_apc_wsp_message_manager.
    DATA mv_running TYPE abap_bool.
    DATA mv_started TYPE abap_bool.
    DATA mv_bound   TYPE abap_bool.   " AMC consumer bound: tool events arrive live

    DATA mo_session TYPE REF TO zcl_pia_00_session.   " one conversation per connection
    CLASS-DATA go_registry TYPE REF TO zcl_pia_00_registry.
    CLASS-DATA go_llm      TYPE REF TO zif_pia_00_llm.
    CLASS-DATA gv_backend  TYPE string.

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
    lv_xstr = '07'.
    gv_done   = gv_esc && ']777;pia-done' && cl_abap_conv_codepage=>create_in( )->convert( source = lv_xstr ).
  ENDMETHOD.

  METHOD if_apc_wsp_extension~on_accept.
    e_connect_mode = co_connect_mode_accept.
  ENDMETHOD.

  METHOD if_apc_wsp_extension~on_start.
    mo_msg_mgr = i_message_manager.
    mv_running = abap_false.

    " Bind AMC consumer: Node.js broker pushes events to WebSocket
    TRY.
        DATA(lo_binding) = i_context->get_binding_manager( ).
        lo_binding->bind_amc_message_consumer(
          i_application_id = 'ZPIA_AMC'
          i_channel_id     = '/events' ).
        mv_bound = abap_true.
      CATCH cx_root INTO DATA(lx_bind).
        mv_bound = abap_false.
        send( |{ gv_red }live events off: { lx_bind->get_text( ) }{ gv_reset }{ c_crlf }| ).
    ENDTRY.

    boot( ).
    send( |{ gv_bold }{ gv_cyan }PIA - pi, writing itself in ABAP{ gv_reset }{ c_crlf }| ).
    send( |{ gv_dim }Tools: read/write/activate/run_tests · backend { gv_backend } · live events { COND string( WHEN mv_bound = abap_true THEN `on` ELSE `off` ) }{ gv_reset }{ c_crlf }| ).
    send( |{ gv_dim }Type a task and press Enter{ gv_reset }{ c_crlf }{ c_crlf }| ).
  ENDMETHOD.

  METHOD if_apc_wsp_extension~on_message.
    mo_msg_mgr = i_message_manager.
    TRY.
        DATA(lv_input) = i_message->get_text( ).
        IF lv_input IS INITIAL. RETURN. ENDIF.
        IF mv_running = abap_true.
          send( |{ gv_red }Still processing...{ gv_reset }{ c_crlf }| ).
          RETURN.
        ENDIF.
        run_task( lv_input ).
      CATCH cx_root INTO DATA(lx).
        mv_running = abap_false.
        send( |{ c_crlf }{ gv_red }ERROR: { lx->get_text( ) }{ gv_reset }{ c_crlf }| ).
    ENDTRY.
    send( gv_done ).
  ENDMETHOD.

  METHOD zif_pia_00_listener~on_event.
    CASE iv_type.
      WHEN 'tool_start'.
        send( gv_dim && `  > ` && iv_data && gv_reset && c_crlf ).
      WHEN 'tool_done'.
        send( gv_green && `  < ` && iv_data && gv_reset && c_crlf ).
      WHEN 'answer'.
        send( c_crlf && gv_green && iv_data && gv_reset && c_crlf ).
    ENDCASE.
  ENDMETHOD.

  METHOD if_apc_wsp_extension~on_close.
  ENDMETHOD.

  METHOD if_apc_wsp_extension~on_error.
  ENDMETHOD.

  METHOD boot.
    IF mo_session IS NOT BOUND.
      mo_session = zcl_pia_00_session=>new( 'tui' ).
    ENDIF.
    IF go_registry IS BOUND. RETURN. ENDIF.
    DATA(lo_backend) = zcl_pia_20_backend=>default( ).
    gv_backend = lo_backend->get_name( ).
    go_registry = zcl_pia_00_registry=>new( ).
    zcl_pia_15_toolset=>register_dev_tools( io_registry = go_registry io_backend = lo_backend ).
    go_llm = zcl_pia_00_llm_http=>new( VALUE #(
      base_url = 'https://api.z.ai/api/v1/responses'
      model    = zcl_pia_00_config=>model( )
      api_key  = zcl_pia_00_config=>get( `ZAI_API_KEY` )
      api_type = 'responses' ) ).
  ENDMETHOD.

  METHOD run_task.
    mv_running = abap_true.

    DATA(lo_amc) = zcl_pia_00_amc_listener=>new( ).
    DATA(lo_exec) = zcl_pia_00_executor=>new(
      io_llm      = go_llm
      io_registry = go_registry
      io_session  = mo_session
      io_listener = lo_amc ).

    " stream tool events: check events before/after
    DATA(lv_ev_before) = lines( mo_session->get_events( ) ).

    DATA(ls_result) = lo_exec->run(
      iv_task = iv_task
      iv_system = 'You are PIA, an ABAP coding agent inside an ABAP runtime. '
               && 'Tools: read_object(name), write_source(name, source - FULL source, include main|testclasses), activate(name), run_tests(name). '
               && 'Rules: read before write; write full source; always activate after write; '
               && 'new code goes live NEXT step, so after activate finish the turn and run_tests in the next turn. Answer briefly in the user language.'
      iv_max_iterations = 8
      iv_continue = abap_true ).

    " post-fact tool trace, only when events did not arrive live
    IF mv_bound = abap_true AND lo_amc->is_streaming( ) = abap_true.
      CLEAR lv_ev_before.
    ELSE.
    LOOP AT mo_session->get_trace( ) INTO DATA(ls_t).
      DATA(lv_status) = COND string( WHEN ls_t-ok = abap_true THEN |{ gv_green }ok{ gv_reset }|
                                     ELSE |{ gv_red }FAIL{ gv_reset }| ).
      send( |  { gv_dim }[{ ls_t-tool }] { lv_status }: { ls_t-args }{ gv_reset }{ c_crlf }| ).
    ENDLOOP.
    ENDIF.

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

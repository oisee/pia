CLASS zcl_pia_30_f_tui_apc DEFINITION
  PUBLIC
  INHERITING FROM cl_apc_wsp_ext_stateful_base
  CREATE PUBLIC.

  " Terminal push channel. The browser keeps a session id (?sid=...) so a conversation
  " survives reconnects; the turn itself runs in zcl_pia_30_turn, and everything it says
  " arrives over AMC (channel extension = sid). PIA_TURN_MODE in pia.env picks where the
  " turn runs: inline (in this handler; OSG only), job (background job) or daemon.
  " Default: job on SAP, inline elsewhere. On SAP the handler itself may not run ABAP Unit
  " or write sources ("Invalid statement in ABAP push channel").

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
    CLASS-DATA gv_done  TYPE string.  " OSC marker: turn finished (stops the client status line)

    DATA mo_msg_mgr TYPE REF TO if_apc_wsp_message_manager.
    DATA mv_bound   TYPE abap_bool.   " AMC consumer bound: the turn's output arrives
    DATA mv_sid     TYPE string.
    DATA mv_mode    TYPE string.
    DATA mv_backend TYPE string.

    METHODS send IMPORTING iv_text TYPE string.
    METHODS read_sid IMPORTING io_context TYPE REF TO if_apc_wsp_server_context.
    METHODS start_turn IMPORTING iv_task TYPE string.

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

  METHOD read_sid.
    TRY.
        mv_sid = io_context->get_initial_request( )->get_form_field( `sid` ).
      CATCH cx_root.
        CLEAR mv_sid.
    ENDTRY.
    IF zcl_pia_00_session_store=>is_valid_sid( mv_sid ) = abap_false.
      TRY.
          mv_sid = substring( val = cl_system_uuid=>create_uuid_c32_static( ) len = 22 ).
        CATCH cx_root.
          mv_sid = |S{ sy-uzeit }{ sy-datum }|.
      ENDTRY.
    ENDIF.
  ENDMETHOD.

  METHOD if_apc_wsp_extension~on_start.
    mo_msg_mgr = i_message_manager.
    read_sid( i_context ).
    mv_backend = zcl_pia_20_backend=>default( )->get_name( ).
    " ?mode=job|daemon|inline overrides PIA_TURN_MODE for this connection (to compare the two)
    TRY.
        mv_mode = to_lower( i_context->get_initial_request( )->get_form_field( `mode` ) ).
      CATCH cx_root.
        CLEAR mv_mode.
    ENDTRY.
    IF mv_mode IS INITIAL.
      mv_mode = to_lower( zcl_pia_00_config=>get( `PIA_TURN_MODE` ) ).
    ENDIF.
    IF mv_mode <> `inline` AND mv_mode <> `job` AND mv_mode <> `daemon`.
      mv_mode = COND #( WHEN mv_backend = `SAP-ADT` THEN `job` ELSE `inline` ).
    ENDIF.

    " this session's channel: the turn publishes there wherever it runs
    TRY.
        i_context->get_binding_manager( )->bind_amc_message_consumer(
          i_application_id       = 'ZPIA_AMC'
          i_channel_id           = '/events'
          i_channel_extension_id = CONV #( mv_sid ) ).
        mv_bound = abap_true.
      CATCH cx_root INTO DATA(lx_bind).
        mv_bound = abap_false.
        send( |{ gv_red }live events off: { lx_bind->get_text( ) }{ gv_reset }{ c_crlf }| ).
    ENDTRY.

    DATA(lv_earlier) = lines( zcl_pia_00_session_store=>load( mv_sid )->get_messages( ) ).
    send( |{ gv_bold }{ gv_cyan }PIA - pi, writing itself in ABAP{ gv_reset }{ c_crlf }| ).
    send( |{ gv_dim }Tools: read/write/activate/run_tests · backend { mv_backend } · turns { mv_mode }|
       && | · live events { COND string( WHEN mv_bound = abap_true THEN `on` ELSE `off` ) }{ gv_reset }{ c_crlf }| ).
    send( |{ gv_dim }session { mv_sid }{ COND string( WHEN lv_earlier > 0 THEN | · resumed, { lv_earlier } earlier messages| ) }|
       && | · /new starts a fresh one{ gv_reset }{ c_crlf }| ).
    send( |{ gv_dim }Type a task and press Enter{ gv_reset }{ c_crlf }{ c_crlf }| ).
  ENDMETHOD.

  METHOD if_apc_wsp_extension~on_message.
    mo_msg_mgr = i_message_manager.
    TRY.
        DATA(lv_input) = i_message->get_text( ).
        IF lv_input IS INITIAL OR lv_input = `/hb`.
          RETURN. " heartbeat: keeps ICM from closing an idle WebSocket after 120 s
        ENDIF.
        start_turn( lv_input ).
      CATCH cx_root INTO DATA(lx).
        send( |{ c_crlf }{ gv_red }ERROR: { lx->get_text( ) }{ gv_reset }{ c_crlf }| ).
        send( gv_done ).
    ENDTRY.
  ENDMETHOD.

  METHOD start_turn.
    DATA lv_error TYPE string.
    zcl_pia_00_session_store=>put_task( iv_sid = mv_sid iv_task = iv_task ).
    CASE mv_mode.
      WHEN `job`.
        lv_error = zcl_pia_30_turn=>start_job( mv_sid ).
      WHEN `daemon`.
        " dynamic: the daemon class is SAP-only (OSG's daemon interface lacks co_setup_mode)
        TRY.
            CALL METHOD ('ZCL_PIA_30_TURN_DAEMON')=>('START_TURN')
              EXPORTING iv_sid = mv_sid
              RECEIVING rv_    = lv_error.
          CATCH cx_root INTO DATA(lx_d).
            lv_error = lx_d->get_text( ).
        ENDTRY.
      WHEN OTHERS.
        " inline: output and the done marker still come over AMC
        zcl_pia_30_turn=>run( mv_sid ).
    ENDCASE.
    IF lv_error IS NOT INITIAL.
      send( |{ c_crlf }{ gv_red }ERROR: could not start the turn ({ mv_mode }): { lv_error }{ gv_reset }{ c_crlf }| ).
      send( gv_done ).
    ENDIF.
  ENDMETHOD.

  METHOD if_apc_wsp_extension~on_close.
  ENDMETHOD.

  METHOD if_apc_wsp_extension~on_error.
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

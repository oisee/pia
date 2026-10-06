CLASS zcl_pia_30_turn_daemon DEFINITION PUBLIC INHERITING FROM cl_abap_daemon_ext_base FINAL CREATE PUBLIC.

  " ABAP daemon PIA_TURNS: subscribes to AMC ZPIA_AMC /turns and runs the turn of every session id
  " it receives (zcl_pia_30_turn=>run), one after another. An APC handler may not start or attach a
  " daemon (CL_ABAP_DAEMON_CLIENT is an invalid statement in a push channel), so the terminal only
  " publishes the sid over AMC; the daemon is started outside it (report ZPIA_DAEMON, e.g. as a job).

  PUBLIC SECTION.
    INTERFACES if_amc_message_receiver_text.
    CONSTANTS c_name TYPE string VALUE `PIA_TURNS`.
    METHODS if_abap_daemon_extension~on_accept REDEFINITION.
    METHODS if_abap_daemon_extension~on_message REDEFINITION.
    " the remaining abstract callbacks of CL_ABAP_DAEMON_EXT_BASE: nothing to do
    METHODS if_abap_daemon_extension~on_error REDEFINITION.
    METHODS if_abap_daemon_extension~on_restart REDEFINITION.
    METHODS if_abap_daemon_extension~on_server_shutdown REDEFINITION.
    METHODS if_abap_daemon_extension~on_start REDEFINITION.
    METHODS if_abap_daemon_extension~on_stop REDEFINITION.
    METHODS if_abap_daemon_extension~on_system_shutdown REDEFINITION.
    METHODS if_abap_daemon_extension~on_before_restart_by_system REDEFINITION.
    " starts the daemon when it is not running (not from a push channel); '' or an error text
    CLASS-METHODS ensure_running
      RETURNING VALUE(rv_) TYPE string.
    " from the terminal: hand a session's turn to the daemon over AMC; '' or an error text
    CLASS-METHODS start_turn
      IMPORTING iv_sid     TYPE string
      RETURNING VALUE(rv_) TYPE string.

ENDCLASS.

CLASS zcl_pia_30_turn_daemon IMPLEMENTATION.

  METHOD if_abap_daemon_extension~on_accept.
    e_setup_mode = if_abap_daemon_extension=>co_setup_mode-accept.
  ENDMETHOD.

  METHOD if_abap_daemon_extension~on_message.
    TRY.
        DATA(lv_sid) = i_message->get_field( `sid` ).
        zcl_pia_30_turn=>run( lv_sid ).
      CATCH cx_root.
        RETURN.
    ENDTRY.
  ENDMETHOD.

  METHOD if_abap_daemon_extension~on_error.
  ENDMETHOD.

  METHOD if_abap_daemon_extension~on_restart.
  ENDMETHOD.

  METHOD if_abap_daemon_extension~on_server_shutdown.
  ENDMETHOD.

  METHOD if_abap_daemon_extension~on_start.
    TRY.
        cl_amc_channel_manager=>create_message_consumer(
          i_application_id = 'ZPIA_AMC'
          i_channel_id     = '/turns' )->start_message_delivery( i_receiver = me ).
      CATCH cx_root.
        RETURN.
    ENDTRY.
  ENDMETHOD.

  METHOD if_amc_message_receiver_text~receive.
    TRY.
        zcl_pia_30_turn=>run( condense( i_message ) ).
      CATCH cx_root.
        RETURN.
    ENDTRY.
  ENDMETHOD.

  METHOD if_abap_daemon_extension~on_stop.
  ENDMETHOD.

  METHOD if_abap_daemon_extension~on_system_shutdown.
  ENDMETHOD.

  METHOD if_abap_daemon_extension~on_before_restart_by_system.
  ENDMETHOD.

  METHOD ensure_running.
    TRY.
        DATA(lt_info) = cl_abap_daemon_client_manager=>get_daemon_info( i_class_name = 'ZCL_PIA_30_TURN_DAEMON' ).
        LOOP AT lt_info TRANSPORTING NO FIELDS WHERE name = c_name.
          RETURN.
        ENDLOOP.
        DATA ls_new LIKE LINE OF lt_info.
        cl_abap_daemon_client_manager=>start(
          EXPORTING i_class_name  = 'ZCL_PIA_30_TURN_DAEMON'
                    i_name        = CONV #( c_name )
                    i_priority    = cl_abap_daemon_client_manager=>co_session_priority_low
          IMPORTING e_instance_id = ls_new-instance_id ).
      CATCH cx_root INTO DATA(lx).
        rv_ = lx->get_text( ).
    ENDTRY.
  ENDMETHOD.

  METHOD start_turn.
    TRY.
        CAST if_amc_message_producer_text( cl_amc_channel_manager=>create_message_producer(
          i_application_id = 'ZPIA_AMC'
          i_channel_id     = '/turns' ) )->send( iv_sid ).
      CATCH cx_root INTO DATA(lx).
        rv_ = lx->get_text( ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.

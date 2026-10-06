CLASS zcl_pia_00_amc_listener DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES zif_pia_00_listener.
    " iv_extension: AMC channel extension = session id, so a turn reaches only its own terminal
    CLASS-METHODS new
      IMPORTING iv_extension TYPE string OPTIONAL
      RETURNING VALUE(ro_)   TYPE REF TO zcl_pia_00_amc_listener.
    CLASS-METHODS class_constructor.
    " AMC send authority (SAMC ZPIA_AMC /events, activity S) is checked against THIS class:
    " the program that calls send, on SAP and in OSG alike.
    METHODS is_streaming RETURNING VALUE(rv_) TYPE abap_bool.
    " for turns that run outside the push channel (job, daemon): everything goes over AMC
    METHODS publish_answer IMPORTING iv_ TYPE string.
    METHODS publish_info IMPORTING iv_ TYPE string.
    METHODS publish_error IMPORTING iv_ TYPE string.
    METHODS publish_done.
  PRIVATE SECTION.
    CONSTANTS c_max_args TYPE i VALUE 160.
    CLASS-DATA gv_dim   TYPE string.
    CLASS-DATA gv_green TYPE string.
    CLASS-DATA gv_red   TYPE string.
    CLASS-DATA gv_reset TYPE string.
    CLASS-DATA gv_done  TYPE string.
    DATA mo_producer TYPE REF TO if_amc_message_producer_text.
    DATA mv_error TYPE string.
    METHODS publish IMPORTING iv_ TYPE string.
ENDCLASS.

CLASS zcl_pia_00_amc_listener IMPLEMENTATION.

  METHOD class_constructor.
    DATA lv_xstr TYPE xstring.
    DATA lv_esc TYPE string.
    lv_xstr = '1B'.
    lv_esc = cl_abap_conv_codepage=>create_in( )->convert( source = lv_xstr ).
    gv_dim   = lv_esc && '[2m'.
    gv_green = lv_esc && '[32m'.
    gv_red   = lv_esc && '[31m'.
    gv_reset = lv_esc && '[0m'.
    lv_xstr = '07'.
    gv_done  = lv_esc && ']777;pia-done' && cl_abap_conv_codepage=>create_in( )->convert( source = lv_xstr ).
  ENDMETHOD.

  METHOD new.
    ro_ = NEW #( ).
    TRY.
        ro_->mo_producer ?= cl_amc_channel_manager=>create_message_producer(
          i_application_id       = 'ZPIA_AMC'
          i_channel_id           = '/events'
          i_channel_extension_id = CONV #( iv_extension ) ).
      CATCH cx_root INTO DATA(lx).
        ro_->mv_error = lx->get_text( ).
        CLEAR ro_->mo_producer.
    ENDTRY.
  ENDMETHOD.

  METHOD is_streaming.
    rv_ = xsdbool( mo_producer IS BOUND ).
  ENDMETHOD.

  METHOD zif_pia_00_listener~on_event.
    DATA lv_msg TYPE string.
    DATA lv_data TYPE string.
    IF mo_producer IS NOT BOUND.
      RETURN.
    ENDIF.
    lv_data = iv_data.
    IF strlen( lv_data ) > c_max_args.
      lv_data = substring( val = lv_data len = c_max_args ) && `...`.
    ENDIF.
    CASE iv_type.
      WHEN 'tool_start'.
        lv_msg = |{ gv_dim }  > { lv_data }{ gv_reset }\r\n|.
      WHEN 'tool_done'.
        IF lv_data CS ' FAIL'.
          lv_msg = |{ gv_red }  < { lv_data }{ gv_reset }\r\n|.
        ELSE.
          lv_msg = |{ gv_green }  < { lv_data }{ gv_reset }\r\n|.
        ENDIF.
      WHEN OTHERS.
        RETURN. " the answer is printed by the front end
    ENDCASE.
    publish( lv_msg ).
  ENDMETHOD.

  METHOD publish.
    IF mo_producer IS NOT BOUND.
      RETURN.
    ENDIF.
    TRY.
        mo_producer->send( iv_ ).
      CATCH cx_root INTO DATA(lx).
        " stop after the first refusal instead of failing every event
        mv_error = lx->get_text( ).
        CLEAR mo_producer.
    ENDTRY.
  ENDMETHOD.

  METHOD publish_answer.
    publish( |\r\n{ gv_green }{ iv_ }{ gv_reset }\r\n\r\n| ).
  ENDMETHOD.

  METHOD publish_info.
    publish( |{ gv_dim }{ iv_ }{ gv_reset }\r\n| ).
  ENDMETHOD.

  METHOD publish_error.
    publish( |\r\n{ gv_red }ERROR: { iv_ }{ gv_reset }\r\n| ).
  ENDMETHOD.

  METHOD publish_done.
    publish( gv_done ).
  ENDMETHOD.

ENDCLASS.

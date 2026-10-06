CLASS zcl_pia_00_amc_listener DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES zif_pia_00_listener.
    CLASS-METHODS new RETURNING VALUE(ro_) TYPE REF TO zcl_pia_00_amc_listener.
  PRIVATE SECTION.
    DATA mo_producer TYPE REF TO if_amc_message_producer.
ENDCLASS.

CLASS zcl_pia_00_amc_listener IMPLEMENTATION.

  METHOD new.
    ro_ = NEW #( ).
    TRY.
        ro_->mo_producer = cl_amc_channel_manager=>create_message_producer(
          i_application_id = 'ZPIA_AMC'
          i_channel_id     = '/events' ).
      CATCH cx_root.
        " AMC not available — degrade to no-streaming
        CLEAR ro_->mo_producer.
    ENDTRY.
  ENDMETHOD.

  METHOD zif_pia_00_listener~on_event.
    IF mo_producer IS NOT BOUND.
      RETURN. " no AMC — silent fallback
    ENDIF.
    TRY.
        DATA lv_msg TYPE string.
        CASE iv_type.
          WHEN 'tool_start'.
            lv_msg = |>> { iv_data }|.
          WHEN 'tool_done'.
            lv_msg = |<< { iv_data }|.
          WHEN 'answer'.
            lv_msg = |ANSWER: { iv_data }|.
          WHEN OTHERS.
            RETURN.
        ENDCASE.
        " AMC text producer
        DATA(lo_text) = CAST if_amc_message_producer_text( mo_producer ).
        lo_text->send( lv_msg ).
      CATCH cx_root.
        " silent — AMC is best-effort
    ENDTRY.
  ENDMETHOD.

ENDCLASS.

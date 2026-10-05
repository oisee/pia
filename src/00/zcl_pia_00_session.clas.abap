CLASS zcl_pia_00_session DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES: BEGIN OF ts_message,
             role    TYPE string,
             content TYPE string,
           END OF ts_message.
    TYPES tt_messages TYPE STANDARD TABLE OF ts_message WITH EMPTY KEY.

    TYPES: BEGIN OF ts_trace,
             tool   TYPE string,
             args   TYPE string,
             ok     TYPE abap_bool,
             output TYPE string,
           END OF ts_trace.
    TYPES tt_trace TYPE STANDARD TABLE OF ts_trace WITH EMPTY KEY.

    CLASS-METHODS new
      IMPORTING iv_task       TYPE string OPTIONAL
      RETURNING VALUE(ro_)    TYPE REF TO zcl_pia_00_session.

    METHODS push_message IMPORTING iv_role TYPE string iv_content TYPE string.
    METHODS get_messages  RETURNING VALUE(rt_) TYPE tt_messages.
    METHODS replace_messages IMPORTING it_ TYPE tt_messages.

    METHODS log_tool IMPORTING iv_tool TYPE string iv_args TYPE string
                               iv_ok TYPE abap_bool iv_output TYPE string.
    METHODS get_trace RETURNING VALUE(rt_) TYPE tt_trace.

    METHODS evt IMPORTING iv_ TYPE string.
    METHODS get_events RETURNING VALUE(rt_) TYPE string_table.

    DATA mv_task       TYPE string READ-ONLY.
    DATA mv_iterations TYPE i READ-ONLY.
    DATA mv_tool_calls TYPE i READ-ONLY.

    METHODS inc_iteration.
    METHODS inc_tool_call.

  PRIVATE SECTION.
    DATA mt_messages TYPE tt_messages.
    DATA mt_trace    TYPE tt_trace.
    DATA mt_events   TYPE string_table.

ENDCLASS.

CLASS zcl_pia_00_session IMPLEMENTATION.

  METHOD new.
    ro_ = NEW #( ).
    ro_->mv_task = iv_task.
  ENDMETHOD.

  METHOD push_message.
    APPEND VALUE #( role = iv_role content = iv_content ) TO mt_messages.
  ENDMETHOD.

  METHOD get_messages.
    rt_ = mt_messages.
  ENDMETHOD.

  METHOD replace_messages.
    mt_messages = it_.
  ENDMETHOD.

  METHOD log_tool.
    APPEND VALUE #( tool = iv_tool args = iv_args ok = iv_ok output = iv_output ) TO mt_trace.
  ENDMETHOD.

  METHOD get_trace.
    rt_ = mt_trace.
  ENDMETHOD.

  METHOD evt.
    GET TIME STAMP FIELD DATA(lv_ts).
    APPEND |{ lv_ts } { iv_ }| TO mt_events.
  ENDMETHOD.

  METHOD get_events.
    rt_ = mt_events.
  ENDMETHOD.

  METHOD inc_iteration.
    mv_iterations = mv_iterations + 1.
  ENDMETHOD.

  METHOD inc_tool_call.
    mv_tool_calls = mv_tool_calls + 1.
  ENDMETHOD.

ENDCLASS.

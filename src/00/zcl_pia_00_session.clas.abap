CLASS zcl_pia_00_session DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES ts_message TYPE zif_pia_00_llm=>ts_message.
    TYPES tt_messages TYPE zif_pia_00_llm=>tt_messages.

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

    METHODS to_json RETURNING VALUE(rv_) TYPE string.
    METHODS from_json IMPORTING iv_json TYPE string
                RETURNING VALUE(rv_) TYPE abap_bool.

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

  METHOD to_json.
    " Serialize session state for checkpoint/resume
    DATA lt TYPE string_table.
    APPEND '{"task":"' && zcl_pia_00_json_util=>escape( mv_task ) && '",' TO lt.
    APPEND '"iterations":' && |{ mv_iterations }| && ',' TO lt.
    APPEND '"tool_calls":' && |{ mv_tool_calls }| && ',' TO lt.

    " messages
    APPEND '"messages":[' TO lt.
    DATA lt_m TYPE string_table.
    LOOP AT mt_messages INTO DATA(ls_m).
      APPEND '{"role":"' && ls_m-role && '","content":"' &&
             zcl_pia_00_json_util=>escape( ls_m-content ) && '"}' TO lt_m.
    ENDLOOP.
    APPEND concat_lines_of( table = lt_m sep = ',' ) TO lt.
    APPEND '],' TO lt.

    " trace (compact: just tool names + ok)
    APPEND '"trace":[' TO lt.
    DATA lt_t TYPE string_table.
    LOOP AT mt_trace INTO DATA(ls_t).
      APPEND '{"t":"' && ls_t-tool && '","o":' &&
             COND #( WHEN ls_t-ok = abap_true THEN '1' ELSE '0' ) && '}' TO lt_t.
    ENDLOOP.
    APPEND concat_lines_of( table = lt_t sep = ',' ) TO lt.
    APPEND ']}' TO lt.

    rv_ = concat_lines_of( table = lt ).
  ENDMETHOD.

  METHOD from_json.
    rv_ = abap_false.
    CLEAR: mt_messages, mt_trace, mt_events, mv_iterations, mv_tool_calls.

    mv_task = zcl_pia_00_json_util=>unescape(
      zcl_pia_00_json_util=>extract_str( iv_json = iv_json iv_name = 'task' ) ).

    DATA lv_it TYPE string.
    FIND FIRST OCCURRENCE OF PCRE '"iterations"' && '\s*:\s*(\d+)' IN iv_json SUBMATCHES lv_it.
    mv_iterations = lv_it.

    DATA(lv_msgs) = zcl_pia_00_json_util=>extract_balanced(
      iv_json = iv_json iv_key = 'messages' iv_open = '[' iv_close = ']' ).
    DATA lt TYPE string_table.
    lt = zcl_pia_00_json_util=>split_entries( lv_msgs ).
    LOOP AT lt INTO DATA(lv_e).
      APPEND VALUE #(
        role = zcl_pia_00_json_util=>extract_str( iv_json = lv_e iv_name = 'role' )
        content = zcl_pia_00_json_util=>unescape(
          zcl_pia_00_json_util=>extract_str( iv_json = lv_e iv_name = 'content' ) ) )
        TO mt_messages.
    ENDLOOP.

    rv_ = abap_true.
  ENDMETHOD.

ENDCLASS.

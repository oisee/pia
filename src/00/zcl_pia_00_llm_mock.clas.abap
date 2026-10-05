CLASS zcl_pia_00_llm_mock DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_pia_00_llm.

    CLASS-METHODS new RETURNING VALUE(ro_) TYPE REF TO zcl_pia_00_llm_mock.
    METHODS add_response IMPORTING iv_ TYPE string.

  PRIVATE SECTION.
    DATA mt TYPE string_table.
    DATA mv_idx TYPE i VALUE 1.

ENDCLASS.

CLASS zcl_pia_00_llm_mock IMPLEMENTATION.

  METHOD new.
    ro_ = NEW #( ).
  ENDMETHOD.

  METHOD add_response.
    APPEND iv_ TO mt.
  ENDMETHOD.

  METHOD zif_pia_00_llm~chat.
    IF mv_idx > lines( mt ).
      ev_error = 'mock: no more scripted responses'.
      RETURN.
    ENDIF.
    READ TABLE mt INTO DATA(lv_body) INDEX mv_idx.
    mv_idx = mv_idx + 1.
    ev_status = 200.
    " scripted bodies are chat-format; normalize via the shared parser
    et_calls = zcl_pia_00_llm_http=>parse_calls_chat( lv_body ).
    ev_answer = zcl_pia_00_json_util=>unescape(
      zcl_pia_00_json_util=>extract_str( iv_json = lv_body iv_name = 'content' ) ).
    IF et_calls IS NOT INITIAL.
      DATA lt_c TYPE string_table.
      LOOP AT et_calls INTO DATA(ls_c).
        APPEND '{"id":"' && ls_c-id && '","name":"' && ls_c-name &&
               '","arguments":"' && zcl_pia_00_json_util=>escape( ls_c-arguments ) && '"}' TO lt_c.
      ENDLOOP.
      ev_assistant_raw = '{"tool_calls":[' && concat_lines_of( table = lt_c sep = ',' ) && ']}'.
    ELSE.
      ev_assistant_raw = ev_answer.
    ENDIF.
  ENDMETHOD.

ENDCLASS.

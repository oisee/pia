CLASS zcl_pia_00_llm_http DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_pia_00_llm.

    CLASS-DATA sv_dbg_url  TYPE string READ-ONLY.
    CLASS-DATA sv_dbg_auth TYPE string READ-ONLY.

    CLASS-METHODS new
      IMPORTING is_config   TYPE zif_pia_00_llm=>ts_config
      RETURNING VALUE(ro_)  TYPE REF TO zcl_pia_00_llm_http.

    " generic helpers (mock reuses them)
    CLASS-METHODS split_entries
      IMPORTING iv_arr      TYPE string
      RETURNING VALUE(rt_)  TYPE string_table.

    CLASS-METHODS parse_calls_chat
      IMPORTING iv_body     TYPE string
      RETURNING VALUE(rt_)  TYPE zif_pia_00_tool=>tt_calls.

    CLASS-METHODS parse_calls_responses
      IMPORTING iv_body     TYPE string
      RETURNING VALUE(rt_)  TYPE zif_pia_00_tool=>tt_calls.

  PRIVATE SECTION.
    DATA ms_config TYPE zif_pia_00_llm=>ts_config.

    METHODS build_input_items
      IMPORTING it_messages  TYPE zcl_pia_00_session=>tt_messages
                iv_system    TYPE string
      RETURNING VALUE(rv_)   TYPE string.

    METHODS flatten_tools
      IMPORTING iv_tools_json TYPE string
      RETURNING VALUE(rv_)   TYPE string.

ENDCLASS.

CLASS zcl_pia_00_llm_http IMPLEMENTATION.

  METHOD new.
    ro_ = NEW #( ).
    ro_->ms_config = is_config.
  ENDMETHOD.

  METHOD split_entries.
    " top-level {...} entries of a JSON array string; defensive: braces inside
    " string values may be unbalanced, so every access is clamped
    DATA lv_len_arr TYPE i.
    lv_len_arr = strlen( iv_arr ).
    DATA lv_pos TYPE i VALUE 0.
    WHILE lv_pos < lv_len_arr.
      FIND FIRST OCCURRENCE OF '{' IN iv_arr+lv_pos MATCH OFFSET DATA(lv_off).
      IF sy-subrc <> 0. EXIT. ENDIF.
      DATA lv_start TYPE i.
      lv_start = lv_pos + lv_off.
      IF lv_start >= lv_len_arr. EXIT. ENDIF.
      DATA lv_depth TYPE i.
      lv_depth = 1.
      DATA lv_end TYPE i.
      lv_end = lv_start.
      WHILE lv_end < lv_len_arr - 1 AND lv_depth > 0.
        lv_end = lv_end + 1.
        IF iv_arr+lv_end(1) = '{'.
          lv_depth = lv_depth + 1.
        ELSEIF iv_arr+lv_end(1) = '}'.
          lv_depth = lv_depth - 1.
        ENDIF.
      ENDWHILE.
      IF lv_depth > 0.
        lv_end = lv_len_arr - 1.
      ENDIF.
      DATA lv_len TYPE i.
      lv_len = lv_end - lv_start + 1.
      IF lv_len <= 0. EXIT. ENDIF.
      IF lv_start + lv_len > lv_len_arr.
        lv_len = lv_len_arr - lv_start.
      ENDIF.
      IF lv_len > 0.
        APPEND iv_arr+lv_start(lv_len) TO rt_.
      ENDIF.
      lv_pos = lv_end + 1.
    ENDWHILE.
  ENDMETHOD.

  METHOD parse_calls_chat.
    DATA(lv_arr) = zcl_pia_00_json_util=>extract_balanced(
      iv_json = iv_body iv_key = 'tool_calls' iv_open = '[' iv_close = ']' ).
    LOOP AT split_entries( lv_arr ) INTO DATA(lv_e).
      DATA ls TYPE zif_pia_00_tool=>ts_call.
      ls-id = zcl_pia_00_json_util=>extract_str( iv_json = lv_e iv_name = 'id' ).
      ls-name = zcl_pia_00_json_util=>extract_str( iv_json = lv_e iv_name = 'name' ).
      ls-arguments = zcl_pia_00_json_util=>unescape( zcl_pia_00_json_util=>extract_balanced(
                       iv_json = lv_e iv_key = 'arguments' iv_open = '{' iv_close = '}' ) ).
      IF ls-name IS NOT INITIAL.
        APPEND ls TO rt_.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD parse_calls_responses.
    DATA(lv_arr) = zcl_pia_00_json_util=>extract_balanced(
      iv_json = iv_body iv_key = 'output' iv_open = '[' iv_close = ']' ).
    LOOP AT split_entries( lv_arr ) INTO DATA(lv_e).
      IF lv_e NS '"function_call"' AND lv_e NS '"type":"function_call"'.
        CONTINUE.
      ENDIF.
      DATA ls TYPE zif_pia_00_tool=>ts_call.
      ls-id = zcl_pia_00_json_util=>extract_str( iv_json = lv_e iv_name = 'call_id' ).
      ls-name = zcl_pia_00_json_util=>extract_str( iv_json = lv_e iv_name = 'name' ).
      ls-arguments = zcl_pia_00_json_util=>unescape( zcl_pia_00_json_util=>extract_balanced(
                       iv_json = lv_e iv_key = 'arguments' iv_open = '{' iv_close = '}' ) ).
      IF ls-name IS NOT INITIAL.
        APPEND ls TO rt_.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD flatten_tools.
    " chat format [{type,function:{...}}] -> responses flat [{type:function,name,...}]
    DATA lt TYPE string_table.
    DATA lv_inner TYPE string.
    DATA lv_len2 TYPE i.
    LOOP AT split_entries( iv_tools_json ) INTO DATA(lv_e).
      DATA(lv_f) = zcl_pia_00_json_util=>extract_balanced(
        iv_json = lv_e iv_key = 'function' iv_open = '{' iv_close = '}' ).
      IF lv_f IS INITIAL.
        APPEND lv_e TO lt.
      ELSE.
        lv_len2 = strlen( lv_f ) - 2.
        lv_inner = lv_f+1(lv_len2).
        APPEND '{"type":"function",' && lv_inner && '}' TO lt.
      ENDIF.
    ENDLOOP.
    rv_ = '[' && concat_lines_of( table = lt sep = ',' ) && ']'.
  ENDMETHOD.

  METHOD build_input_items.
    DATA lt TYPE string_table.
    LOOP AT it_messages INTO DATA(ls).
      IF ls-role = 'system'.
        CONTINUE. " goes to instructions
      ELSEIF ls-role = 'assistant' AND ls-content CP '{"tool_calls"*'.
        DATA(lv_arr) = zcl_pia_00_json_util=>extract_balanced(
          iv_json = ls-content iv_key = 'tool_calls' iv_open = '[' iv_close = ']' ).
        LOOP AT split_entries( lv_arr ) INTO DATA(lv_e).
          APPEND '{"type":"function_call","call_id":"' &&
                 zcl_pia_00_json_util=>extract_str( iv_json = lv_e iv_name = 'id' ) &&
                 '","name":"' &&
                 zcl_pia_00_json_util=>extract_str( iv_json = lv_e iv_name = 'name' ) &&
                 '","arguments":"' &&
                 zcl_pia_00_json_util=>extract_str( iv_json = lv_e iv_name = 'arguments' ) &&
                 '"}' TO lt.
        ENDLOOP.
      ELSEIF ls-role = 'tool'.
        APPEND '{"type":"function_call_output","call_id":"' &&
               zcl_pia_00_json_util=>extract_str( iv_json = ls-content iv_name = 'tool_call_id' ) &&
               '","output":"' &&
               zcl_pia_00_json_util=>extract_str( iv_json = ls-content iv_name = 'content' ) && '"}' TO lt.
      ELSE.
        APPEND '{"role":"' && ls-role && '","content":"' &&
               zcl_pia_00_json_util=>escape( ls-content ) && '"}' TO lt.
      ENDIF.
    ENDLOOP.
    rv_ = '[' && concat_lines_of( table = lt sep = ',' ) && ']'.
  ENDMETHOD.

  METHOD zif_pia_00_llm~chat.
    DATA lv_body TYPE string.
    DATA li TYPE REF TO if_http_client.

    IF ms_config-api_type = 'responses'.
      DATA lv_system TYPE string.
      READ TABLE it_messages INTO DATA(ls_sys) INDEX 1.
      IF sy-subrc = 0 AND ls_sys-role = 'system'.
        lv_system = ls_sys-content.
      ENDIF.
      lv_body = '{"model":"' && ms_config-model &&
                '","instructions":"' && zcl_pia_00_json_util=>escape( lv_system ) &&
                '","input":' && build_input_items( it_messages = it_messages iv_system = lv_system ).
      IF iv_tools_json IS NOT INITIAL.
        lv_body = lv_body && ',"tools":' && flatten_tools( iv_tools_json ).
      ENDIF.
      lv_body = lv_body && '}'.
    ELSE.
      DATA lv_tools TYPE string.
      IF iv_tools_json IS NOT INITIAL.
        lv_tools = ',"tools":' && iv_tools_json.
      ENDIF.
      DATA lt TYPE string_table.
      LOOP AT it_messages INTO DATA(ls).
        IF ls-role = 'assistant' AND ls-content CP '{"tool_calls"*'.
          APPEND '{"role":"assistant","tool_calls":' && ls-content+14 && '}' TO lt.
        ELSEIF ls-role = 'tool'.
          APPEND '{"role":"tool",' && ls-content && '}' TO lt.
        ELSE.
          APPEND '{"role":"' && ls-role && '","content":"' &&
                 zcl_pia_00_json_util=>escape( ls-content ) && '"}' TO lt.
        ENDIF.
      ENDLOOP.
      lv_body = '{"model":"' && ms_config-model && '","stream":false,"messages":[' &&
                concat_lines_of( table = lt sep = ',' ) && ']' && lv_tools && '}'.
    ENDIF.

    cl_http_client=>create_by_url(
      EXPORTING url = ms_config-base_url
      IMPORTING client = li ).
    li->request->set_method( 'POST' ).
    li->request->set_header_field( name = 'content-type' value = 'application/json' ).
    IF ms_config-api_key IS NOT INITIAL.
      DATA lv_auth TYPE string.
      lv_auth = |Bearer { ms_config-api_key }|.
      li->request->set_header_field( name = 'Authorization' value = lv_auth ).
      sv_dbg_url = ms_config-base_url.
      sv_dbg_auth = 'len=' && strlen( ms_config-api_key ) &&
                    ' head=' && ms_config-api_key+0(6) &&
                    ' tail=' && substring( val = ms_config-api_key off = strlen( ms_config-api_key ) - 4 ).
    ENDIF.
    li->request->set_cdata( lv_body ).
    li->send( ).
    li->receive( ).
    li->response->get_status( IMPORTING code = ev_status ).
    ev_body = li->response->get_cdata( ).
    DATA lv_resp TYPE string.
    lv_resp = ev_body.
    IF ev_status <> 200.
      ev_error = 'HTTP ' && ev_status && ': ' && lv_resp.
      RETURN.
    ENDIF.

    IF ms_config-api_type = 'responses'.
      et_calls = parse_calls_responses( lv_resp ).
      " answer: output_text of message items
      DATA(lv_arr2) = zcl_pia_00_json_util=>extract_balanced(
        iv_json = lv_resp iv_key = 'output' iv_open = '[' iv_close = ']' ).
      LOOP AT split_entries( lv_arr2 ) INTO DATA(lv_item).
        IF lv_item CS 'output_text'.
          ev_answer = ev_answer && zcl_pia_00_json_util=>unescape(
            zcl_pia_00_json_util=>extract_str( iv_json = lv_item iv_name = 'text' ) ).
        ENDIF.
      ENDLOOP.
    ELSE.
      et_calls = parse_calls_chat( lv_resp ).
      ev_answer = zcl_pia_00_json_util=>unescape(
        zcl_pia_00_json_util=>extract_str( iv_json = lv_resp iv_name = 'content' ) ).
    ENDIF.

    " replayable raw (uniform session convention)
    IF et_calls IS NOT INITIAL.
      DATA lt_c TYPE string_table.
      LOOP AT et_calls INTO DATA(ls_c).
        APPEND '{"id":"' && ls_c-id && '","name":"' && ls_c-name &&
               '","arguments":' &&
               zcl_pia_00_json_util=>escape( ls_c-arguments ) && '}' TO lt_c.
      ENDLOOP.
      ev_assistant_raw = '{"tool_calls":[' && concat_lines_of( table = lt_c sep = ',' ) && ']}'.
    ELSE.
      ev_assistant_raw = ev_answer.
    ENDIF.
  ENDMETHOD.

ENDCLASS.

CLASS zcl_pia_00_llm_http DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_pia_00_llm.


    CLASS-METHODS new
      IMPORTING is_config   TYPE zif_pia_00_llm=>ts_config
      RETURNING VALUE(ro_)  TYPE REF TO zcl_pia_00_llm_http.

    " generic helpers (mock reuses them)
    CLASS-METHODS parse_calls_chat
      IMPORTING iv_body     TYPE string
      RETURNING VALUE(rt_)  TYPE zif_pia_00_tool=>tt_calls.

    CLASS-METHODS parse_calls_responses
      IMPORTING iv_body     TYPE string
      RETURNING VALUE(rt_)  TYPE zif_pia_00_tool=>tt_calls.

    CLASS-METHODS parse_reply_chat
      IMPORTING iv_body TYPE string
      EXPORTING et_calls TYPE zif_pia_00_tool=>tt_calls
                ev_answer TYPE string
                ev_error TYPE string.

  PRIVATE SECTION.
    METHODS build_request
      IMPORTING it_messages TYPE zif_pia_00_llm=>tt_messages
                iv_tools_json TYPE string OPTIONAL
      RETURNING VALUE(lv_body) TYPE string.

    " next recorded response; the position is kept in <file>.pos so it survives turns run as jobs
    METHODS replay
      IMPORTING iv_file   TYPE string
      EXPORTING ev_status TYPE i
                ev_body   TYPE string
                ev_error  TYPE string.
    DATA ms_config TYPE zif_pia_00_llm=>ts_config.

    METHODS build_input_items
      IMPORTING it_messages  TYPE zif_pia_00_llm=>tt_messages
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


  METHOD parse_calls_chat.
    " the JSON is read by sXML (zcl_pia_00_json_util=>to_paths); strings come decoded
    zcl_pia_00_json_util=>to_paths( EXPORTING iv_json = iv_body IMPORTING et_ = DATA(lt_pv) ).
    DATA(lv_base) = `/choices/1/message/tool_calls/`.
    LOOP AT lt_pv INTO DATA(ls_pv) WHERE path CP lv_base && '*/function/name'.
      DATA(lv_item) = substring_before( val = ls_pv-path sub = `/function/name` ).
      APPEND VALUE #( id        = zcl_pia_00_json_util=>path_value( it_ = lt_pv iv_path = lv_item && `/id` )
                      name      = ls_pv-value
                      arguments = zcl_pia_00_json_util=>path_value( it_ = lt_pv iv_path = lv_item && `/function/arguments` ) ) TO rt_.
    ENDLOOP.
  ENDMETHOD.

  METHOD parse_calls_responses.
    " output items of type function_call; the JSON is read by sXML (zcl_pia_00_json_util=>to_paths)
    zcl_pia_00_json_util=>to_paths( EXPORTING iv_json = iv_body IMPORTING et_ = DATA(lt_pv) ).
    LOOP AT lt_pv INTO DATA(ls_pv) WHERE path CP '/output/*/type' AND value = `function_call`.
      DATA(lv_item) = substring_before( val = ls_pv-path sub = `/type` ).
      IF lv_item CA `/` AND substring_after( val = lv_item sub = `/output/` ) CA `/`.
        CONTINUE.   " a nested type, not an output item
      ENDIF.
      APPEND VALUE #( id        = zcl_pia_00_json_util=>path_value( it_ = lt_pv iv_path = lv_item && `/call_id` )
                      name      = zcl_pia_00_json_util=>path_value( it_ = lt_pv iv_path = lv_item && `/name` )
                      arguments = zcl_pia_00_json_util=>path_value( it_ = lt_pv iv_path = lv_item && `/arguments` ) ) TO rt_.
    ENDLOOP.
  ENDMETHOD.

  METHOD flatten_tools.
    " chat format [{type,function:{...}}] -> responses flat [{type:function,name,...}]
    DATA lt TYPE string_table.
    DATA lv_inner TYPE string.
    DATA lv_len2 TYPE i.
    LOOP AT zcl_pia_00_json_util=>split_entries( iv_tools_json ) INTO DATA(lv_e).
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
        zcl_pia_00_json_util=>to_paths( EXPORTING iv_json = ls-content IMPORTING et_ = DATA(lt_pv) ).
        LOOP AT lt_pv INTO DATA(ls_pv) WHERE path CP '/tool_calls/*/name'.
          DATA(lv_item) = substring_before( val = ls_pv-path sub = `/name` ).
          APPEND '{"type":"function_call","call_id":"' &&
                 zcl_pia_00_json_util=>escape( zcl_pia_00_json_util=>path_value( it_ = lt_pv iv_path = lv_item && `/id` ) ) &&
                 '","name":"' && zcl_pia_00_json_util=>escape( ls_pv-value ) &&
                 '","arguments":"' &&
                 zcl_pia_00_json_util=>escape( zcl_pia_00_json_util=>path_value( it_ = lt_pv iv_path = lv_item && `/arguments` ) ) &&
                 '"}' TO lt.
        ENDLOOP.
      ELSEIF ls-role = 'tool'.
        " stored as the members "tool_call_id":"..","content":".." (no braces)
        zcl_pia_00_json_util=>to_paths( EXPORTING iv_json = `{` && ls-content && `}` IMPORTING et_ = DATA(lt_tool) ).
        APPEND '{"type":"function_call_output","call_id":"' &&
               zcl_pia_00_json_util=>escape( zcl_pia_00_json_util=>path_value( it_ = lt_tool iv_path = `/tool_call_id` ) ) &&
               '","output":"' &&
               zcl_pia_00_json_util=>escape( zcl_pia_00_json_util=>path_value( it_ = lt_tool iv_path = `/content` ) ) && '"}' TO lt.
      ELSE.
        APPEND '{"role":"' && ls-role && '","content":"' &&
               zcl_pia_00_json_util=>escape( ls-content ) && '"}' TO lt.
      ENDIF.
    ENDLOOP.
    rv_ = '[' && concat_lines_of( table = lt sep = ',' ) && ']'.
  ENDMETHOD.

  METHOD build_request.
    IF ms_config-api_type = 'responses'.
      DATA lv_system TYPE string.
      READ TABLE it_messages INTO DATA(ls_sys) INDEX 1.
      IF sy-subrc = 0 AND ls_sys-role = 'system'.
        lv_system = ls_sys-content.
      ENDIF.
      lv_body = '{"model":"' && zcl_pia_00_json_util=>escape( ms_config-model ) &&
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
          zcl_pia_00_json_util=>to_paths( EXPORTING iv_json = ls-content IMPORTING et_ = DATA(lt_calls) ).
          DATA lt_wire TYPE string_table.
          CLEAR lt_wire.
          LOOP AT lt_calls INTO DATA(ls_call) WHERE path CP '/tool_calls/*/name'.
            DATA(lv_item) = substring_before( val = ls_call-path sub = `/name` ).
            APPEND `{"id":"` && zcl_pia_00_json_util=>escape(
              zcl_pia_00_json_util=>path_value( it_ = lt_calls iv_path = lv_item && `/id` ) )
              && `","type":"function","function":{"name":"` && zcl_pia_00_json_util=>escape( ls_call-value )
              && `","arguments":"` && zcl_pia_00_json_util=>escape(
              zcl_pia_00_json_util=>path_value( it_ = lt_calls iv_path = lv_item && `/arguments` ) ) && `"}}` TO lt_wire.
          ENDLOOP.
          APPEND `{"role":"assistant","content":null,"tool_calls":[`
            && concat_lines_of( table = lt_wire sep = `,` ) && `]}` TO lt.
        ELSEIF ls-role = 'tool'.
          APPEND '{"role":"tool",' && ls-content && '}' TO lt.
        ELSE.
          APPEND '{"role":"' && ls-role && '","content":"' &&
                 zcl_pia_00_json_util=>escape( ls-content ) && '"}' TO lt.
        ENDIF.
      ENDLOOP.
      lv_body = '{"model":"' && zcl_pia_00_json_util=>escape( ms_config-model ) && '","stream":false,"messages":[' &&
                concat_lines_of( table = lt sep = ',' ) && ']' && lv_tools && '}'.
    ENDIF.

    " Only configured sampling limits go on the wire. Preserve API defaults otherwise.
    DATA lv_options TYPE string.
    IF ms_config-temperature IS NOT INITIAL.
      FIND REGEX `^-?(0|[1-9][0-9]*)([.][0-9]+)?([eE][+-]?[0-9]+)?$` IN ms_config-temperature.
      IF sy-subrc <> 0.
        RAISE EXCEPTION TYPE cx_sy_conversion_no_number.
      ENDIF.
      lv_options = lv_options && `,"temperature":` && ms_config-temperature.
    ENDIF.
    IF ms_config-max_tokens IS NOT INITIAL.
      FIND REGEX `^[1-9][0-9]*$` IN ms_config-max_tokens.
      IF sy-subrc <> 0.
        RAISE EXCEPTION TYPE cx_sy_conversion_no_number.
      ENDIF.
      DATA(lv_limit) = COND string( WHEN ms_config-api_type = `responses` THEN `max_output_tokens` ELSE `max_tokens` ).
      lv_options = lv_options && `,"` && lv_limit && `":` && ms_config-max_tokens.
    ENDIF.
    IF lv_options IS NOT INITIAL.
      lv_body = substring( val = lv_body len = strlen( lv_body ) - 1 ) && lv_options && `}`.
    ENDIF.
  ENDMETHOD.

  METHOD parse_reply_chat.
    CLEAR: et_calls, ev_answer, ev_error.
    et_calls = parse_calls_chat( iv_body ).
    zcl_pia_00_json_util=>to_paths( EXPORTING iv_json = iv_body IMPORTING et_ = DATA(lt_chat) ).
    ev_answer = zcl_pia_00_json_util=>path_value( it_ = lt_chat iv_path = `/choices/1/message/content` ).
    " reasoning_content is deliberately ignored; this adapter has no metrics sink.
    IF zcl_pia_00_json_util=>path_value( it_ = lt_chat iv_path = `/choices/1/finish_reason` ) = `length`.
      ev_error = `LLM output truncated (finish_reason=length); increase PIA_MAX_TOKENS or reduce the context.`.
      CLEAR et_calls. " never execute incomplete tool arguments
    ENDIF.
  ENDMETHOD.

  METHOD zif_pia_00_llm~chat.
    CLEAR: et_calls, ev_answer, ev_assistant_raw, ev_body, ev_status, ev_error.
    DATA lv_body TYPE string.
    DATA li TYPE REF TO if_http_client.

    lv_body = build_request( it_messages = it_messages iv_tools_json = iv_tools_json ).

    " PIA_LLM=replay:<file> answers from a recorded transcript (no key, no network);
    " PIA_LLM=record:<file> appends every response body to that file (one escaped body per line)
    DATA(lv_mode) = zcl_pia_00_config=>get( `PIA_LLM` ).
    IF lv_mode CP 'replay:*'.
      replay( EXPORTING iv_file = substring_after( val = lv_mode sub = `:` )
              IMPORTING ev_status = ev_status ev_body = ev_body ev_error = ev_error ).
      IF ev_error IS NOT INITIAL.
        RETURN.
      ENDIF.
    ELSE.
      cl_http_client=>create_by_url(
        EXPORTING url = ms_config-base_url
        IMPORTING client = li ).
      li->request->set_method( 'POST' ).
      li->request->set_header_field( name = 'content-type' value = 'application/json' ).
      IF ms_config-api_key IS NOT INITIAL.
        DATA lv_auth TYPE string.
        lv_auth = |Bearer { ms_config-api_key }|.
        li->request->set_header_field( name = 'Authorization' value = lv_auth ).
      ENDIF.
      li->request->set_cdata( lv_body ).
      li->send( ).
      li->receive( ).
      li->response->get_status( IMPORTING code = ev_status ).
      ev_body = li->response->get_cdata( ).
      IF lv_mode CP 'record:*' AND ev_status = 200.
        zcl_pia_00_session_store=>append_line(
          iv_file = substring_after( val = lv_mode sub = `:` )
          iv_line = zcl_pia_00_json_util=>escape( ev_body ) ).
      ENDIF.
    ENDIF.
    DATA lv_resp TYPE string.
    lv_resp = ev_body.
    IF ev_status <> 200.
      ev_error = |HTTP { ev_status }: { lv_resp }|.
      RETURN.
    ENDIF.

    IF ms_config-api_type = 'responses'.
      et_calls = parse_calls_responses( lv_resp ).
      " answer: output_text of message items
      zcl_pia_00_json_util=>to_paths( EXPORTING iv_json = lv_resp IMPORTING et_ = DATA(lt_out) ).
      LOOP AT lt_out INTO DATA(ls_out) WHERE path CP '/output/*/content/*/type' AND value = `output_text`.
        ev_answer = ev_answer && zcl_pia_00_json_util=>path_value(
          it_ = lt_out iv_path = substring_before( val = ls_out-path sub = `/type` ) && `/text` ).
      ENDLOOP.
    ELSE.
      parse_reply_chat( EXPORTING iv_body = lv_resp
                        IMPORTING et_calls = et_calls ev_answer = ev_answer ev_error = ev_error ).
      IF ev_error IS NOT INITIAL.
        RETURN.
      ENDIF.
    ENDIF.

    " replayable raw (uniform session convention)
    IF et_calls IS NOT INITIAL.
      DATA lt_c TYPE string_table.
      LOOP AT et_calls INTO DATA(ls_c).
        APPEND '{"id":"' && ls_c-id && '","name":"' && ls_c-name &&
               '","arguments":"' &&
               zcl_pia_00_json_util=>escape( ls_c-arguments ) && '"}' TO lt_c.  " a JSON string, as the API sends it
      ENDLOOP.
      ev_assistant_raw = '{"tool_calls":[' && concat_lines_of( table = lt_c sep = ',' ) && ']}'.
    ELSE.
      ev_assistant_raw = ev_answer.
    ENDIF.
  ENDMETHOD.

  METHOD replay.
    DATA lv_pos TYPE i.
    DATA(lt_pos) = zcl_pia_00_session_store=>read_lines( |{ iv_file }.pos| ).
    READ TABLE lt_pos INDEX 1 INTO DATA(lv_pos_text).
    IF sy-subrc = 0.
      lv_pos = lv_pos_text.
    ENDIF.
    DATA(lt_rec) = zcl_pia_00_session_store=>read_lines( iv_file ).
    lv_pos = lv_pos + 1.
    READ TABLE lt_rec INDEX lv_pos INTO DATA(lv_line).
    IF sy-subrc <> 0.
      ev_error = |replay: no recorded response { lv_pos } in { iv_file } ({ lines( lt_rec ) } recorded)|.
      RETURN.
    ENDIF.
    zcl_pia_00_session_store=>write_lines( iv_file = |{ iv_file }.pos| it_ = VALUE #( ( |{ lv_pos }| ) ) ).
    ev_status = 200.
    ev_body = zcl_pia_00_json_util=>unescape( lv_line ).
  ENDMETHOD.

ENDCLASS.

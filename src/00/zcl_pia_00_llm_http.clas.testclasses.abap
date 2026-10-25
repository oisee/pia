" Tool calls from LLM answers, read with sXML. The case F1 started from: two calls, a lone brace in the
" first call's source, and the model's reasoning with unbalanced brackets before them.
CLASS ltcl_calls DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    DATA mv_a1 TYPE string.
    DATA mv_a2 TYPE string.
    METHODS setup.
    METHODS responses_two_calls FOR TESTING.
    METHODS chat_two_calls FOR TESTING.
ENDCLASS.

CLASS ltcl_calls IMPLEMENTATION.

  METHOD setup.
    mv_a1 = `{"name":"ZCL_X","source":"lv_open = '{'."}`.
    mv_a2 = `{"name":"ZCL_X"}`.
  ENDMETHOD.

  METHOD responses_two_calls.
    DATA(lv_body) = `{"output":[{"type":"reasoning","content":[{"type":"reasoning_text","text":"the first ] closes it"}]},`
      && `{"type":"function_call","name":"write_source","arguments":"` && zcl_pia_00_json_util=>escape( mv_a1 )
      && `","call_id":"c1","status":"completed"},`
      && `{"type":"function_call","name":"activate","arguments":"` && zcl_pia_00_json_util=>escape( mv_a2 )
      && `","call_id":"c2","status":"completed"}],"status":"completed"}`.
    DATA(lt) = zcl_pia_00_llm_http=>parse_calls_responses( lv_body ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt ) exp = 2 msg = 'both calls' ).
    cl_abap_unit_assert=>assert_equals( act = lt[ 1 ]-name exp = `write_source` ).
    cl_abap_unit_assert=>assert_equals( act = lt[ 1 ]-arguments exp = mv_a1 msg = 'arguments of call 1, nothing added' ).
    cl_abap_unit_assert=>assert_equals( act = lt[ 2 ]-id exp = `c2` ).
    cl_abap_unit_assert=>assert_equals( act = lt[ 2 ]-arguments exp = mv_a2 ).
  ENDMETHOD.

  METHOD chat_two_calls.
    DATA(lv_body) = `{"choices":[{"message":{"role":"assistant","content":"a ] b","tool_calls":[`
      && `{"id":"c1","type":"function","function":{"name":"write_source","arguments":"` && zcl_pia_00_json_util=>escape( mv_a1 ) && `"}},`
      && `{"id":"c2","type":"function","function":{"name":"activate","arguments":"` && zcl_pia_00_json_util=>escape( mv_a2 ) && `"}}]}}]}`.
    DATA(lt) = zcl_pia_00_llm_http=>parse_calls_chat( lv_body ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt ) exp = 2 msg = 'both calls' ).
    cl_abap_unit_assert=>assert_equals( act = lt[ 1 ]-arguments exp = mv_a1 ).
    cl_abap_unit_assert=>assert_equals( act = lt[ 2 ]-name exp = `activate` ).
  ENDMETHOD.

ENDCLASS.

CLASS ltcl_local_chat DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    METHODS optional_limits FOR TESTING.
    METHODS default_limits FOR TESTING.
    METHODS invalid_limits FOR TESTING.
    METHODS final_text FOR TESTING.
    METHODS null_content FOR TESTING.
    METHODS empty_content FOR TESTING.
    METHODS string_arguments FOR TESTING.
    METHODS reasoning_content FOR TESTING.
    METHODS length_empty FOR TESTING.
    METHODS length_partial FOR TESTING.
    METHODS length_tool FOR TESTING.
    METHODS tool_roundtrip IMPORTING iv_content TYPE string iv_reasoning TYPE string DEFAULT ``.
ENDCLASS.

CLASS zcl_pia_00_llm_http DEFINITION LOCAL FRIENDS ltcl_local_chat.

CLASS ltcl_local_chat IMPLEMENTATION.
  METHOD optional_limits.
    LOOP AT VALUE string_table( ( `chat` ) ( `responses` ) ) INTO DATA(lv_api).
      DATA(lo_llm) = zcl_pia_00_llm_http=>new( VALUE #(
        api_type = lv_api model = `test` temperature = `0` max_tokens = `512` ) ).
      DATA(lv_body) = lo_llm->build_request( VALUE #( ( role = `user` content = `hello` ) ) ).
      zcl_pia_00_json_util=>to_paths( EXPORTING iv_json = lv_body
        IMPORTING et_ = DATA(lt_paths) ev_error = DATA(lv_error) ).
      cl_abap_unit_assert=>assert_initial( lv_error ).
      cl_abap_unit_assert=>assert_equals( exp = `0`
        act = zcl_pia_00_json_util=>path_value( it_ = lt_paths iv_path = `/temperature` ) ).
      DATA(lv_key) = COND string( WHEN lv_api = `chat` THEN `/max_tokens` ELSE `/max_output_tokens` ).
      cl_abap_unit_assert=>assert_equals( exp = `512`
        act = zcl_pia_00_json_util=>path_value( it_ = lt_paths iv_path = lv_key ) ).
      DATA(lv_wrong) = COND string( WHEN lv_api = `chat` THEN `/max_output_tokens` ELSE `/max_tokens` ).
      cl_abap_unit_assert=>assert_initial(
        zcl_pia_00_json_util=>path_value( it_ = lt_paths iv_path = lv_wrong ) ).
    ENDLOOP.
  ENDMETHOD.
  METHOD default_limits.
    LOOP AT VALUE string_table( ( `chat` ) ( `responses` ) ) INTO DATA(lv_api).
      DATA(lo_llm) = zcl_pia_00_llm_http=>new( VALUE #( api_type = lv_api model = `test` ) ).
      DATA(lv_body) = lo_llm->build_request( VALUE #( ) ).
      cl_abap_unit_assert=>assert_false( xsdbool( lv_body CS `temperature` ) ).
      cl_abap_unit_assert=>assert_false( xsdbool( lv_body CS `max_tokens` ) ).
      cl_abap_unit_assert=>assert_false( xsdbool( lv_body CS `max_output_tokens` ) ).
    ENDLOOP.
  ENDMETHOD.
  METHOD invalid_limits.
    DATA(lo_llm) = zcl_pia_00_llm_http=>new( VALUE #( api_type = `chat` max_tokens = `1,"injected":true` ) ).
    TRY.
        DATA(lv_body) = lo_llm->build_request( VALUE #( ) ).
        cl_abap_unit_assert=>fail( `invalid numeric setting must be rejected` ).
      CATCH cx_sy_conversion_no_number.
    ENDTRY.
  ENDMETHOD.
  METHOD final_text.
    zcl_pia_00_llm_http=>parse_reply_chat(
      EXPORTING iv_body = `{"choices":[{"finish_reason":"stop","message":{"content":"Done","reasoning_content":"ignore"}}]}`
      IMPORTING et_calls = DATA(lt_calls) ev_answer = DATA(lv_answer) ev_error = DATA(lv_error) ).
    cl_abap_unit_assert=>assert_initial( lt_calls ).
    cl_abap_unit_assert=>assert_initial( lv_error ).
    cl_abap_unit_assert=>assert_equals( act = lv_answer exp = `Done` ).
  ENDMETHOD.
  METHOD tool_roundtrip.
    DATA(lv_args) = `{"name":"ZCL_X","source":"a = '}'."}`.
    DATA(lv_body) = `{"choices":[{"finish_reason":"tool_calls","message":{"role":"assistant","content":`
      && iv_content && iv_reasoning && `,"tool_calls":[{"id":"c1","type":"function","function":`
      && `{"name":"write_source","arguments":"` && zcl_pia_00_json_util=>escape( lv_args ) && `"}}]}}]}`.
    zcl_pia_00_llm_http=>parse_reply_chat( EXPORTING iv_body = lv_body
      IMPORTING et_calls = DATA(lt_calls) ev_answer = DATA(lv_answer) ev_error = DATA(lv_error) ).
    cl_abap_unit_assert=>assert_initial( lv_error ).
    cl_abap_unit_assert=>assert_initial( lv_answer ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_calls ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lt_calls[ 1 ]-arguments exp = lv_args ).
    DATA(lo_llm) = zcl_pia_00_llm_http=>new( VALUE #( api_type = `chat` model = `test` ) ).
    DATA(lv_raw) = `{"tool_calls":[{"id":"c1","name":"write_source","arguments":"`
      && zcl_pia_00_json_util=>escape( lt_calls[ 1 ]-arguments ) && `"}]}`.
    DATA(lv_request) = lo_llm->build_request( VALUE #(
      ( role = `assistant` content = lv_raw )
      ( role = `tool` content = `"tool_call_id":"c1","content":"ok"` ) ) ).
    zcl_pia_00_json_util=>to_paths( EXPORTING iv_json = lv_request
      IMPORTING et_ = DATA(lt_paths) ev_error = lv_error ).
    cl_abap_unit_assert=>assert_initial( act = lv_error msg = `follow-up must be valid JSON` ).
    cl_abap_unit_assert=>assert_equals( exp = `write_source`
      act = zcl_pia_00_json_util=>path_value( it_ = lt_paths iv_path = `/messages/1/tool_calls/1/function/name` ) ).
    cl_abap_unit_assert=>assert_equals( exp = lv_args
      act = zcl_pia_00_json_util=>path_value( it_ = lt_paths iv_path = `/messages/1/tool_calls/1/function/arguments` ) ).
  ENDMETHOD.
  METHOD null_content.
    tool_roundtrip( `null` ).
  ENDMETHOD.
  METHOD empty_content.
    tool_roundtrip( `""` ).
  ENDMETHOD.
  METHOD string_arguments.
    tool_roundtrip( `null` ).
  ENDMETHOD.
  METHOD reasoning_content.
    tool_roundtrip( iv_content = `null` iv_reasoning = `,"reasoning_content":"ignore ] } this"` ).
  ENDMETHOD.
  METHOD length_empty.
    zcl_pia_00_llm_http=>parse_reply_chat(
      EXPORTING iv_body = `{"choices":[{"finish_reason":"length","message":{"content":null}}]}`
      IMPORTING ev_error = DATA(lv_error) ).
    cl_abap_unit_assert=>assert_not_initial( lv_error ).
  ENDMETHOD.
  METHOD length_partial.
    zcl_pia_00_llm_http=>parse_reply_chat(
      EXPORTING iv_body = `{"choices":[{"finish_reason":"length","message":{"content":"partial"}}]}`
      IMPORTING ev_error = DATA(lv_error) ).
    cl_abap_unit_assert=>assert_not_initial( lv_error ).
  ENDMETHOD.
  METHOD length_tool.
    zcl_pia_00_llm_http=>parse_reply_chat(
      EXPORTING iv_body = `{"choices":[{"finish_reason":"length","message":{"content":null,"tool_calls":[`
        && `{"id":"c1","function":{"name":"activate","arguments":"{"}}]}}]}`
      IMPORTING et_calls = DATA(lt_calls) ev_error = DATA(lv_error) ).
    cl_abap_unit_assert=>assert_not_initial( lv_error ).
    cl_abap_unit_assert=>assert_initial( lt_calls ).
  ENDMETHOD.
ENDCLASS.

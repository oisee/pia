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

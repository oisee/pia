" Unit tests for the tool-call parsers of zcl_pia_00_llm_http.
CLASS ltcl_parse_calls DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    METHODS responses_two_calls_one_brace FOR TESTING.
    METHODS chat_two_calls_one_brace FOR TESTING.
ENDCLASS.

CLASS ltcl_parse_calls IMPLEMENTATION.

  METHOD responses_two_calls_one_brace.
    " first call: source contains a string literal with a single opening brace
    DATA lv_a1 TYPE string.
    lv_a1 = `{` && `\n` && `    lv_open = '{'.` && `\n` && `  }`.
    DATA lv_a2 TYPE string.
    lv_a2 = `{` && `\n` && `    DATA lv_two TYPE i VALUE 2.` && `\n` && `  }`.
    DATA lv_body TYPE string.
    lv_body = `{` &&
              `"output":[` &&
                `{"id":"a","type":"function_call","status":"completed","call_id":"c1",` &&
                `"name":"write_method","arguments":"` && zcl_pia_00_json_util=>escape( lv_a1 ) && `"},` &&
                `{"id":"b","type":"function_call","status":"completed","call_id":"c2",` &&
                `"name":"write_method","arguments":"` && zcl_pia_00_json_util=>escape( lv_a2 ) && `"}` &&
              `]}`.

    DATA(lt_calls) = zcl_pia_00_llm_http=>parse_calls_responses( lv_body ).

    cl_abap_unit_assert=>assert_equals(
      exp = 2
      act = lines( lt_calls )
      msg = 'responses: both function_call items must be parsed' ).

    READ TABLE lt_calls INDEX 1 INTO DATA(ls_1).
    cl_abap_unit_assert=>assert_equals(
      exp = 'c1'
      act = ls_1-id
      msg = 'responses: id of first call' ).
    cl_abap_unit_assert=>assert_equals(
      exp = lv_a1
      act = ls_1-arguments
      msg = 'responses: arguments of first call must not eat the rest of the JSON' ).

    READ TABLE lt_calls INDEX 2 INTO DATA(ls_2).
    cl_abap_unit_assert=>assert_equals(
      exp = 'c2'
      act = ls_2-id
      msg = 'responses: id of second call' ).
    cl_abap_unit_assert=>assert_equals(
      exp = lv_a2
      act = ls_2-arguments
      msg = 'responses: arguments of second call' ).
  ENDMETHOD.

  METHOD chat_two_calls_one_brace.
    " same scenario in the chat format (arguments is a nested object)
    DATA lv_body TYPE string.
    lv_body = `{` &&
              `"choices":[{"message":{"role":"assistant","tool_calls":[` &&
                `{"id":"c1","type":"function","function":{` &&
                  `"name":"write_method","arguments":{"name":"ZCL_X","method":"M1",` &&
                  `"source":"    lv_open = '{'."}}}},` &&
                `{"id":"c2","type":"function","function":{` &&
                  `"name":"write_method","arguments":{"name":"ZCL_X","method":"M2",` &&
                  `"source":"    DATA lv_two TYPE i VALUE 2."}}}}` &&
              `]}}]}`.

    DATA lv_exp1 TYPE string.
    lv_exp1 = `{` && `"name":"ZCL_X","method":"M1",` &&
              `"source":"    lv_open = '{'."` && `}`.

    DATA(lt_calls) = zcl_pia_00_llm_http=>parse_calls_chat( lv_body ).

    cl_abap_unit_assert=>assert_equals(
      exp = 2
      act = lines( lt_calls )
      msg = 'chat: both tool_calls entries must be parsed' ).

    READ TABLE lt_calls INDEX 1 INTO DATA(ls_1).
    cl_abap_unit_assert=>assert_equals(
      exp = 'c1'
      act = ls_1-id
      msg = 'chat: id of first call' ).
    cl_abap_unit_assert=>assert_equals(
      exp = lv_exp1
      act = ls_1-arguments
      msg = 'chat: arguments of first call' ).

    READ TABLE lt_calls INDEX 2 INTO DATA(ls_2).
    cl_abap_unit_assert=>assert_equals(
      exp = 'c2'
      act = ls_2-id
      msg = 'chat: id of second call' ).
  ENDMETHOD.

ENDCLASS.
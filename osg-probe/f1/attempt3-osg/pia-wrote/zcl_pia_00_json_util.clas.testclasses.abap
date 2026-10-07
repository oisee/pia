"* Local ABAP Unit tests for ZCL_PIA_00_JSON_UTIL
CLASS ltcl_json_util DEFINITION FINAL
  FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    " escape
    METHODS escape_quotes FOR TESTING.
    METHODS escape_backslash FOR TESTING.
    METHODS escape_newline FOR TESTING.
    METHODS escape_nonascii FOR TESTING.
    METHODS escape_mixed FOR TESTING.
    METHODS escape_emoji_pair FOR TESTING.
    " unescape
    METHODS unescape_ctrl FOR TESTING.
    METHODS unescape_backslash_quote FOR TESTING.
    METHODS unescape_hex_known FOR TESTING.
    METHODS unescape_hex_other FOR TESTING.
    METHODS roundtrip_nonascii FOR TESTING.
    " extract_str
    METHODS extract_simple FOR TESTING.
    METHODS extract_escaped_quote FOR TESTING.
    METHODS extract_missing FOR TESTING.
    " extract_balanced
    METHODS balanced_object FOR TESTING.
    METHODS balanced_nested_and_array FOR TESTING.
    METHODS balanced_missing_key FOR TESTING.
    METHODS balanced_no_open_bracket FOR TESTING.
    METHODS balanced_unclosed FOR TESTING.
    METHODS balanced_open_brace_in_string FOR TESTING.
    METHODS balanced_close_brace_in_string FOR TESTING.
    " split_entries
    METHODS split_simple FOR TESTING.
    METHODS split_two_entries FOR TESTING.
    METHODS split_brace_in_string FOR TESTING.
    METHODS split_entries_empty FOR TESTING.
    " to_int / to_hex4 / hexval
    METHODS to_int_basic FOR TESTING.
    METHODS to_int_lowercase FOR TESTING.
    METHODS to_int_invalid FOR TESTING.
    METHODS to_hex4_zero FOR TESTING.
    METHODS to_hex4_padding FOR TESTING.
    METHODS to_hex4_cyrillic_codepoint FOR TESTING.
    METHODS to_hex4_euro_codepoint FOR TESTING.
    METHODS to_hex4_max FOR TESTING.
    METHODS hexval_digits FOR TESTING.
    METHODS hexval_lower FOR TESTING.
    METHODS hexval_invalid FOR TESTING.
ENDCLASS.

CLASS ltcl_json_util IMPLEMENTATION.

  METHOD escape_quotes.
    cl_abap_unit_assert=>assert_equals(
      exp = `a\"b`
      act = zcl_pia_00_json_util=>escape( `a"b` ) ).
  ENDMETHOD.

  METHOD escape_backslash.
    cl_abap_unit_assert=>assert_equals(
      exp = `a\\b`
      act = zcl_pia_00_json_util=>escape( `a\b` ) ).
  ENDMETHOD.

  METHOD escape_newline.
    DATA lv_in TYPE string.
    lv_in = `a` && cl_abap_char_utilities=>newline && `b`.
    cl_abap_unit_assert=>assert_equals(
      exp = `a\nb`
      act = zcl_pia_00_json_util=>escape( lv_in ) ).
  ENDMETHOD.

  METHOD escape_nonascii.
    cl_abap_unit_assert=>assert_equals(
      exp = `\u00C4`
      act = zcl_pia_00_json_util=>escape( `Ä` ) ).
  ENDMETHOD.

  METHOD escape_mixed.
    DATA lv_in TYPE string.
    lv_in = `a"b` && cl_abap_char_utilities=>newline && `Ä`.
    cl_abap_unit_assert=>assert_equals(
      exp = `a\"b\n\u00C4`
      act = zcl_pia_00_json_util=>escape( lv_in ) ).
  ENDMETHOD.

  METHOD escape_emoji_pair.
    " known open-steamgate runtime issue: the surrogate pair does not convert,
    " so the emoji is dropped; left red on purpose
    DATA lv_in TYPE string.
    lv_in = `a` && cl_abap_conv_in_ce=>uccp( 'D83D' ) &&
            cl_abap_conv_in_ce=>uccp( 'DE0A' ) && `b`.
    cl_abap_unit_assert=>assert_equals(
      exp = `a\uD83D\uDE0Ab`
      act = zcl_pia_00_json_util=>escape( lv_in ) ).
  ENDMETHOD.

  METHOD unescape_ctrl.
    DATA lv_exp TYPE string.
    lv_exp = `a` && cl_abap_char_utilities=>newline && `b`.
    cl_abap_unit_assert=>assert_equals(
      exp = lv_exp
      act = zcl_pia_00_json_util=>unescape( `a\nb` ) ).
  ENDMETHOD.

  METHOD unescape_backslash_quote.
    cl_abap_unit_assert=>assert_equals(
      exp = `a"b\c`
      act = zcl_pia_00_json_util=>unescape( `a\"b\\c` ) ).
  ENDMETHOD.

  METHOD unescape_hex_known.
    cl_abap_unit_assert=>assert_equals(
      exp = `A`
      act = zcl_pia_00_json_util=>unescape( `\u0041` ) ).
  ENDMETHOD.

  METHOD unescape_hex_other.
    cl_abap_unit_assert=>assert_equals(
      exp = cl_abap_conv_in_ce=>uccp( '00C4' )
      act = zcl_pia_00_json_util=>unescape( `\u00C4` ) ).
  ENDMETHOD.

  METHOD roundtrip_nonascii.
    DATA lv TYPE string VALUE `ÄÖü`.
    cl_abap_unit_assert=>assert_equals(
      exp = lv
      act = zcl_pia_00_json_util=>unescape( zcl_pia_00_json_util=>escape( lv ) ) ).
  ENDMETHOD.

  METHOD extract_simple.
    cl_abap_unit_assert=>assert_equals(
      exp = `pia`
      act = zcl_pia_00_json_util=>extract_str(
              iv_json = `{"name":"pia"}` iv_name = `name` ) ).
  ENDMETHOD.

  METHOD extract_escaped_quote.
    cl_abap_unit_assert=>assert_equals(
      exp = `a\"b`
      act = zcl_pia_00_json_util=>extract_str(
              iv_json = `{"text":"a\"b"}` iv_name = `text` ) ).
  ENDMETHOD.

  METHOD extract_missing.
    cl_abap_unit_assert=>assert_equals(
      exp = ``
      act = zcl_pia_00_json_util=>extract_str(
              iv_json = `{"a":1}` iv_name = `name` ) ).
  ENDMETHOD.

  METHOD balanced_object.
    cl_abap_unit_assert=>assert_equals(
      exp = `{"b":1}`
      act = zcl_pia_00_json_util=>extract_balanced(
              iv_json = `{"a":{"b":1}}` iv_key = `a`
              iv_open = `{` iv_close = `}` ) ).
  ENDMETHOD.

  METHOD balanced_nested_and_array.
    cl_abap_unit_assert=>assert_equals(
      exp = `[{"id":"c1"},{"id":"c2"}]`
      act = zcl_pia_00_json_util=>extract_balanced(
              iv_json = `{"tool_calls":[{"id":"c1"},{"id":"c2"}]}`
              iv_key = `tool_calls` iv_open = `[` iv_close = `]` ) ).
  ENDMETHOD.

  METHOD balanced_missing_key.
    cl_abap_unit_assert=>assert_equals(
      exp = ``
      act = zcl_pia_00_json_util=>extract_balanced(
              iv_json = `{"a":1}` iv_key = `tool_calls`
              iv_open = `[` iv_close = `]` ) ).
  ENDMETHOD.

  METHOD balanced_no_open_bracket.
    cl_abap_unit_assert=>assert_equals(
      exp = ``
      act = zcl_pia_00_json_util=>extract_balanced(
              iv_json = `{"a":"b"}` iv_key = `a`
              iv_open = `[` iv_close = `]` ) ).
  ENDMETHOD.

  METHOD balanced_unclosed.
    cl_abap_unit_assert=>assert_equals(
      exp = `{"b":1}`
      act = zcl_pia_00_json_util=>extract_balanced(
              iv_json = `{"a":{"b":1}` iv_key = `a`
              iv_open = `{` iv_close = `}` ) ).
  ENDMETHOD.

  METHOD balanced_open_brace_in_string.
    " regression: an unbalanced '{' inside a JSON string value used to be
    " counted as structure, so the object ran past its real end
    cl_abap_unit_assert=>assert_equals(
      exp = `{"s":"lv_open = '{'.","n":1}`
      act = zcl_pia_00_json_util=>extract_balanced(
              iv_json = `{"a":{"s":"lv_open = '{'.","n":1}}` iv_key = `a`
              iv_open = `{` iv_close = `}` ) ).
  ENDMETHOD.

  METHOD balanced_close_brace_in_string.
    " regression: a '}' inside a JSON string value closed the object too early
    cl_abap_unit_assert=>assert_equals(
      exp = `{"s":"}","n":1}`
      act = zcl_pia_00_json_util=>extract_balanced(
              iv_json = `{"a":{"s":"}","n":1}}` iv_key = `a`
              iv_open = `{` iv_close = `}` ) ).
  ENDMETHOD.

  METHOD split_simple.
    DATA(lt) = zcl_pia_00_json_util=>split_entries( `[{"a":1}]` ).
    cl_abap_unit_assert=>assert_equals( exp = 1 act = lines( lt ) ).
    cl_abap_unit_assert=>assert_equals( exp = `{"a":1}` act = lt[ 1 ] ).
  ENDMETHOD.

  METHOD split_two_entries.
    DATA(lt) = zcl_pia_00_json_util=>split_entries(
      `[{"id":"c1","function":{"name":"f"}},{"id":"c2","function":{"name":"g"}}]` ).
    cl_abap_unit_assert=>assert_equals( exp = 2 act = lines( lt ) ).
    cl_abap_unit_assert=>assert_equals( exp = `{"id":"c2","function":{"name":"g"}}` act = lt[ 2 ] ).
  ENDMETHOD.

  METHOD split_brace_in_string.
    " bug report: two tool calls, the first carries a source with a lone '{'
    " (lv_open = '{'.) in the escaped arguments string; the brace was counted
    " as an opener, the first entry swallowed the rest of the array and the
    " second tool call was lost
    DATA lv_arr TYPE string.
    lv_arr = `[{"type":"function_call","call_id":"c1","name":"write_source",` &&
             `"arguments":"{\"name\":\"ZCL_DEMO\",\"source\":\"DATA lv_open = '{'.\"}"},` &&
             `{"type":"function_call","call_id":"c2","name":"read_object",` &&
             `"arguments":"{\"name\":\"ZCL_OTHER\"}"}]`.
    DATA(lt) = zcl_pia_00_json_util=>split_entries( lv_arr ).

    cl_abap_unit_assert=>assert_equals(
      exp  = 2
      act  = lines( lt )
      msg  = 'second tool call was lost'
      quit = cl_abap_unit_assert=>quit-no ).
    IF lines( lt ) >= 1.
      cl_abap_unit_assert=>assert_equals(
        exp  = `{"type":"function_call","call_id":"c1","name":"write_source",` &&
               `"arguments":"{\"name\":\"ZCL_DEMO\",\"source\":\"DATA lv_open = '{'.\"}"}`
        act  = lt[ 1 ]
        msg  = 'first entry contains trailing text'
        quit = cl_abap_unit_assert=>quit-no ).
    ENDIF.
    IF lines( lt ) >= 2.
      cl_abap_unit_assert=>assert_equals(
        exp  = `{"type":"function_call","call_id":"c2","name":"read_object",` &&
               `"arguments":"{\"name\":\"ZCL_OTHER\"}"}`
        act  = lt[ 2 ]
        msg  = 'second entry wrong'
        quit = cl_abap_unit_assert=>quit-no ).
    ENDIF.
  ENDMETHOD.

  METHOD split_entries_empty.
    DATA(lt) = zcl_pia_00_json_util=>split_entries( `[]` ).
    cl_abap_unit_assert=>assert_equals( exp = 0 act = lines( lt ) ).
  ENDMETHOD.

  METHOD to_int_basic.
    cl_abap_unit_assert=>assert_equals(
      exp = 65 act = zcl_pia_00_json_util=>to_int( `41` ) ).
  ENDMETHOD.

  METHOD to_int_lowercase.
    cl_abap_unit_assert=>assert_equals(
      exp = 78 act = zcl_pia_00_json_util=>to_int( `4e` ) ).
  ENDMETHOD.

  METHOD to_int_invalid.
    cl_abap_unit_assert=>assert_equals(
      exp = 0 act = zcl_pia_00_json_util=>to_int( `zz` ) ).
  ENDMETHOD.

  METHOD to_hex4_zero.
    cl_abap_unit_assert=>assert_equals(
      exp = `0000` act = zcl_pia_00_json_util=>to_hex4( 0 ) ).
  ENDMETHOD.

  METHOD to_hex4_padding.
    cl_abap_unit_assert=>assert_equals(
      exp = `000A` act = zcl_pia_00_json_util=>to_hex4( 10 ) ).
  ENDMETHOD.

  METHOD to_hex4_cyrillic_codepoint.
    " Cyrillic А = U+0410 = 1040
    cl_abap_unit_assert=>assert_equals(
      exp = `0410` act = zcl_pia_00_json_util=>to_hex4( 1040 ) ).
  ENDMETHOD.

  METHOD to_hex4_euro_codepoint.
    " euro sign = U+20AC = 8364
    cl_abap_unit_assert=>assert_equals(
      exp = `20AC` act = zcl_pia_00_json_util=>to_hex4( 8364 ) ).
  ENDMETHOD.

  METHOD to_hex4_max.
    cl_abap_unit_assert=>assert_equals(
      exp = `FFFF` act = zcl_pia_00_json_util=>to_hex4( 65535 ) ).
  ENDMETHOD.

  METHOD hexval_digits.
    cl_abap_unit_assert=>assert_equals(
      exp = 15 act = zcl_pia_00_json_util=>hexval( `F` ) ).
    cl_abap_unit_assert=>assert_equals(
      exp = 9 act = zcl_pia_00_json_util=>hexval( `9` ) ).
  ENDMETHOD.

  METHOD hexval_lower.
    cl_abap_unit_assert=>assert_equals(
      exp = 10 act = zcl_pia_00_json_util=>hexval( `a` ) ).
  ENDMETHOD.

  METHOD hexval_invalid.
    cl_abap_unit_assert=>assert_equals(
      exp = 0 act = zcl_pia_00_json_util=>hexval( `g` ) ).
  ENDMETHOD.

ENDCLASS.
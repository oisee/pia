"* Unit tests for zcl_pia_00_json_util.
"* Expected values are derived from the ACTUAL code behavior.
"* SUSPECT marks places where behavior deviates from the JSON spec / task expectations.

CLASS ltcl_json_util DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    " -- escape
    METHODS escape_emoji_pair FOR TESTING.
    METHODS escape_quotes FOR TESTING.
    METHODS escape_backslash FOR TESTING.
    METHODS escape_newline FOR TESTING.
    METHODS escape_nonascii FOR TESTING.
    METHODS escape_mixed FOR TESTING.
    " -- unescape
    METHODS unescape_ctrl FOR TESTING.
    METHODS unescape_backslash_quote FOR TESTING.
    METHODS unescape_hex_known FOR TESTING.
    METHODS unescape_hex_other FOR TESTING.
    METHODS roundtrip_nonascii FOR TESTING.
    " -- extract_str
    METHODS extract_simple FOR TESTING.
    METHODS extract_escaped_quote FOR TESTING.
    METHODS extract_missing FOR TESTING.
    " -- extract_balanced
    METHODS balanced_object FOR TESTING.
    METHODS balanced_nested_and_array FOR TESTING.
    METHODS balanced_missing_key FOR TESTING.
    METHODS balanced_no_open_bracket FOR TESTING.
    METHODS balanced_unclosed FOR TESTING.
    " -- to_int / to_hex4 / hexval
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

  " ============================== escape ==============================

  METHOD escape_quotes.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pia_00_json_util=>escape( `a"b` )
      exp = `a\"b`
      msg = 'escape: double quote must become backslash-quote' ).

    cl_abap_unit_assert=>assert_equals(
      act = zcl_pia_00_json_util=>escape( `"` )
      exp = `\"`
      msg = 'escape: lone double quote' ).
  ENDMETHOD.

  METHOD escape_backslash.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pia_00_json_util=>escape( `a\b` )
      exp = `a\\b`
      msg = 'escape: backslash must be doubled' ).

    cl_abap_unit_assert=>assert_equals(
      act = zcl_pia_00_json_util=>escape( `\\` )
      exp = `\\\\`
      msg = 'escape: two backslashes become four' ).
  ENDMETHOD.

  METHOD escape_newline.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pia_00_json_util=>escape( `a` && |\n| && `b` )
      exp = `a\nb`
      msg = 'escape: LF becomes literal \n sequence' ).

    " ELSEIF lv_ch = |\r| branch of the WHEN OTHERS block.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pia_00_json_util=>escape( `a` && |\r| && `b` )
      exp = `a\rb`
      msg = 'escape: CR becomes literal \r sequence' ).

    cl_abap_unit_assert=>assert_equals(
      act = zcl_pia_00_json_util=>escape( `a` && |\t| && `b` )
      exp = `a\tb`
      msg = 'escape: TAB becomes literal \t sequence' ).
  ENDMETHOD.

  METHOD escape_nonascii.
    " 'Ж' = U+0416, UTF-8 bytes D0 96 -> hex string 'D096', strlen 4 > 2 ->
    " \u branch, n = 2: cp = (to_int('D0')-192)*64 + (to_int('96')-128)
    "                  = (208-192)*64 + (150-128) = 1046
    " to_hex4( 1046 ) = '0416' -> literal \u0416.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pia_00_json_util=>escape( `Ж` )
      exp = `\u0416`
      msg = 'escape: cyrillic Ж -> \u0416 (cp 1046 = 0x0416)' ).

    " '€' = U+20AC, UTF-8 bytes E2 82 AC -> hex string 'E282AC', strlen 6 > 2 ->
    " \u branch, n = 3: cp = (226-224)*4096 + (130-128)*64 + (172-128)
    "                  = 8192 + 128 + 44 = 8364 (dec) = 20AC (hex)
    " to_hex4( 8364 ) = '20AC' -> literal \u20AC.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pia_00_json_util=>escape( `€` )
      exp = `\u20AC`
      msg = 'escape: euro sign -> \u20AC (cp 8364 = 0x20AC)' ).
  ENDMETHOD.

  METHOD escape_mixed.
    " 'x' (ASCII) -> hex '61', strlen 2 <= 2 -> fast path, kept as-is;
    " 'Ж' -> \u branch (see escape_nonascii) -> \u0416.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pia_00_json_util=>escape( `xЖ` )
      exp = `x\u0416`
      msg = 'escape: mixed ASCII + cyrillic -> x\u0416' ).
  ENDMETHOD.

  " ============================== unescape ==============================

  METHOD unescape_ctrl.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pia_00_json_util=>unescape( `a\nb` )
      exp = `a` && |\n| && `b`
      msg = 'unescape: \n sequence becomes LF' ).

    " WHEN `r` branch -> |\r|.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pia_00_json_util=>unescape( `a\rb` )
      exp = `a` && |\r| && `b`
      msg = 'unescape: \r sequence becomes CR' ).

    cl_abap_unit_assert=>assert_equals(
      act = zcl_pia_00_json_util=>unescape( `a\tb` )
      exp = `a` && |\t| && `b`
      msg = 'unescape: \t sequence becomes TAB' ).
  ENDMETHOD.

  METHOD unescape_backslash_quote.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pia_00_json_util=>unescape( `a\\b` )
      exp = `a\b`
      msg = 'unescape: \\ becomes single backslash' ).

    cl_abap_unit_assert=>assert_equals(
      act = zcl_pia_00_json_util=>unescape( `\"` )
      exp = `"`
      msg = 'unescape: \" becomes double quote' ).
  ENDMETHOD.

  METHOD unescape_hex_known.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pia_00_json_util=>unescape( `\u0022` )
      exp = `"`
      msg = 'unescape: \u0022 -> double quote' ).

    cl_abap_unit_assert=>assert_equals(
      act = zcl_pia_00_json_util=>unescape( `\u003e` )
      exp = `>`
      msg = 'unescape: \u003e -> greater-than' ).

    " Uppercase hex letters also work (to_lower is applied inside the CASE only).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pia_00_json_util=>unescape( `\u003E` )
      exp = `>`
      msg = 'unescape: \u003E (uppercase hex) -> greater-than' ).
  ENDMETHOD.

  METHOD unescape_hex_other.
    " \uXXXX decodes to the character (Cyrillic and 3-byte UTF-8 alike).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pia_00_json_util=>unescape( `\u0416` )
      exp = `Ж`
      msg = 'unescape: \u0416 -> Ж' ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pia_00_json_util=>unescape( `\u20AC` )
      exp = `€`
      msg = 'unescape: \u20AC -> €' ).

    " SUSPECT: short \u sequence is silently dropped, rest is kept.
    " 'a\ub' (len 4): backslash at 0-based offset 1, 'u' branch,
    " lv_j + 4 = 6 < 4 is false -> nothing appended, lv_i jumps by 2 past 'u',
    " then 'b' is copied -> 'ab'.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pia_00_json_util=>unescape( `a\ub` )
      exp = `ab`
      msg = 'unescape: malformed \u swallowed, b kept (SUSPECT)' ).
  ENDMETHOD.

  METHOD roundtrip_nonascii.
    " escape( `Ж€` ) = \u0416\u20AC, but unescape echoes both sequences back
    " verbatim (WHEN OTHERS), so act is \u0416\u20AC, not `Ж€` -> test fails now.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pia_00_json_util=>unescape( zcl_pia_00_json_util=>escape( `Ж€` ) )
      exp = `Ж€`
      msg = 'round-trip: unescape(escape(Ж€)) must give Ж€ back' ).
  ENDMETHOD.

  " ============================== extract_str ==============================

  METHOD extract_simple.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pia_00_json_util=>extract_str( iv_json = `{"a":"b"}` iv_name = `a` )
      exp = `b`
      msg = 'extract_str: simple field' ).

    cl_abap_unit_assert=>assert_equals(
      act = zcl_pia_00_json_util=>extract_str( iv_json = `{"msg":"hello world"}` iv_name = `msg` )
      exp = `hello world`
      msg = 'extract_str: value with spaces' ).

    " Whitespace around the colon is tolerated by the regex.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pia_00_json_util=>extract_str( iv_json = `{"a": "b"}` iv_name = `a` )
      exp = `b`
      msg = 'extract_str: space after colon' ).
  ENDMETHOD.

  METHOD extract_escaped_quote.
    " Value is returned RAW (still escaped) - unescape() is a separate step.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pia_00_json_util=>extract_str( iv_json = `{"a":"x\"y"}` iv_name = `a` )
      exp = `x\"y`
      msg = 'extract_str: escaped quote inside value returned raw' ).

    cl_abap_unit_assert=>assert_equals(
      act = zcl_pia_00_json_util=>extract_str( iv_json = `{"a":"p\\q"}` iv_name = `a` )
      exp = `p\\q`
      msg = 'extract_str: escaped backslash inside value returned raw' ).
  ENDMETHOD.

  METHOD extract_missing.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pia_00_json_util=>extract_str( iv_json = `{"x":"1"}` iv_name = `a` )
      exp = ``
      msg = 'extract_str: missing field -> empty' ).

    " "a" pattern must not match key "ab" (quotes are part of the pattern).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pia_00_json_util=>extract_str( iv_json = `{"ab":"x"}` iv_name = `a` )
      exp = ``
      msg = 'extract_str: partial key match -> empty' ).
  ENDMETHOD.

  " ============================== extract_balanced ==============================

  METHOD balanced_object.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pia_00_json_util=>extract_balanced(
              iv_json = `{"o":{"x":1},"y":2}` iv_key = `o` iv_open = `{` iv_close = `}` )
      exp = `{"x":1}`
      msg = 'extract_balanced: inner object up to matching brace' ).
  ENDMETHOD.

  METHOD balanced_nested_and_array.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pia_00_json_util=>extract_balanced(
              iv_json = `{"o":{"a":{"b":2}}}` iv_key = `o` iv_open = `{` iv_close = `}` )
      exp = `{"a":{"b":2}}`
      msg = 'extract_balanced: nested braces tracked by depth' ).

    cl_abap_unit_assert=>assert_equals(
      act = zcl_pia_00_json_util=>extract_balanced(
              iv_json = `{"a":[1,[2,3]]}` iv_key = `a` iv_open = `[` iv_close = `]` )
      exp = `[1,[2,3]]`
      msg = 'extract_balanced: nested square brackets' ).
  ENDMETHOD.

  METHOD balanced_missing_key.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pia_00_json_util=>extract_balanced(
              iv_json = `{"x":1}` iv_key = `o` iv_open = `{` iv_close = `}` )
      exp = ``
      msg = 'extract_balanced: missing key -> empty' ).
  ENDMETHOD.

  METHOD balanced_no_open_bracket.
    " Key 'o' is found, but there is no opening bracket after it:
    " lv_rest starts AFTER the key match, so the leading '{' of the JSON itself
    " is never seen -> second FIND fails -> RETURN -> rv_ stays initial ('').
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pia_00_json_util=>extract_balanced(
              iv_json = `{"o":"txt"}` iv_key = `o` iv_open = `{` iv_close = `}` )
      exp = ``
      msg = 'extract_balanced: key present, no opening bracket -> empty' ).
  ENDMETHOD.

  METHOD balanced_unclosed.
    " SUSPECT: for unbalanced input the method returns the tail anyway.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pia_00_json_util=>extract_balanced(
              iv_json = `{"o":{"x":1` iv_key = `o` iv_open = `{` iv_close = `}` )
      exp = `{"x":1`
      msg = 'extract_balanced: unclosed input returns tail (SUSPECT)' ).
  ENDMETHOD.

  " ============================== to_int / to_hex4 / hexval ==============================

  METHOD to_int_basic.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pia_00_json_util=>to_int( `0A` )
      exp = 10
      msg = 'to_int: 0A -> 10' ).

    cl_abap_unit_assert=>assert_equals(
      act = zcl_pia_00_json_util=>to_int( `FF` )
      exp = 255
      msg = 'to_int: FF -> 255' ).
  ENDMETHOD.

  METHOD to_int_lowercase.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pia_00_json_util=>to_int( `e2` )
      exp = 226
      msg = 'to_int: lowercase hex e2 -> 226' ).
  ENDMETHOD.

  METHOD to_int_invalid.
    " SUSPECT: hexval has no WHEN OTHERS, invalid digits silently map to 0.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pia_00_json_util=>to_int( `GG` )
      exp = 0
      msg = 'to_int: invalid hex GG -> 0 (SUSPECT)' ).
  ENDMETHOD.

  METHOD to_hex4_zero.
    " 0 MOD 16 = 0 on all four iterations -> 0000.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pia_00_json_util=>to_hex4( 0 )
      exp = `0000`
      msg = 'to_hex4: zero -> 0000' ).
  ENDMETHOD.

  METHOD to_hex4_padding.
    " True HEX conversion with zero padding to 4 digits:
    " 255 = 0x00FF -> digits F, F, 0, 0 -> '00FF';
    " 10  = 0x000A -> digits A, 0, 0, 0 -> '000A'.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pia_00_json_util=>to_hex4( 255 )
      exp = `00FF`
      msg = 'to_hex4: 255 -> 00FF' ).

    cl_abap_unit_assert=>assert_equals(
      act = zcl_pia_00_json_util=>to_hex4( 10 )
      exp = `000A`
      msg = 'to_hex4: 10 -> 000A' ).
  ENDMETHOD.

  METHOD to_hex4_cyrillic_codepoint.
    " Codepoint of 'Ж' = 1046 dec = 0x0416:
    " 1046 = 65*16+6 -> '6'; 65 = 4*16+1 -> '1'; 4 -> '4'; 0 -> '0' -> '0416'.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pia_00_json_util=>to_hex4( 1046 )
      exp = `0416`
      msg = 'to_hex4: 1046 -> 0416' ).
  ENDMETHOD.

  METHOD to_hex4_euro_codepoint.
    " Codepoint of '€' = 8364 dec = 0x20AC:
    " 8364 = 522*16+12 -> 'C'; 522 = 32*16+10 -> 'A'; 32 = 2*16+0 -> '0'; 2 -> '2' -> '20AC'.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pia_00_json_util=>to_hex4( 8364 )
      exp = `20AC`
      msg = 'to_hex4: 8364 -> 20AC' ).
  ENDMETHOD.

  METHOD to_hex4_max.
    " 65535 = 0xFFFF -> four 'F' digits, fits exactly in 4 hex digits.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pia_00_json_util=>to_hex4( 65535 )
      exp = `FFFF`
      msg = 'to_hex4: 65535 -> FFFF' ).
  ENDMETHOD.

  METHOD hexval_digits.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pia_00_json_util=>hexval( `0` )
      exp = 0
      msg = 'hexval: 0 -> 0' ).

    cl_abap_unit_assert=>assert_equals(
      act = zcl_pia_00_json_util=>hexval( `F` )
      exp = 15
      msg = 'hexval: F -> 15' ).
  ENDMETHOD.

  METHOD hexval_lower.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pia_00_json_util=>hexval( `a` )
      exp = 10
      msg = 'hexval: lowercase a -> 10' ).

    " Only the first character is evaluated.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pia_00_json_util=>hexval( `AB` )
      exp = 10
      msg = 'hexval: AB -> 10, first char only' ).
  ENDMETHOD.

  METHOD hexval_invalid.
    " SUSPECT: no WHEN OTHERS branch, any non-hex char silently maps to 0.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pia_00_json_util=>hexval( `z` )
      exp = 0
      msg = 'hexval: invalid z -> 0 (SUSPECT)' ).
  ENDMETHOD.

  METHOD escape_emoji_pair.
    " U+1F60A is two UTF-16 units; built at run time (no non-BMP literal in the source)
    DATA(lv_emoji) = zcl_pia_00_json_util=>unescape( `\uD83D\uDE0A` ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pia_00_json_util=>escape( |a{ lv_emoji }b| )
      exp = `a\uD83D\uDE0Ab`
      msg = 'escape: surrogate pair -> \uD83D\uDE0A' ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pia_00_json_util=>unescape( zcl_pia_00_json_util=>escape( lv_emoji ) )
      exp = lv_emoji
      msg = 'emoji round-trip' ).
  ENDMETHOD.

ENDCLASS.

CLASS zcl_pia_00_json_util DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    CLASS-METHODS escape
      IMPORTING iv_        TYPE string
      RETURNING VALUE(rv_) TYPE string.

    CLASS-METHODS codepoint
      IMPORTING iv_        TYPE string
      RETURNING VALUE(rv_) TYPE i.

    CLASS-METHODS to_int
      IMPORTING iv_        TYPE string
      RETURNING VALUE(rv_) TYPE i.

    CLASS-METHODS to_hex4
      IMPORTING iv_        TYPE i
      RETURNING VALUE(rv_) TYPE string.

    CLASS-METHODS hexval
      IMPORTING iv_        TYPE string
      RETURNING VALUE(rv_) TYPE i.

    CLASS-METHODS extract_str
      IMPORTING iv_json     TYPE string
                iv_name     TYPE string
      RETURNING VALUE(rv_)  TYPE string.

    CLASS-METHODS unescape
      IMPORTING iv_        TYPE string
      RETURNING VALUE(rv_) TYPE string.

    " top-level {...} entries of a JSON array string
    CLASS-METHODS split_entries
      IMPORTING iv_arr      TYPE string
      RETURNING VALUE(rt_)  TYPE string_table.

    CLASS-METHODS extract_balanced
      IMPORTING iv_json     TYPE string
                iv_key      TYPE string
                iv_open     TYPE string
                iv_close    TYPE string
      RETURNING VALUE(rv_)  TYPE string.

ENDCLASS.

CLASS zcl_pia_00_json_util IMPLEMENTATION.

  METHOD escape.
    DATA lv_i TYPE i.
    DATA lv_len TYPE i.
    DATA lv_ch TYPE string.
    DATA lv_cp TYPE i.
    DATA lv_from TYPE i.
    lv_len = strlen( iv_ ).
    WHILE lv_i < lv_len.
      lv_ch = iv_+lv_i(1).
      CASE lv_ch.
        WHEN `\`. rv_ = rv_ && `\\`.
        WHEN `"`. rv_ = rv_ && `\"`.
        WHEN OTHERS.
          IF lv_ch = |\n|.
            rv_ = rv_ && `\n`.
          ELSEIF lv_ch = |\r|.
            rv_ = rv_ && `\r`.
          ELSEIF lv_ch = |\t|.
            rv_ = rv_ && `\t`.
          ELSE.
            " codepoint from the UTF-8 bytes, read with xstrlen and x(1) offsets: portable to SAP
            " (the old strlen/to_upper on an xstring did not compile there) and independent of
            " cl_abap_conv_out_ce=>uccpi, which is wrong in open-abap-core (high byte * 255)
            " a character outside the BMP (emoji) is two UTF-16 units: alone, a unit fails to convert
            " on SAP (CX_SY_CONVERSION_CODEPAGE) and becomes U+FFFD in OSG; take the pair together
            lv_cp = codepoint( lv_ch ).
            IF lv_cp = 65533 AND lv_i + 1 < lv_len.
              lv_from = lv_i.
              lv_cp = codepoint( substring( val = iv_ off = lv_from len = 2 ) ).
              IF lv_cp >= 65536.
                lv_cp = lv_cp - 65536.
                rv_ = rv_ && `\u` && to_hex4( 55296 + lv_cp DIV 1024 ) && `\u` && to_hex4( 56320 + lv_cp MOD 1024 ).
                lv_i = lv_i + 2.
                CONTINUE.
              ENDIF.
              lv_cp = 65533.
            ENDIF.
            IF lv_cp >= 32 AND lv_cp < 128.
              rv_ = rv_ && lv_ch.
            ELSE.
              rv_ = rv_ && `\u` && to_hex4( lv_cp ).
            ENDIF.
          ENDIF.
      ENDCASE.
      lv_i = lv_i + 1.
    ENDWHILE.
  ENDMETHOD.

  METHOD codepoint.
    DATA lv_x TYPE xstring.
    DATA lv_b TYPE x LENGTH 1.
    DATA lv_b0 TYPE i.
    DATA lv_b1 TYPE i.
    DATA lv_b2 TYPE i.
    DATA lv_b3 TYPE i.
    " a lone UTF-16 surrogate does not convert on SAP; caught here because the method declares
    " no RAISING (outside it the exception would arrive as CX_SY_NO_HANDLER)
    TRY.
        lv_x = cl_abap_conv_codepage=>create_out( )->convert( iv_ ).
      CATCH cx_root.
        rv_ = 65533.
        RETURN.
    ENDTRY.
    lv_b = lv_x+0(1).
    lv_b0 = lv_b.
    CASE xstrlen( lv_x ).
      WHEN 1.
        rv_ = lv_b0.
      WHEN 2.
        lv_b = lv_x+1(1).
        lv_b1 = lv_b.
        rv_ = ( lv_b0 - 192 ) * 64 + ( lv_b1 - 128 ).
      WHEN 3.
        lv_b = lv_x+1(1).
        lv_b1 = lv_b.
        lv_b = lv_x+2(1).
        lv_b2 = lv_b.
        rv_ = ( lv_b0 - 224 ) * 4096 + ( lv_b1 - 128 ) * 64 + ( lv_b2 - 128 ).
      WHEN 4.
        lv_b = lv_x+1(1).
        lv_b1 = lv_b.
        lv_b = lv_x+2(1).
        lv_b2 = lv_b.
        lv_b = lv_x+3(1).
        lv_b3 = lv_b.
        rv_ = ( lv_b0 - 240 ) * 262144 + ( lv_b1 - 128 ) * 4096 + ( lv_b2 - 128 ) * 64 + ( lv_b3 - 128 ).
      WHEN OTHERS.
        rv_ = 65533.
    ENDCASE.
  ENDMETHOD.

  METHOD to_int.
    " hex pair -> int
    rv_ = hexval( substring( val = iv_ off = 0 len = 1 ) ) * 16
          + hexval( substring( val = iv_ off = 1 len = 1 ) ).
  ENDMETHOD.

  METHOD to_hex4.
    " 4-digit uppercase hex (was decimal: 1046 -> '1046' instead of '0416')
    CONSTANTS c_hex TYPE string VALUE `0123456789ABCDEF`.
    DATA lv_n TYPE i.
    DATA lv_d TYPE i.
    lv_n = iv_.
    DO 4 TIMES.
      lv_d = lv_n MOD 16.
      rv_ = substring( val = c_hex off = lv_d len = 1 ) && rv_.
      lv_n = lv_n DIV 16.
    ENDDO.
  ENDMETHOD.

  METHOD hexval.
    CASE to_upper( substring( val = iv_ off = 0 len = 1 ) ).
      WHEN '0'. rv_ = 0. WHEN '1'. rv_ = 1. WHEN '2'. rv_ = 2. WHEN '3'. rv_ = 3.
      WHEN '4'. rv_ = 4. WHEN '5'. rv_ = 5. WHEN '6'. rv_ = 6. WHEN '7'. rv_ = 7.
      WHEN '8'. rv_ = 8. WHEN '9'. rv_ = 9. WHEN 'A'. rv_ = 10. WHEN 'B'. rv_ = 11.
      WHEN 'C'. rv_ = 12. WHEN 'D'. rv_ = 13. WHEN 'E'. rv_ = 14. WHEN 'F'. rv_ = 15.
    ENDCASE.
  ENDMETHOD.

  METHOD extract_str.
    DATA(lv_re) = '"' && iv_name && '"\s*:\s*"((?:[^"\\]|\\.)*)"'.
    FIND FIRST OCCURRENCE OF PCRE lv_re IN iv_json SUBMATCHES rv_.
  ENDMETHOD.

  METHOD unescape.
    DATA lv_i TYPE i VALUE 0.
    DATA lv_len TYPE i.
    DATA lv_j TYPE i.
    lv_len = strlen( iv_ ).
    WHILE lv_i < lv_len.
      IF iv_+lv_i(1) = `\` AND lv_i + 1 < lv_len.
        lv_j = lv_i + 1.
        CASE iv_+lv_j(1).
          WHEN `n`. rv_ = rv_ && |\n|.
          WHEN `r`. rv_ = rv_ && |\r|.
          WHEN `t`. rv_ = rv_ && |\t|.
          WHEN `u`.
            " \uXXXX -> character (was: only 5 ASCII codepoints, Cyrillic stayed escaped)
            DATA lv_hex TYPE string.
            DATA lv_char TYPE string.
            IF lv_j + 4 < lv_len.
              lv_hex = iv_+lv_j(5).
              lv_hex = lv_hex+1(4).
              TRY.
                  lv_char = cl_abap_conv_in_ce=>uccp( to_upper( lv_hex ) ).
                  rv_ = rv_ && lv_char.
                CATCH cx_root.
                  rv_ = rv_ && `\u` && lv_hex.
              ENDTRY.
              lv_i = lv_i + 4.
            ENDIF.
          WHEN OTHERS. rv_ = rv_ && iv_+lv_j(1).
        ENDCASE.
        lv_i = lv_i + 2.
      ELSE.
        rv_ = rv_ && iv_+lv_i(1).
        lv_i = lv_i + 1.
      ENDIF.
    ENDWHILE.
  ENDMETHOD.

  METHOD split_entries.
    " top-level {...} entries of a JSON array string; defensive: every access is clamped.
    " String-aware: a quote opens/closes a JSON string only when the backslash run
    " before it is even (odd = escaped quote); braces inside a string value are data,
    " not structure. A lone brace in a tool-call argument used to keep the depth
    " counter open, so the first entry swallowed the rest of the array and every
    " following tool call was lost (found by SPLIT_BRACE_IN_STRING).
    DATA lv_len TYPE i.
    DATA lv_i TYPE i VALUE 0.
    DATA lv_run TYPE i VALUE 0.
    DATA lv_in TYPE abap_bool VALUE abap_false.
    DATA lv_depth TYPE i VALUE 0.
    DATA lv_start TYPE i VALUE 0.
    DATA lv_n TYPE i.
    lv_len = strlen( iv_arr ).
    WHILE lv_i < lv_len.
      IF iv_arr+lv_i(1) = `\`.
        lv_run = lv_run + 1.
        lv_i = lv_i + 1.
        CONTINUE.
      ENDIF.
      IF iv_arr+lv_i(1) = '"'.
        IF lv_run MOD 2 = 0.
          IF lv_in = abap_true.
            lv_in = abap_false.
          ELSE.
            lv_in = abap_true.
          ENDIF.
        ENDIF.
      ELSEIF lv_in = abap_false.
        IF iv_arr+lv_i(1) = '{'.
          IF lv_depth = 0.
            lv_start = lv_i.
          ENDIF.
          lv_depth = lv_depth + 1.
        ELSEIF iv_arr+lv_i(1) = '}'.
          IF lv_depth > 0.
            lv_depth = lv_depth - 1.
            IF lv_depth = 0.
              lv_n = lv_i - lv_start + 1.
              IF lv_start + lv_n > lv_len.
                lv_n = lv_len - lv_start.
              ENDIF.
              IF lv_n > 0.
                APPEND iv_arr+lv_start(lv_n) TO rt_.
              ENDIF.
            ENDIF.
          ENDIF.
        ENDIF.
      ENDIF.
      lv_run = 0.
      lv_i = lv_i + 1.
    ENDWHILE.
    IF lv_depth > 0 AND lv_start < lv_len.
      " unclosed trailing object: clamp to the end, as before
      lv_n = lv_len - lv_start.
      APPEND iv_arr+lv_start(lv_n) TO rt_.
    ENDIF.
  ENDMETHOD.

  METHOD extract_balanced.
    DATA lv_off TYPE i.
    DATA lv_pat TYPE string.
    DATA lv_rest TYPE string.
    DATA lv_len TYPE i.
    DATA lv_start TYPE i VALUE 0.
    DATA lv_run TYPE i VALUE 0.
    DATA lv_in TYPE abap_bool VALUE abap_false.
    DATA lv_depth TYPE i VALUE 1.
    DATA lv_pos TYPE i.
    DATA lv_len2 TYPE i.
    lv_pat = '"' && iv_key && '"'.
    FIND lv_pat IN iv_json MATCH OFFSET lv_off.
    IF sy-subrc <> 0. RETURN. ENDIF.
    lv_rest = iv_json+lv_off.
    lv_len = strlen( lv_rest ).
    " 1) find the opening delimiter outside JSON strings (a delimiter inside a
    "    string value is data, not structure)
    WHILE lv_start < lv_len.
      IF lv_rest+lv_start(1) = `\`.
        lv_run = lv_run + 1.
        lv_start = lv_start + 1.
        CONTINUE.
      ENDIF.
      IF lv_rest+lv_start(1) = '"'.
        IF lv_run MOD 2 = 0.
          IF lv_in = abap_true.
            lv_in = abap_false.
          ELSE.
            lv_in = abap_true.
          ENDIF.
        ENDIF.
      ELSEIF lv_in = abap_false AND lv_rest+lv_start(1) = iv_open.
        lv_run = 0.
        EXIT.
      ENDIF.
      lv_run = 0.
      lv_start = lv_start + 1.
    ENDWHILE.
    IF lv_start >= lv_len. RETURN. ENDIF.
    " 2) balanced scan; a quote toggles string state only after an even backslash
    "    run (odd = escaped quote), braces and brackets inside strings do not count.
    "    Blind counting broke on arguments like lv_open = brace: the depth stayed
    "    open and the value ran past the object into the following JSON members.
    lv_pos = lv_start.
    WHILE lv_pos < lv_len - 1 AND lv_depth > 0.
      lv_pos = lv_pos + 1.
      IF lv_rest+lv_pos(1) = `\`.
        lv_run = lv_run + 1.
        CONTINUE.
      ENDIF.
      IF lv_rest+lv_pos(1) = '"'.
        IF lv_run MOD 2 = 0.
          IF lv_in = abap_true.
            lv_in = abap_false.
          ELSE.
            lv_in = abap_true.
          ENDIF.
        ENDIF.
      ELSEIF lv_in = abap_false.
        IF lv_rest+lv_pos(1) = iv_open.
          lv_depth = lv_depth + 1.
        ELSEIF lv_rest+lv_pos(1) = iv_close.
          lv_depth = lv_depth - 1.
        ENDIF.
      ENDIF.
      lv_run = 0.
    ENDWHILE.
    lv_len2 = lv_pos - lv_start + 1.
    IF lv_start + lv_len2 > lv_len.
      lv_len2 = lv_len - lv_start.
    ENDIF.
    IF lv_len2 > 0.
      rv_ = lv_rest+lv_start(lv_len2).
    ENDIF.
  ENDMETHOD.

ENDCLASS.
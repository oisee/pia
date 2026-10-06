CLASS zcl_pia_00_json_util DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    CLASS-METHODS escape
      IMPORTING iv_        TYPE string
      RETURNING VALUE(rv_) TYPE string.

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
          ELSEIF strlen( cl_abap_codepage=>convert_to( lv_ch ) ) <= 2.
            rv_ = rv_ && lv_ch. " ASCII fast path
          ELSE.
            " non-ASCII -> \uXXXX (UTF-8 bytes -> codepoint)
            DATA(lv_hex) = to_upper( cl_abap_codepage=>convert_to( lv_ch ) ).
            DATA(lv_n) = strlen( lv_hex ) / 2.
            DATA lv_cp TYPE i.
            IF lv_n = 2.
              lv_cp = ( to_int( substring( val = lv_hex off = 0 len = 2 ) ) - 192 ) * 64 + ( to_int( substring( val = lv_hex off = 2 len = 2 ) ) - 128 ).
            ELSEIF lv_n = 3.
              lv_cp = ( to_int( substring( val = lv_hex off = 0 len = 2 ) ) - 224 ) * 4096
                    + ( to_int( substring( val = lv_hex off = 2 len = 2 ) ) - 128 ) * 64
                    + ( to_int( substring( val = lv_hex off = 4 len = 2 ) ) - 128 ).
            ELSE.
              lv_cp = 63. " fallback '?'
            ENDIF.
            rv_ = rv_ && `\u` && to_hex4( lv_cp ).
          ENDIF.
      ENDCASE.
      lv_i = lv_i + 1.
    ENDWHILE.
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
    FIND FIRST OCCURRENCE OF REGEX lv_re IN iv_json SUBMATCHES rv_.
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

  METHOD extract_balanced.
    DATA lv_off TYPE i.
    DATA(lv_pat) = '"' && iv_key && '"'.
    FIND lv_pat IN iv_json MATCH OFFSET lv_off.
    IF sy-subrc <> 0. RETURN. ENDIF.
    DATA lv_rest TYPE string.
    lv_rest = iv_json+lv_off.
    DATA lv_start TYPE i.
    FIND FIRST OCCURRENCE OF iv_open IN lv_rest MATCH OFFSET lv_start.
    IF sy-subrc <> 0. RETURN. ENDIF.
    DATA lv_depth TYPE i VALUE 1.
    DATA lv_pos TYPE i VALUE lv_start.
    WHILE lv_pos < strlen( lv_rest ) - 1 AND lv_depth > 0.
      lv_pos = lv_pos + 1.
      IF lv_rest+lv_pos(1) = iv_open.
        lv_depth = lv_depth + 1.
      ELSEIF lv_rest+lv_pos(1) = iv_close.
        lv_depth = lv_depth - 1.
      ENDIF.
    ENDWHILE.
    DATA(lv_len) = lv_pos - lv_start + 1.
    rv_ = lv_rest+lv_start(lv_len).
  ENDMETHOD.

ENDCLASS.

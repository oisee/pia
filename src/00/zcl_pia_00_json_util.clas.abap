CLASS zcl_pia_00_json_util DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    CLASS-METHODS escape
      IMPORTING iv_         TYPE string
      RETURNING VALUE(rv_)  TYPE string.

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
    rv_ = iv_.
    REPLACE ALL OCCURRENCES OF `\` IN rv_ WITH `\\`.
    REPLACE ALL OCCURRENCES OF `"` IN rv_ WITH `\"`.
    REPLACE ALL OCCURRENCES OF |\n| IN rv_ WITH `\n`.
    REPLACE ALL OCCURRENCES OF |\r| IN rv_ WITH `\r`.
    REPLACE ALL OCCURRENCES OF |\t| IN rv_ WITH `\t`.
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
            " \uXXXX (common codepoints; the rest kept verbatim)
            DATA lv_hex TYPE string.
            IF lv_j + 4 < lv_len.
              lv_hex = iv_+lv_j(5).
              lv_hex = lv_hex+1(4).
              CASE to_lower( lv_hex ).
                WHEN `003e`. rv_ = rv_ && `>`.
                WHEN `003c`. rv_ = rv_ && `<`.
                WHEN `0026`. rv_ = rv_ && `&`.
                WHEN `0027`. rv_ = rv_ && `'`.
                WHEN `0022`. rv_ = rv_ && `"`.
                WHEN OTHERS. rv_ = rv_ && `\u` && lv_hex.
              ENDCASE.
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

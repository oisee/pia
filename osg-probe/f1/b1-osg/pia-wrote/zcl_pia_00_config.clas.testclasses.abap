CLASS ltcl_config DEFINITION FINAL FOR TESTING
  DURATION SHORT RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    CONSTANTS c_test_file TYPE string VALUE `pia_test.env`.

    CLASS-METHODS write_env
      IMPORTING iv_content TYPE string.

    METHODS teardown.
    METHODS inline_comment_on_model FOR TESTING RAISING cx_static_check.
    METHODS inline_comment_on_turn_mode FOR TESTING RAISING cx_static_check.
    METHODS full_line_comment_ignored FOR TESTING RAISING cx_static_check.
    METHODS blanks_around_value_trimmed FOR TESTING RAISING cx_static_check.
    METHODS value_without_comment FOR TESTING RAISING cx_static_check.
    METHODS lowercase_key_matched FOR TESTING RAISING cx_static_check.
ENDCLASS.

CLASS ltcl_config IMPLEMENTATION.

  METHOD write_env.
    DATA lt_lines TYPE STANDARD TABLE OF string WITH DEFAULT KEY.

    SPLIT iv_content AT |\n| INTO TABLE lt_lines.
    OPEN DATASET c_test_file FOR OUTPUT IN TEXT MODE ENCODING UTF-8.
    LOOP AT lt_lines INTO DATA(lv_line).
      TRANSFER lv_line TO c_test_file.
    ENDLOOP.
    CLOSE DATASET c_test_file.
  ENDMETHOD.

  METHOD teardown.
    TRY.
        DELETE DATASET c_test_file.
      CATCH cx_root ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

  METHOD inline_comment_on_model.
    " README-style line: value followed by a comment
    write_env( `PIA_MODEL=glm-5.3 # optional` ).
    cl_abap_unit_assert=>assert_equals(
      exp = `glm-5.3`
      act = zcl_pia_00_config=>get_from(
              iv_file = c_test_file
              iv_name = `PIA_MODEL` ) ).
  ENDMETHOD.

  METHOD inline_comment_on_turn_mode.
    write_env( `PIA_TURN_MODE=job # optional: job | daemon | inline` ).
    cl_abap_unit_assert=>assert_equals(
      exp = `job`
      act = zcl_pia_00_config=>get_from(
              iv_file = c_test_file
              iv_name = `PIA_TURN_MODE` ) ).
  ENDMETHOD.

  METHOD full_line_comment_ignored.
    " a commented-out line must not win over the real one
    write_env( |# PIA_MODEL=glm-5.3-flash\nPIA_MODEL=glm-5.3 # optional| ).
    cl_abap_unit_assert=>assert_equals(
      exp = `glm-5.3`
      act = zcl_pia_00_config=>get_from(
              iv_file = c_test_file
              iv_name = `PIA_MODEL` ) ).
  ENDMETHOD.

  METHOD blanks_around_value_trimmed.
    write_env( `PIA_LLM = z.ai ` ).
    cl_abap_unit_assert=>assert_equals(
      exp = `z.ai`
      act = zcl_pia_00_config=>get_from(
              iv_file = c_test_file
              iv_name = `PIA_LLM` ) ).
  ENDMETHOD.

  METHOD value_without_comment.
    write_env( `PIA_LLM=z.ai` ).
    cl_abap_unit_assert=>assert_equals(
      exp = `z.ai`
      act = zcl_pia_00_config=>get_from(
              iv_file = c_test_file
              iv_name = `PIA_LLM` ) ).
  ENDMETHOD.

  METHOD lowercase_key_matched.
    write_env( `pia_model=glm-5.3 # optional` ).
    cl_abap_unit_assert=>assert_equals(
      exp = `glm-5.3`
      act = zcl_pia_00_config=>get_from(
              iv_file = c_test_file
              iv_name = `PIA_MODEL` ) ).
  ENDMETHOD.

ENDCLASS.
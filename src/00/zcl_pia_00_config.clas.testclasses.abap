CLASS ltcl_config DEFINITION FINAL FOR TESTING
  DURATION SHORT RISK LEVEL HARMLESS.

  PUBLIC SECTION.
    METHODS value_with_inline_comment FOR TESTING RAISING cx_static_check.
    METHODS value_plain FOR TESTING RAISING cx_static_check.
    METHODS line_without_equals FOR TESTING RAISING cx_static_check.

ENDCLASS.

CLASS zcl_pia_00_config DEFINITION LOCAL FRIENDS ltcl_config.

CLASS ltcl_config IMPLEMENTATION.

  METHOD value_with_inline_comment.
    " README style: value followed by a comment
    cl_abap_unit_assert=>assert_equals(
      exp = `glm-5.3`
      act = zcl_pia_00_config=>value_of_line( `PIA_MODEL=glm-5.3 # optional` )
      msg = `inline comment must be stripped from PIA_MODEL` ).

    cl_abap_unit_assert=>assert_equals(
      exp = `job`
      act = zcl_pia_00_config=>value_of_line( `PIA_TURN_MODE=job # optional: job | daemon | inline` )
      msg = `inline comment must be stripped from PIA_TURN_MODE` ).
  ENDMETHOD.

  METHOD value_plain.
    cl_abap_unit_assert=>assert_equals(
      exp = `glm-5.3`
      act = zcl_pia_00_config=>value_of_line( `PIA_MODEL=glm-5.3` ) ).
  ENDMETHOD.

  METHOD line_without_equals.
    cl_abap_unit_assert=>assert_equals(
      exp = ``
      act = zcl_pia_00_config=>value_of_line( `# just a comment` ) ).
  ENDMETHOD.

ENDCLASS.

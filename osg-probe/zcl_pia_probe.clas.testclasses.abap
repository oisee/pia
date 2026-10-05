CLASS ltcl_pia_probe DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    METHODS test_2_plus_2 FOR TESTING.
    METHODS test_fails_on_purpose FOR TESTING.
ENDCLASS.

CLASS ltcl_pia_probe IMPLEMENTATION.
  METHOD test_2_plus_2.
    cl_abap_unit_assert=>assert_equals( exp = 4 act = 2 + 2 ).
  ENDMETHOD.

  METHOD test_fails_on_purpose.
    cl_abap_unit_assert=>assert_equals( exp = 1 act = 2 msg = 'PIA probe: deliberate failure' ).
  ENDMETHOD.
ENDCLASS.

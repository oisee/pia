CLASS ltcl_slow DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION MEDIUM.
  PRIVATE SECTION.
    METHODS slow FOR TESTING.
ENDCLASS.

CLASS ltcl_slow IMPLEMENTATION.
  METHOD slow.
    " keeps STORE RUN_TESTS in flight long enough to activate something else meanwhile
    WAIT UP TO 8 SECONDS.
    cl_abap_unit_assert=>assert_equals( act = zcl_pia_race=>one( ) exp = 1 ).
  ENDMETHOD.
ENDCLASS.

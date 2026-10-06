CLASS ltcl_add DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    METHODS add_2_3 FOR TESTING.
ENDCLASS.

CLASS ltcl_add IMPLEMENTATION.
  METHOD add_2_3.
    cl_abap_unit_assert=>assert_equals( act = zcl_pia_demo=>add( a = 2 b = 3 ) exp = 5 msg = 'add' ).
  ENDMETHOD.
ENDCLASS.

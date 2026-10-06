CLASS zcl_pia_demo DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    CLASS-METHODS add
      IMPORTING a          TYPE i
                b          TYPE i
      RETURNING VALUE(rv_) TYPE i.
    CLASS-METHODS selfcheck RETURNING VALUE(rv_) TYPE string.
ENDCLASS.

CLASS zcl_pia_demo IMPLEMENTATION.
  METHOD add.
    rv_ = a - b.
  ENDMETHOD.
  METHOD selfcheck.
    IF zcl_pia_demo=>add( a = 2 b = 2 ) = 4.
      rv_ = 'PASS: add(2,2)=4'.
    ELSE.
      rv_ = |FAIL: add(2,2)={ zcl_pia_demo=>add( a = 2 b = 2 ) }, expected 4|.
    ENDIF.
  ENDMETHOD.
ENDCLASS.

CLASS zcl_pia_90_verify DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.

CLASS zcl_pia_90_verify IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.
    out->write( |ZCL_PIA_DEMO=>selfcheck( ): { zcl_pia_demo=>selfcheck( ) }| ).
  ENDMETHOD.
ENDCLASS.

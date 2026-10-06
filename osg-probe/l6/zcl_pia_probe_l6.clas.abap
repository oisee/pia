CLASS zcl_pia_probe_l6 DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.

CLASS zcl_pia_probe_l6 IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.
    out->write( `L6 marker: v0` ).
  ENDMETHOD.
ENDCLASS.

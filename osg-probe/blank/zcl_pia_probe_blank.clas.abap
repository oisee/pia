CLASS zcl_pia_probe_blank DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
    CLASS-METHODS run RETURNING VALUE(rt_out) TYPE string_table.
ENDCLASS.

CLASS zcl_pia_probe_blank IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.
    DATA lt_out TYPE string_table.
    DATA lv_line TYPE string.
    lt_out = run( ).
    LOOP AT lt_out INTO lv_line.
      out->write( lv_line ).
    ENDLOOP.
  ENDMETHOD.

  METHOD run.
    DATA lv_a TYPE string.
    DATA lv_n TYPE i VALUE 500.
    lv_a = 'activated: ' && 'X'.
    APPEND `[1] ` && lv_a && `]` TO rt_out.
    lv_a = 'a' && ' ' && 'b'.
    APPEND `[2] ` && lv_a && `]` TO rt_out.
    lv_a = 'HTTP ' && lv_n && ': ' && 'err'.
    APPEND `[3] ` && lv_a && `]` TO rt_out.
    lv_a = `activated: ` && 'X'.
    APPEND `[4] ` && lv_a && `]` TO rt_out.
  ENDMETHOD.
ENDCLASS.

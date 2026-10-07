CLASS zcl_pia_15_toolset DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    " the standard development tools on one backend (read, write, activate, run_tests)
    CLASS-METHODS register_dev_tools
      IMPORTING io_registry TYPE REF TO zcl_pia_00_registry
                io_backend  TYPE REF TO zif_pia_20_dev_backend.

ENDCLASS.

CLASS zcl_pia_15_toolset IMPLEMENTATION.

  METHOD register_dev_tools.
    DATA(lo_read) = NEW zcl_pia_10_t_read_object( ).
    lo_read->set_backend( io_backend ).
    io_registry->register( lo_read ).
    DATA(lo_write) = NEW zcl_pia_15_t_write_source( ).
    lo_write->set_backend( io_backend ).
    io_registry->register( lo_write ).
    DATA(lo_act) = NEW zcl_pia_15_t_activate( ).
    lo_act->set_backend( io_backend ).
    io_registry->register( lo_act ).
    " method level: the system's own method ranges (ADT objectstructure / STORE PARSE OUTLINE)
    DATA(lo_outline) = NEW zcl_pia_15_t_outline( ).
    lo_outline->set_backend( io_backend ).
    io_registry->register( lo_outline ).
    DATA(lo_rmeth) = NEW zcl_pia_15_t_read_method( ).
    lo_rmeth->set_backend( io_backend ).
    io_registry->register( lo_rmeth ).
    DATA(lo_wmeth) = NEW zcl_pia_15_t_write_method( ).
    lo_wmeth->set_backend( io_backend ).
    io_registry->register( lo_wmeth ).
    DATA(lo_test) = NEW zcl_pia_15_t_run_tests( ).
    lo_test->set_backend( io_backend ).
    io_registry->register( lo_test ).
  ENDMETHOD.

ENDCLASS.

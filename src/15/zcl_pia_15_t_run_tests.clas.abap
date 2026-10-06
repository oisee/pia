CLASS zcl_pia_15_t_run_tests DEFINITION PUBLIC INHERITING FROM zcl_pia_00_tool_base CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS zif_pia_00_tool~get_name        REDEFINITION.
    METHODS zif_pia_00_tool~get_params      REDEFINITION.
    METHODS zif_pia_00_tool~get_description REDEFINITION.
    METHODS zif_pia_00_tool~invoke          REDEFINITION.

    METHODS set_backend IMPORTING io_ TYPE REF TO zif_pia_20_dev_backend.

  PRIVATE SECTION.
    DATA mo_backend TYPE REF TO zif_pia_20_dev_backend.

ENDCLASS.

CLASS zcl_pia_15_t_run_tests IMPLEMENTATION.

  METHOD zif_pia_00_tool~get_name.
    rv_ = 'run_tests'.
  ENDMETHOD.

  METHOD zif_pia_00_tool~get_params.
    rt_ = VALUE #( ( name = 'name' type = 'string' desc = 'Class whose local ABAP Unit tests to run' required = abap_true ) ).
  ENDMETHOD.

  METHOD zif_pia_00_tool~get_description.
    rv_ = 'Run the local ABAP Unit tests of a class on the published (active) code. '
       && 'Returns pass/fail counts and, for failures, expected/actual and the line. '
       && 'If the last activation is not published yet, finish your turn and run tests in the next turn.'.
  ENDMETHOD.

  METHOD zif_pia_00_tool~invoke.
    DATA lt_cls TYPE string_table.
    DATA lv_out TYPE string.
    DATA(lv_name) = get_arg( iv_name = 'name' iv_arguments = iv_arguments ).
    IF lv_name IS INITIAL.
      rs_ = fail( 'name is required' ).
      RETURN.
    ENDIF.
    APPEND lv_name TO lt_cls.
    DATA(ls) = mo_backend->run_tests( lt_cls ).
    IF ls-source CS 'PUBLICATION_PENDING'.
      rs_ = fail( 'activation not published yet: finish this turn, run tests in the next turn' ).
      RETURN.
    ENDIF.
    " the raw result is compact JSON; the model reads it directly
    lv_out = ls-source.
    IF strlen( lv_out ) > 6000.
      lv_out = lv_out+0(6000) && `...[truncated]`.
    ENDIF.
    IF ls-ok = abap_true.
      rs_ = ok( |GREEN { ls-message }\n{ lv_out }| ).
    ELSE.
      " a red test is a valid tool result, not a tool failure
      rs_ = ok( |RED { ls-message }\n{ lv_out }| ).
    ENDIF.
  ENDMETHOD.

  METHOD set_backend.
    mo_backend = io_.
  ENDMETHOD.

ENDCLASS.

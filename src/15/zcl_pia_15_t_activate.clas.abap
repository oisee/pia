CLASS zcl_pia_15_t_activate DEFINITION PUBLIC INHERITING FROM zcl_pia_00_tool_base CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS zif_pia_00_tool~get_name        REDEFINITION.
    METHODS zif_pia_00_tool~get_params      REDEFINITION.
    METHODS zif_pia_00_tool~get_description REDEFINITION.
    METHODS zif_pia_00_tool~get_permission  REDEFINITION.
    METHODS zif_pia_00_tool~invoke          REDEFINITION.

    METHODS set_backend IMPORTING io_ TYPE REF TO zif_pia_20_dev_backend.

  PRIVATE SECTION.
    DATA mo_backend TYPE REF TO zif_pia_20_dev_backend.

ENDCLASS.

CLASS zcl_pia_15_t_activate IMPLEMENTATION.

  METHOD zif_pia_00_tool~get_name.
    rv_ = 'activate'.
  ENDMETHOD.

  METHOD zif_pia_00_tool~get_params.
    rt_ = VALUE #( ( name = 'name' type = 'string' desc = 'Class name' required = abap_true ) ).
  ENDMETHOD.

  METHOD zif_pia_00_tool~get_description.
    rv_ = 'Activate a written class. The new code becomes live in the NEXT step. After activate, finish your turn with a summary.'.
  ENDMETHOD.

  METHOD zif_pia_00_tool~get_permission.
    rv_ = zif_pia_00_tool=>c_perm_write.
  ENDMETHOD.

  METHOD zif_pia_00_tool~invoke.
    DATA(lv_name) = get_arg( iv_name = 'name' iv_arguments = iv_arguments ).
    IF lv_name IS INITIAL.
      rs_ = fail( 'name is required' ).
      RETURN.
    ENDIF.
    DATA(ls) = mo_backend->activate( lv_name ).
    IF ls-ok = abap_false.
      rs_ = fail( ls-message ).
      RETURN.
    ENDIF.
    rs_ = ok( ls-message ).
  ENDMETHOD.

  METHOD set_backend.
    mo_backend = io_.
  ENDMETHOD.

ENDCLASS.

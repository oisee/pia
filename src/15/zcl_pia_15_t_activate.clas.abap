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
    DATA lv_name TYPE string.
    lv_name = get_arg( iv_name = 'name' iv_arguments = iv_arguments ).
    IF lv_name IS INITIAL.
      rs_ = fail( 'name is required' ).
      RETURN.
    ENDIF.
    DATA(ls_act) = mo_backend->activate( lv_name ).
    IF ls_act-ok = abap_false.
      rs_ = fail( 'activation refused: ' && ls_act-issues ).
      RETURN.
    ENDIF.
    " Include op_id for checkpoint/resume tracking
    DATA lv_out TYPE string.
    lv_out = 'activated: ' && lv_name.
    IF ls_act-op_id IS NOT INITIAL.
      lv_out = lv_out && ' op_id=' && ls_act-op_id.
    ENDIF.
    IF ls_act-state = 'pending'.
      lv_out = lv_out && ' (publish pending — new code live in next step)'.
    ENDIF.
    rs_ = ok( lv_out ).
  ENDMETHOD.

  METHOD set_backend.
    mo_backend = io_.
  ENDMETHOD.

ENDCLASS.

CLASS zcl_pia_15_t_write_source DEFINITION PUBLIC INHERITING FROM zcl_pia_00_tool_base CREATE PUBLIC.

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

CLASS zcl_pia_15_t_write_source IMPLEMENTATION.

  METHOD zif_pia_00_tool~get_name.
    rv_ = 'write_source'.
  ENDMETHOD.

  METHOD zif_pia_00_tool~get_params.
    rt_ = VALUE #( ( name = 'name' type = 'string' desc = 'Class name' required = abap_true ) ( name = 'source' type = 'string' desc = 'Complete new class source' required = abap_true ) ).
  ENDMETHOD.

  METHOD zif_pia_00_tool~get_description.
    rv_ = 'Write the FULL new source of a class (main include). Provide the complete source, not a fragment.'.
  ENDMETHOD.

  METHOD zif_pia_00_tool~get_permission.
    rv_ = zif_pia_00_tool=>c_perm_write.
  ENDMETHOD.

  METHOD zif_pia_00_tool~invoke.
    DATA(lv_name)   = get_arg( iv_name = 'name'   iv_arguments = iv_arguments ).
    " source may contain escaped quotes etc: extract via balanced string with escape-aware regex
    DATA(lv_source) = get_arg( iv_name = 'source' iv_arguments = iv_arguments ).
    IF lv_name IS INITIAL OR lv_source IS INITIAL.
      rs_ = fail( 'name and source are required' ).
      RETURN.
    ENDIF.
    DATA(ls) = mo_backend->write_source( iv_name = lv_name iv_source = lv_source ).
    IF ls-ok = abap_false.
      rs_ = fail( ls-message ).
      RETURN.
    ENDIF.
    rs_ = ok( ls-message && '. NOTE: activation is a separate step (activate tool).' ).
  ENDMETHOD.

  METHOD set_backend.
    mo_backend = io_.
  ENDMETHOD.

ENDCLASS.

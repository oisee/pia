CLASS zcl_pia_10_t_read_object DEFINITION PUBLIC INHERITING FROM zcl_pia_00_tool_base CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS zif_pia_00_tool~get_name        REDEFINITION.
    METHODS zif_pia_00_tool~get_params      REDEFINITION.
    METHODS zif_pia_00_tool~get_description REDEFINITION.
    METHODS zif_pia_00_tool~invoke          REDEFINITION.

    METHODS set_backend IMPORTING io_ TYPE REF TO zif_pia_20_dev_backend.

  PRIVATE SECTION.
    DATA mo_backend TYPE REF TO zif_pia_20_dev_backend.

ENDCLASS.

CLASS zcl_pia_10_t_read_object IMPLEMENTATION.

  METHOD zif_pia_00_tool~get_name.
    rv_ = 'read_object'.
  ENDMETHOD.

  METHOD zif_pia_00_tool~get_params.
    rt_ = VALUE #( ( name = 'name' type = 'string' desc = 'Class name, e.g. ZCL_PIA_DEMO' required = abap_true )
                   ( name = 'include' type = 'string' desc = 'main (default) or testclasses (local ABAP Unit test classes)' required = abap_false ) ).
  ENDMETHOD.

  METHOD zif_pia_00_tool~get_description.
    rv_ = 'Read the full ABAP source of a class include: main (default, definition+implementation) or testclasses. For one method use outline and read_method.'.
  ENDMETHOD.

  METHOD zif_pia_00_tool~invoke.
    DATA(lv_name) = get_arg( iv_name = 'name' iv_arguments = iv_arguments ).
    IF lv_name IS INITIAL.
      rs_ = fail( 'name is required' ).
      RETURN.
    ENDIF.
    DATA(lv_include) = get_arg( iv_name = 'include' iv_arguments = iv_arguments ).
    IF lv_include = 'main'.
      CLEAR lv_include.
    ENDIF.
    DATA(ls) = mo_backend->read_object( iv_name = lv_name iv_include = lv_include ).
    IF ls-ok = abap_false.
      rs_ = fail( ls-message ).
      RETURN.
    ENDIF.
    rs_ = ok( ls-source ).
  ENDMETHOD.

  METHOD set_backend.
    mo_backend = io_.
  ENDMETHOD.

ENDCLASS.

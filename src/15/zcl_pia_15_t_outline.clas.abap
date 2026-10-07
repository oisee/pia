CLASS zcl_pia_15_t_outline DEFINITION PUBLIC INHERITING FROM zcl_pia_00_tool_base CREATE PUBLIC.

  " ranges come from the system (zif_pia_20_dev_backend~get_methods: ADT objectstructure on SAP, STORE PARSE
  " OUTLINE on open-steamgate); the tool only cuts or replaces those lines
  PUBLIC SECTION.
    METHODS zif_pia_00_tool~get_name        REDEFINITION.
    METHODS zif_pia_00_tool~get_params      REDEFINITION.
    METHODS zif_pia_00_tool~get_description REDEFINITION.
    METHODS zif_pia_00_tool~invoke          REDEFINITION.

    METHODS set_backend IMPORTING io_ TYPE REF TO zif_pia_20_dev_backend.

  PRIVATE SECTION.
    DATA mo_backend TYPE REF TO zif_pia_20_dev_backend.

ENDCLASS.

CLASS zcl_pia_15_t_outline IMPLEMENTATION.

  METHOD zif_pia_00_tool~get_name.
    rv_ = 'outline'.
  ENDMETHOD.

  METHOD zif_pia_00_tool~get_params.
    rt_ = VALUE #( ( name = 'name' type = 'string' desc = 'Class name' required = abap_true ) ).
  ENDMETHOD.

  METHOD zif_pia_00_tool~get_description.
    rv_ = 'List the methods of a class (and of its local test classes) with include and line ranges, as the system reports them.'.
  ENDMETHOD.

  METHOD zif_pia_00_tool~invoke.
    DATA(lv_name) = get_arg( iv_name = 'name' iv_arguments = iv_arguments ).
    IF lv_name IS INITIAL.
      rs_ = fail( 'name is required' ).
      RETURN.
    ENDIF.
    mo_backend->get_methods( EXPORTING iv_name = lv_name IMPORTING et_methods = DATA(lt_methods) ev_error = DATA(lv_error) ).
    IF lv_error IS NOT INITIAL.
      rs_ = fail( lv_error ).
      RETURN.
    ENDIF.
    DATA lt_out TYPE string_table.
    LOOP AT lt_methods INTO DATA(ls_m).
      APPEND |{ ls_m-owner }=>{ ls_m-method }: { ls_m-include } { ls_m-impl_from }-{ ls_m-impl_to }|
          && COND string( WHEN ls_m-def_from > 0 THEN | (declared { ls_m-def_from }-{ ls_m-def_to })| ) TO lt_out.
    ENDLOOP.
    rs_ = ok( |{ lines( lt_methods ) } methods\n| && concat_lines_of( table = lt_out sep = cl_abap_char_utilities=>newline ) ).
  ENDMETHOD.

  METHOD set_backend.
    mo_backend = io_.
  ENDMETHOD.

ENDCLASS.

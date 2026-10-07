CLASS zcl_pia_15_t_read_method DEFINITION PUBLIC INHERITING FROM zcl_pia_00_tool_base CREATE PUBLIC.

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

CLASS zcl_pia_15_t_read_method IMPLEMENTATION.

  METHOD zif_pia_00_tool~get_name.
    rv_ = 'read_method'.
  ENDMETHOD.

  METHOD zif_pia_00_tool~get_params.
    rt_ = VALUE #( ( name = 'name' type = 'string' desc = 'Class name' required = abap_true ) ( name = 'method' type = 'string' desc = 'Method name, e.g. EXTRACT_STR or ZIF_X~RUN' required = abap_true )
                   ( name = 'class' type = 'string' desc = 'Owner class (a local test class name) when the method name is not unique' required = abap_false ) ).
  ENDMETHOD.

  METHOD zif_pia_00_tool~get_description.
    rv_ = 'Read one METHOD ... ENDMETHOD block of a class or of its local test classes, with include and line range.'.
  ENDMETHOD.

  METHOD zif_pia_00_tool~invoke.
    DATA(lv_name) = get_arg( iv_name = 'name' iv_arguments = iv_arguments ).
    DATA(lv_method) = to_upper( get_arg( iv_name = 'method' iv_arguments = iv_arguments ) ).
    DATA(lv_owner) = to_upper( get_arg( iv_name = 'class' iv_arguments = iv_arguments ) ).
    IF lv_name IS INITIAL OR lv_method IS INITIAL.
      rs_ = fail( 'name and method are required' ).
      RETURN.
    ENDIF.
    mo_backend->get_methods( EXPORTING iv_name = lv_name IMPORTING et_methods = DATA(lt_methods) ev_error = DATA(lv_error) ).
    IF lv_error IS NOT INITIAL.
      rs_ = fail( lv_error ).
      RETURN.
    ENDIF.
    DATA lt_hit LIKE lt_methods.
    LOOP AT lt_methods INTO DATA(ls_m) WHERE method = lv_method.
      IF lv_owner IS INITIAL OR ls_m-owner = lv_owner.
        APPEND ls_m TO lt_hit.
      ENDIF.
    ENDLOOP.
    IF lines( lt_hit ) <> 1.
      rs_ = fail( COND #( WHEN lt_hit IS INITIAL THEN |method { lv_method } not found in { to_upper( lv_name ) } (see outline)|
                          ELSE |method { lv_method } is in several classes: pass class (see outline)| ) ).
      RETURN.
    ENDIF.
    DATA(ls_span) = lt_hit[ 1 ].
    IF ls_span-impl_from = 0.
      rs_ = fail( |method { lv_method } has no implementation in { to_upper( lv_name ) }| ).
      RETURN.
    ENDIF.
    DATA(ls_read) = mo_backend->read_object( iv_name = lv_name
                                            iv_include = COND #( WHEN ls_span-include = `main` THEN `` ELSE ls_span-include ) ).
    IF ls_read-ok = abap_false.
      rs_ = fail( ls_read-message ).
      RETURN.
    ENDIF.
    DATA lt_lines TYPE string_table.
    SPLIT replace( val = ls_read-source sub = cl_abap_char_utilities=>cr_lf with = cl_abap_char_utilities=>newline occ = 0 )
      AT cl_abap_char_utilities=>newline INTO TABLE lt_lines.
    IF ls_span-impl_to > lines( lt_lines ).
      rs_ = fail( |the reported range { ls_span-impl_from }-{ ls_span-impl_to } is outside { ls_span-include } ({ lines( lt_lines ) } lines)| ).
      RETURN.
    ENDIF.
    DATA lt_block TYPE string_table.
    LOOP AT lt_lines INTO DATA(lv_line) FROM ls_span-impl_from TO ls_span-impl_to.
      APPEND lv_line TO lt_block.
    ENDLOOP.
    rs_ = ok( |{ ls_span-owner }=>{ lv_method }, { ls_span-include } lines { ls_span-impl_from }-{ ls_span-impl_to }:\n|
           && concat_lines_of( table = lt_block sep = cl_abap_char_utilities=>newline ) ).
  ENDMETHOD.

  METHOD set_backend.
    mo_backend = io_.
  ENDMETHOD.

ENDCLASS.

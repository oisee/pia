CLASS zcl_pia_15_t_write_method DEFINITION PUBLIC INHERITING FROM zcl_pia_00_tool_base CREATE PUBLIC.

  " ranges come from the system (zif_pia_20_dev_backend~get_methods: ADT objectstructure on SAP, STORE PARSE
  " OUTLINE on open-steamgate); the tool only cuts or replaces those lines
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

CLASS zcl_pia_15_t_write_method IMPLEMENTATION.

  METHOD zif_pia_00_tool~get_name.
    rv_ = 'write_method'.
  ENDMETHOD.

  METHOD zif_pia_00_tool~get_params.
    rt_ = VALUE #( ( name = 'name' type = 'string' desc = 'Class name' required = abap_true ) ( name = 'method' type = 'string' desc = 'Method name, e.g. EXTRACT_STR or ZIF_X~RUN' required = abap_true )
                   ( name = 'source' type = 'string' desc = 'The complete new METHOD <name>. ... ENDMETHOD. block' required = abap_true )
                   ( name = 'class' type = 'string' desc = 'Owner class (a local test class name) when the method name is not unique' required = abap_false ) ).
  ENDMETHOD.

  METHOD zif_pia_00_tool~get_description.
    rv_ = 'Replace one existing METHOD ... ENDMETHOD block; the rest of the include stays as it is. A new method or a changed signature needs write_source. Activation is a separate step.'.
  ENDMETHOD.

  METHOD zif_pia_00_tool~get_permission.
    rv_ = zif_pia_00_tool=>c_perm_write.
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
    " guard: the reported range must start at this method (open-steamgate reports local test methods in main
    " until its objectstructure parity fix); otherwise refuse instead of overwriting other code
    " guard: the reported range must be exactly this method's block (the range can come from another version of the
    " source, e.g. open-steamgate's outline of the published version while the source has unactivated changes)
    IF to_upper( condense( lt_lines[ ls_span-impl_from ] ) ) NP |METHOD { lv_method }*|
       OR to_upper( condense( lt_lines[ ls_span-impl_to ] ) ) NP 'ENDMETHOD*'.
      rs_ = fail( |the system's range { ls_span-include } { ls_span-impl_from }-{ ls_span-impl_to } is not METHOD { lv_method } ... ENDMETHOD |
               && |in the current source (activate first, or use read_object and write_source)| ).
      RETURN.
    ENDIF.
    DATA(lv_block) = get_arg( iv_name = 'source' iv_arguments = iv_arguments ).
    IF lv_block IS INITIAL.
      rs_ = fail( 'source is required' ).
      RETURN.
    ENDIF.
    DATA lt_new TYPE string_table.
    SPLIT replace( val = lv_block sub = cl_abap_char_utilities=>cr_lf with = cl_abap_char_utilities=>newline occ = 0 )
      AT cl_abap_char_utilities=>newline INTO TABLE lt_new.
    " lines before the method, the new block, lines after it
    DATA lt_out TYPE string_table.
    LOOP AT lt_lines INTO DATA(lv_line).
      IF sy-tabix = ls_span-impl_from.
        APPEND LINES OF lt_new TO lt_out.
      ENDIF.
      IF sy-tabix < ls_span-impl_from OR sy-tabix > ls_span-impl_to.
        APPEND lv_line TO lt_out.
      ENDIF.
    ENDLOOP.
    lt_lines = lt_out.
    zcl_pia_15_self_guard=>remember( io_backend = mo_backend iv_name = lv_name
                                     iv_include = COND #( WHEN ls_span-include = `main` THEN `` ELSE ls_span-include ) ).
    DATA(ls_write) = mo_backend->write_source( iv_name = lv_name iv_include = COND #( WHEN ls_span-include = `main` THEN `` ELSE ls_span-include )
                                               iv_source = concat_lines_of( table = lt_lines sep = cl_abap_char_utilities=>newline )
                                                 && COND string( WHEN substring( val = ls_read-source off = strlen( ls_read-source ) - 1 len = 1 )
                                                                      = cl_abap_char_utilities=>newline
                                                                 THEN cl_abap_char_utilities=>newline ) ).
    IF ls_write-ok = abap_false.
      rs_ = fail( ls_write-message ).
      RETURN.
    ENDIF.
    rs_ = ok( |replaced { ls_span-owner }=>{ lv_method } ({ ls_span-include } lines { ls_span-impl_from }-{ ls_span-impl_to }, now { lines( lt_new ) } lines). |
           && 'NOTE: activation is a separate step (activate tool); the syntax check runs there.' ).
  ENDMETHOD.

  METHOD set_backend.
    mo_backend = io_.
  ENDMETHOD.

ENDCLASS.

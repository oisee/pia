CLASS zcl_pia_00_tool_base DEFINITION PUBLIC CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_pia_00_tool.
    METHODS constructor.

  PROTECTED SECTION.
    METHODS add_param
      IMPORTING iv_name     TYPE string
                iv_desc     TYPE string
                iv_type     TYPE string DEFAULT 'string'
                iv_required TYPE abap_bool DEFAULT abap_true.

    METHODS get_arg
      IMPORTING iv_name      TYPE string
                iv_arguments TYPE string
      RETURNING VALUE(rv_)   TYPE string.

    METHODS ok
      IMPORTING iv_output   TYPE string
      RETURNING VALUE(rs_)  TYPE zif_pia_00_tool=>ts_result.

    METHODS fail
      IMPORTING iv_msg      TYPE string
      RETURNING VALUE(rs_)  TYPE zif_pia_00_tool=>ts_result.

  PRIVATE SECTION.
    DATA mt_params TYPE zif_pia_00_tool=>tt_params.

ENDCLASS.

CLASS zcl_pia_00_tool_base IMPLEMENTATION.

  METHOD constructor.
    " force own instance state (transpiler inheritance quirk workaround)
    DATA lt_own TYPE zif_pia_00_tool=>tt_params.
    mt_params = lt_own.
  ENDMETHOD.

  METHOD add_param.
    APPEND VALUE #( name = iv_name type = iv_type desc = iv_desc
                    required = iv_required ) TO mt_params.
  ENDMETHOD.

  METHOD get_arg.
    rv_ = zcl_pia_00_json_util=>unescape(
            zcl_pia_00_json_util=>extract_str( iv_json = iv_arguments iv_name = iv_name ) ).
  ENDMETHOD.

  METHOD ok.
    rs_-ok = abap_true.
    rs_-output = iv_output.
  ENDMETHOD.

  METHOD fail.
    rs_-ok = abap_false.
    rs_-output = 'ERROR: ' && iv_msg.
  ENDMETHOD.

  METHOD zif_pia_00_tool~get_params.
    rt_ = mt_params.
  ENDMETHOD.

  METHOD zif_pia_00_tool~get_permission.
    rv_ = zif_pia_00_tool=>c_perm_read.
  ENDMETHOD.

  METHOD zif_pia_00_tool~get_name.
  ENDMETHOD.

  METHOD zif_pia_00_tool~get_description.
  ENDMETHOD.

  METHOD zif_pia_00_tool~invoke.
    rs_ = fail( 'not implemented' ).
  ENDMETHOD.

ENDCLASS.

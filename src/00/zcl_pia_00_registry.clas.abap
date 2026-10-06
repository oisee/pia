CLASS zcl_pia_00_registry DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    CLASS-METHODS new RETURNING VALUE(ro_) TYPE REF TO zcl_pia_00_registry.

    METHODS register IMPORTING io_ TYPE REF TO zif_pia_00_tool.

    METHODS get_tools_json_openai RETURNING VALUE(rv_) TYPE string.

    METHODS invoke_call
      IMPORTING is_call     TYPE zif_pia_00_tool=>ts_call
      RETURNING VALUE(rs_)  TYPE zif_pia_00_tool=>ts_result.

    METHODS count RETURNING VALUE(rv_) TYPE i.

  PRIVATE SECTION.
    DATA mt TYPE STANDARD TABLE OF REF TO zif_pia_00_tool WITH EMPTY KEY.

ENDCLASS.

CLASS zcl_pia_00_registry IMPLEMENTATION.

  METHOD new.
    ro_ = NEW #( ).
  ENDMETHOD.

  METHOD register.
    IF io_ IS BOUND.
      APPEND io_ TO mt.
    ENDIF.
  ENDMETHOD.

  METHOD get_tools_json_openai.
    DATA lt TYPE string_table.
    DATA lt_p TYPE string_table.
    DATA lt_r TYPE string_table.
    LOOP AT mt INTO DATA(lo).
      CLEAR: lt_p, lt_r.
      LOOP AT lo->get_params( ) INTO DATA(ls_p).
        APPEND '"' && ls_p-name && '":{"type":"' && ls_p-type &&
               '","description":"' && zcl_pia_00_json_util=>escape( ls_p-desc ) && '"}'
               TO lt_p.
        IF ls_p-required = abap_true.
          APPEND '"' && ls_p-name && '"' TO lt_r.
        ENDIF.
      ENDLOOP.
      DATA(lv_props) = concat_lines_of( table = lt_p sep = ',' ).
      DATA(lv_req)   = concat_lines_of( table = lt_r sep = ',' ).
      APPEND '{"type":"function","function":{"name":"' && lo->get_name( ) &&
             '","description":"' && zcl_pia_00_json_util=>escape( lo->get_description( ) ) &&
             '","parameters":{"type":"object","properties":{' && lv_props &&
             '},"required":[' && lv_req && ']}}}'
             TO lt.
    ENDLOOP.
    rv_ = '[' && concat_lines_of( table = lt sep = ',' ) && ']'.
  ENDMETHOD.

  METHOD invoke_call.
    LOOP AT mt INTO DATA(lo).
      IF to_upper( lo->get_name( ) ) = to_upper( is_call-name ).
        rs_ = lo->invoke( iv_arguments = is_call-arguments iv_call_id = is_call-id ).
        RETURN.
      ENDIF.
    ENDLOOP.
    rs_-ok = abap_false.
    rs_-output = |ERROR: tool not found: { is_call-name }|.
    rs_-call_id = is_call-id.
  ENDMETHOD.

  METHOD count.
    rv_ = lines( mt ).
  ENDMETHOD.

ENDCLASS.

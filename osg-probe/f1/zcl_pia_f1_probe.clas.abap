CLASS zcl_pia_f1_probe DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.

CLASS zcl_pia_f1_probe IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.
    " the steps of zcl_pia_00_llm_http->parse_calls_responses on a Responses body whose
    " function_call arguments carry ABAP source with a lone bracket / brace in a literal
    DATA lt_src TYPE string_table.
    APPEND `lv_open = '{'.` TO lt_src.
    APPEND `FIND PCRE '[\[<]' IN lv_x.` TO lt_src.
    LOOP AT lt_src INTO DATA(lv_src).
      DATA(lv_args) = `{"name":"ZCL_X","source":"` && zcl_pia_00_json_util=>escape( lv_src ) && `"}`.
      " as z.ai sends it: two calls, fields after the arguments
      DATA(lv_body) = `{"output":[{"type":"function_call","name":"write_source","arguments":"`
        && zcl_pia_00_json_util=>escape( lv_args ) && `","call_id":"c1","status":"completed"},`
        && `{"type":"function_call","name":"activate","arguments":"{\"name\":\"ZCL_X\"}","call_id":"c2","status":"completed"}],"status":"completed"}`.
      DATA(lv_arr) = zcl_pia_00_json_util=>extract_balanced( iv_json = lv_body iv_key = 'output' iv_open = '[' iv_close = ']' ).
      DATA(lt_e) = zcl_pia_00_json_util=>split_entries( lv_arr ).
      DATA lv_got TYPE string.
      CLEAR lv_got.
      out->write( |calls found: { lines( lt_e ) } (sent 2)| ).
      LOOP AT lt_e INTO DATA(lv_e).
        CHECK lv_got IS INITIAL.
        lv_got = zcl_pia_00_json_util=>unescape( zcl_pia_00_json_util=>extract_balanced(
                   iv_json = lv_e iv_key = 'arguments' iv_open = '{' iv_close = '}' ) ).
      ENDLOOP.
      out->write( |sent:     { lv_args }| ).
      out->write( |received: { lv_got }| ).
      out->write( COND string( WHEN lv_got = lv_args THEN `SAME` ELSE `DIFFERENT` ) ).
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.

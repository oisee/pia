CLASS zcl_pia_rec_probe DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.

CLASS zcl_pia_rec_probe IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.
    " the recorded z.ai answers of F1 attempt 3, parsed as PIA parses them now
    DATA lt_out TYPE string_table.
    LOOP AT zcl_pia_00_session_store=>read_lines( `pia-f1-a3.rec` ) INTO DATA(lv_line).
      DATA(lv_body) = zcl_pia_00_json_util=>unescape( lv_line ).
      DATA(lt_calls) = zcl_pia_00_llm_http=>parse_calls_responses( lv_body ).
      APPEND |{ sy-tabix }: { lines( lt_calls ) } calls| TO lt_out.
    ENDLOOP.
    out->write( concat_lines_of( table = lt_out sep = ` | ` ) ).
  ENDMETHOD.
ENDCLASS.

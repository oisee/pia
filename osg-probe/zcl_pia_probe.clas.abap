CLASS zcl_pia_probe DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
  PRIVATE SECTION.
    METHODS https_probe RETURNING VALUE(rv_out) TYPE string.
    METHODS llm_probe    RETURNING VALUE(rv_out) TYPE string.
ENDCLASS.

CLASS zcl_pia_probe IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.
    out->write( `PIA probe: start` ).
    TRY.
        out->write( https_probe( ) ).
      CATCH cx_root INTO DATA(lx).
        out->write( |PIA probe: EX https { lx->get_text( ) }| ).
    ENDTRY.
    TRY.
        out->write( llm_probe( ) ).
      CATCH cx_root INTO DATA(lx2).
        out->write( |PIA probe: EX llm { lx2->get_text( ) }| ).
    ENDTRY.
    out->write( `PIA probe: done` ).
  ENDMETHOD.

  METHOD https_probe.
    DATA li TYPE REF TO if_http_client.
    cl_http_client=>create_by_url(
      EXPORTING url = 'https://api.anthropic.com/v1/messages'
      IMPORTING client = li ).
    li->request->set_method( 'POST' ).
    li->request->set_header_field( name = 'content-type' value = 'application/json' ).
    li->request->set_header_field( name = 'x-api-key' value = 'pia-probe-no-key' ).
    li->request->set_header_field( name = 'anthropic-version' value = '2023-06-01' ).
    li->request->set_cdata(
      '{"model":"claude-3-5-haiku-latest","max_tokens":1,"messages":[{"role":"user","content":"ping"}]}' ).
    li->send( ).
    li->receive( ).
    DATA lv_code TYPE i.
    li->response->get_status( IMPORTING code = lv_code ).
    rv_out = |PIA probe: HTTPS status { lv_code } (expected 401 without key)|.
  ENDMETHOD.

  METHOD llm_probe.
    DATA li TYPE REF TO if_http_client.
    cl_http_client=>create_by_url(
      EXPORTING url = 'http://192.168.8.107:11434/v1/chat/completions'
      IMPORTING client = li ).
    li->request->set_method( 'POST' ).
    li->request->set_header_field( name = 'content-type' value = 'application/json' ).
    li->request->set_cdata(
      '{"model":"qwen-coder-abap-v7:latest","max_tokens":120,' &&
      ' "messages":[{"role":"user","content":"Write a one-line ABAP statement that concatenates a and b into c."}]}' ).
    li->send( ).
    li->receive( ).
    DATA lv_code TYPE i.
    li->response->get_status( IMPORTING code = lv_code ).
    DATA(lv_body) = li->response->get_cdata( ).
    DATA lv_content TYPE string.
    FIND FIRST OCCURRENCE OF REGEX '"content"\s*:\s*"([^"]*)"' IN lv_body SUBMATCHES lv_content.
    rv_out = |PIA probe: LLM status { lv_code }, model says: { lv_content }|.
  ENDMETHOD.
ENDCLASS.

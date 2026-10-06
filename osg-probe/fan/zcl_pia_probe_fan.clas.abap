CLASS zcl_pia_probe_fan DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
    " A: n x (send+receive) sequentially; B: n x send, then n x receive (fan-out)
    CLASS-METHODS run
      IMPORTING iv_url        TYPE string
                iv_n          TYPE i
      RETURNING VALUE(rt_out) TYPE string_table.
  PRIVATE SECTION.
    CLASS-METHODS new_client
      IMPORTING iv_url     TYPE string
      RETURNING VALUE(ri)  TYPE REF TO if_http_client.
ENDCLASS.

CLASS zcl_pia_probe_fan IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.
    DATA lt_out TYPE string_table.
    DATA lv_line TYPE string.
    lt_out = run( iv_url = `http://httpbin.org/delay/2` iv_n = 3 ).
    LOOP AT lt_out INTO lv_line.
      out->write( lv_line ).
    ENDLOOP.
  ENDMETHOD.

  METHOD new_client.
    cl_http_client=>create_by_url(
      EXPORTING url = iv_url
      IMPORTING client = ri ).
    ri->request->set_method( 'GET' ).
  ENDMETHOD.

  METHOD run.
    DATA lt_cli TYPE STANDARD TABLE OF REF TO if_http_client WITH EMPTY KEY.
    DATA li TYPE REF TO if_http_client.
    DATA lv_t0 TYPE i.
    DATA lv_t1 TYPE i.
    DATA lv_ta TYPE i.
    DATA lv_tb TYPE i.
    DATA lv_ms TYPE i.
    DATA lv_i TYPE i.
    DATA lv_rc TYPE i.
    DATA lv_code TYPE i.

    " A: sequential
    GET RUN TIME FIELD lv_t0.
    DO iv_n TIMES.
      li = new_client( iv_url ).
      li->send( EXCEPTIONS OTHERS = 1 ).
      li->receive( EXCEPTIONS OTHERS = 1 ).
      lv_rc = sy-subrc.
      li->response->get_status( IMPORTING code = lv_code ).
      li->close( ).
    ENDDO.
    GET RUN TIME FIELD lv_t1.
    lv_ms = ( lv_t1 - lv_t0 ) / 1000.
    APPEND |A sequential n={ iv_n }: { lv_ms } ms (last rc { lv_rc } status { lv_code })| TO rt_out.

    " B: fan-out
    GET RUN TIME FIELD lv_t0.
    DO iv_n TIMES.
      li = new_client( iv_url ).
      li->send( EXCEPTIONS OTHERS = 1 ).
      APPEND li TO lt_cli.
    ENDDO.
    GET RUN TIME FIELD lv_t1.
    lv_ms = ( lv_t1 - lv_t0 ) / 1000.
    APPEND |B send phase n={ iv_n }: { lv_ms } ms| TO rt_out.

    LOOP AT lt_cli INTO li.
      lv_i = sy-tabix.
      GET RUN TIME FIELD lv_ta.
      li->receive( EXCEPTIONS OTHERS = 1 ).
      lv_rc = sy-subrc.
      GET RUN TIME FIELD lv_tb.
      li->response->get_status( IMPORTING code = lv_code ).
      li->close( ).
      lv_ms = ( lv_tb - lv_ta ) / 1000.
      APPEND |B receive #{ lv_i }: { lv_ms } ms (rc { lv_rc } status { lv_code })| TO rt_out.
    ENDLOOP.
    GET RUN TIME FIELD lv_t1.
    lv_ms = ( lv_t1 - lv_t0 ) / 1000.
    APPEND |B fan-out total: { lv_ms } ms| TO rt_out.
  ENDMETHOD.
ENDCLASS.

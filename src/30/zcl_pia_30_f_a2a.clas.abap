CLASS zcl_pia_30_f_a2a DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_http_extension.
  PRIVATE SECTION.
    CLASS-DATA go_session  TYPE REF TO zcl_pia_00_session.
    CLASS-DATA go_registry TYPE REF TO zcl_pia_00_registry.
    CLASS-DATA go_llm      TYPE REF TO zif_pia_00_llm.

    CLASS-METHODS boot.
    CLASS-METHODS agent_card RETURNING VALUE(rv_) TYPE string.
    CLASS-METHODS handle_send IMPORTING iv_body TYPE string
                     RETURNING VALUE(rv_) TYPE string.
    METHODS respond IMPORTING io_server TYPE REF TO if_http_server
                              iv_json TYPE string
                              iv_status TYPE i DEFAULT 200.
ENDCLASS.

CLASS zcl_pia_30_f_a2a IMPLEMENTATION.

  METHOD boot.
    IF go_session IS BOUND. RETURN. ENDIF.
    DATA(lo_backend) = zcl_pia_20_b_osg_store=>new( ).
    go_registry = zcl_pia_00_registry=>new( ).
    DATA(lo_read) = NEW zcl_pia_10_t_read_object( ).
    lo_read->set_backend( lo_backend ).
    go_registry->register( lo_read ).
    DATA(lo_write) = NEW zcl_pia_15_t_write_source( ).
    lo_write->set_backend( lo_backend ).
    go_registry->register( lo_write ).
    DATA(lo_act) = NEW zcl_pia_15_t_activate( ).
    lo_act->set_backend( lo_backend ).
    go_registry->register( lo_act ).
    go_llm = zcl_pia_00_llm_http=>new( VALUE #(
      base_url = 'https://api.z.ai/api/v1/responses'
      model    = 'glm-5.3-flash'
      api_key  = 'PIA_ZAI_KEY'
      api_type = 'responses' ) ).
    go_session = zcl_pia_00_session=>new( 'a2a' ).
  ENDMETHOD.

  METHOD if_http_extension~handle_request.
    boot( ).
    DATA(lv_method) = server->request->get_method( ).
    DATA(lv_path) = server->request->get_header_field( '~path_info' ).
    SHIFT lv_path LEFT DELETING LEADING '/'.

    IF lv_path CS 'agent.json' AND lv_method = 'GET'.
      respond( io_server = server iv_json = agent_card( ) ).
      RETURN.
    ENDIF.

    IF lv_method = 'POST'.
      DATA(lv_body) = server->request->get_cdata( ).
      respond( io_server = server iv_json = handle_send( lv_body ) ).
      RETURN.
    ENDIF.

    respond( io_server = server iv_json = '{"error":"not found"}' iv_status = 404 ).
  ENDMETHOD.

  METHOD agent_card.
    DATA lv TYPE string_table.
    APPEND '{"name":"PIA",' TO lv.
    APPEND '"description":"ABAP-native coding agent running inside an ABAP runtime (OSG/SAP). Can read, write and activate ABAP classes.",' TO lv.
    APPEND '"url":"%BASE_URL%",' TO lv.
    APPEND '"version":"0.1.0",' TO lv.
    APPEND '"capabilities":{"streaming":false},' TO lv.
    APPEND '"defaultInputModes":["text/plain"],"defaultOutputModes":["text/plain"],' TO lv.
    APPEND '"skills":[{"id":"abap_coding","name":"ABAP Coding","description":"Read, modify, activate ABAP code inside the system"}]}' TO lv.
    rv_ = concat_lines_of( table = lv ).
  ENDMETHOD.

  METHOD handle_send.
    " A2A message: {"message":{"role":"user","parts":[{"type":"text","content":"task"}]}}
    " Or simple: {"text":"task"}
    DATA(lv_task) = zcl_pia_00_json_util=>extract_str( iv_json = iv_body iv_name = 'content' ).
    IF lv_task IS INITIAL.
      lv_task = zcl_pia_00_json_util=>extract_str( iv_json = iv_body iv_name = 'text' ).
    ENDIF.
    lv_task = zcl_pia_00_json_util=>unescape( lv_task ).

    IF lv_task IS INITIAL.
      rv_ = '{"error":"no task text found"}'.
      RETURN.
    ENDIF.

    " Resume from checkpoint if provided
    DATA(lv_checkpoint) = zcl_pia_00_json_util=>extract_str(
      iv_json = iv_body iv_name = 'checkpoint' ).
    IF lv_checkpoint IS NOT INITIAL.
      " checkpoint is base64-encoded to avoid JSON escaping issues
      go_session->from_json(
        cl_http_utility=>decode_base64( lv_checkpoint ) ).
    ENDIF.

    DATA(lo_exec) = zcl_pia_00_executor=>new(
      io_llm      = go_llm
      io_registry = go_registry
      io_session  = go_session ).

    DATA(ls_result) = lo_exec->run(
      iv_task = lv_task
      iv_system = 'You are PIA, an ABAP coding agent. Tools: read_object, write_source, activate. '
               && 'Read before write. Write FULL source. Activate after write. Answer briefly.'
      iv_max_iterations = 8
      iv_continue = abap_true ).

    " A2A response: JSON with answer + tool trace
    DATA lt TYPE string_table.
    APPEND '{"id":"' && |a2a_{ sy-uzeit }| && '",' TO lt.
    APPEND '"status":{"state":"completed"},' TO lt.
    APPEND '"answer":"' && zcl_pia_00_json_util=>escape( ls_result-answer ) && '",' TO lt.
    APPEND '"tool_calls":' && |{ ls_result-tool_calls }| && ',' TO lt.
    APPEND '"iterations":' && |{ ls_result-iterations }| && ',' TO lt.

    " tool trace
    APPEND '"trace":[' TO lt.
    DATA lt_t TYPE string_table.
    LOOP AT go_session->get_trace( ) INTO DATA(ls_t).
      DATA(lv_ok) = 'false'.
      IF ls_t-ok = abap_true.
        lv_ok = 'true'.
      ENDIF.
      APPEND '{"tool":"' && ls_t-tool && '","ok":' && lv_ok && '}' TO lt_t.
    ENDLOOP.
    APPEND concat_lines_of( table = lt_t sep = ',' ) TO lt.
    APPEND '],' TO lt.

    " checkpoint for resume
    APPEND '"checkpoint":"' &&
           cl_http_utility=>encode_base64( go_session->to_json( ) ) &&
           '"}' TO lt.

    rv_ = concat_lines_of( table = lt ).
  ENDMETHOD.

  METHOD respond.
    io_server->response->set_header_field( name = 'Content-Type'
        value = 'application/json; charset=utf-8' ).
    io_server->response->set_cdata( iv_json ).
  ENDMETHOD.

ENDCLASS.

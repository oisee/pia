CLASS zcl_pia_30_f_chat DEFINITION PUBLIC CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_http_extension.
    CLASS-METHODS boot.
  PRIVATE SECTION.
    CLASS-DATA mo_session  TYPE REF TO zcl_pia_00_session.
    CLASS-DATA mo_registry TYPE REF TO zcl_pia_00_registry.
    CLASS-DATA mo_llm      TYPE REF TO zif_pia_00_llm.
    CLASS-METHODS render
      IMPORTING io_server TYPE REF TO if_http_server
      EXPORTING ev_html   TYPE string.
ENDCLASS.

CLASS zcl_pia_30_f_chat IMPLEMENTATION.

  METHOD boot.
    IF mo_session IS BOUND. RETURN. ENDIF.
    DATA(lo_backend) = zcl_pia_20_b_osg_store=>new( ).
    mo_registry = zcl_pia_00_registry=>new( ).
    DATA(lo_read) = NEW zcl_pia_10_t_read_object( ).
    lo_read->set_backend( lo_backend ).
    mo_registry->register( lo_read ).
    DATA(lo_write) = NEW zcl_pia_15_t_write_source( ).
    lo_write->set_backend( lo_backend ).
    mo_registry->register( lo_write ).
    DATA(lo_act) = NEW zcl_pia_15_t_activate( ).
    lo_act->set_backend( lo_backend ).
    mo_registry->register( lo_act ).
    mo_llm = zcl_pia_00_llm_http=>new( VALUE #(
      base_url = 'https://api.z.ai/api/v1/responses'
      model    = 'glm-5.3-flash'
      api_key  = 'PIA_ZAI_KEY'
      api_type = 'responses' ) ).
    mo_session = zcl_pia_00_session=>new( 'chat' ).
  ENDMETHOD.

  METHOD if_http_extension~handle_request.
    boot( ).
    DATA(lv_method) = server->request->get_method( ).
    DATA(lv_msg) = server->request->get_form_field( 'msg' ).
    IF lv_method = 'POST' AND lv_msg IS INITIAL.
      DATA(lv_body) = server->request->get_cdata( ).
      FIND FIRST OCCURRENCE OF 'msg=' IN lv_body MATCH OFFSET DATA(lv_off).
      IF sy-subrc = 0.
        lv_msg = lv_body+lv_off.
        REPLACE FIRST OCCURRENCE OF 'msg=' IN lv_msg WITH ``.
        REPLACE ALL OCCURRENCES OF '+' IN lv_msg WITH ` `.
        lv_msg = cl_http_utility=>unescape_url( lv_msg ).
      ENDIF.
    ENDIF.
    IF lv_method = 'POST' AND lv_msg IS NOT INITIAL.
      DATA(lo_exec) = zcl_pia_00_executor=>new(
        io_llm = mo_llm io_registry = mo_registry io_session = mo_session ).
      lo_exec->run(
        iv_task = lv_msg
        iv_system = 'You are PIA, an ABAP coding agent running inside an ABAP runtime. '
                 && 'Tools: read_object(name), write_source(name, source - FULL source), activate(name). '
                 && 'Rules: read before write; always activate after write; new code goes live NEXT step. '
                 && 'Answer briefly. ALWAYS answer in the language of the user message. If asked to just talk - talk.'
        iv_max_iterations = 8
        iv_continue = abap_true ).
    ENDIF.
    render( EXPORTING io_server = server IMPORTING ev_html = DATA(lv_html) ).
    server->response->set_header_field( name = 'content-type' value = 'text/html; charset=utf-8' ).
    server->response->set_cdata( lv_html ).
  ENDMETHOD.

  METHOD render.
    DATA lv TYPE string_table.
    APPEND '<!DOCTYPE html><html><head><meta charset="utf-8"><title>PIA chat</title>' TO lv.
    APPEND '<style>body{background:#0d1117;color:#e6edf3;font-family:Menlo,Consolas,monospace;max-width:860px;margin:24px auto;padding:0 12px}' TO lv.
    APPEND 'h1{color:#58a6ff;font-size:20px}.msg{border:1px solid #30363d;border-radius:8px;padding:10px 14px;margin:10px 0;white-space:pre-wrap}' TO lv.
    APPEND '.u{border-color:#1f6feb}.a{border-color:#238636}.t{border-color:#30363d;color:#8b949e;font-size:12px}' TO lv.
    APPEND 'form{display:flex;gap:8px;margin-top:16px}textarea{flex:1;min-height:52px;resize:vertical;font-family:inherit;font-size:14px;background:#161b22;color:#e6edf3;border:1px solid #30363d;border-radius:6px;padding:10px}' TO lv.
    APPEND 'button{background:#238636;color:#fff;border:0;border-radius:6px;padding:10px 18px;cursor:pointer}.it{color:#8b949e;font-size:11px}</style></head><body>' TO lv.
    APPEND '<h1>&#128053; PIA &mdash; pi, writing itself in ABAP</h1>' TO lv.
    LOOP AT mo_session->get_messages( ) INTO DATA(ls).
      IF ls-role = 'system'. CONTINUE. ENDIF.
      DATA(lv_cls) = 't'.
      IF ls-role = 'user'. lv_cls = 'u'. ELSEIF ls-role = 'assistant'. lv_cls = 'a'. ENDIF.
      DATA(lv_txt) = ls-content.
      REPLACE ALL OCCURRENCES OF '<' IN lv_txt WITH '&lt;'.
      REPLACE ALL OCCURRENCES OF '>' IN lv_txt WITH '&gt;'.
      IF ls-role = 'assistant' AND ls-content CP '{"tool_calls"*'.
        lv_cls = 't'.
      ENDIF.
      APPEND |<div class="msg { lv_cls }">{ lv_txt }</div>| TO lv.
    ENDLOOP.
    LOOP AT mo_session->get_trace( ) INTO DATA(ls_t).
      DATA(lv_o) = ls_t-output.
      REPLACE ALL OCCURRENCES OF '<' IN lv_o WITH '&lt;'.
      IF strlen( lv_o ) > 200. lv_o = lv_o+0(200) && '...'. ENDIF.
      APPEND |<div class="msg t">&#9654; { ls_t-tool } { ls_t-args } &rarr; ok={ ls_t-ok }: { lv_o }</div>| TO lv.
    ENDLOOP.
    LOOP AT mo_session->get_events( ) INTO DATA(lv_ev).
      IF lv_ev CS 'llm_error'.
        APPEND '<div class="msg t">' && lv_ev && '</div>' TO lv.
      ENDIF.
    ENDLOOP.
    APPEND `<form method="post" onsubmit="document.getElementById('think').style.display='block';this.style.display='none'"><textarea name="msg" id="msg" rows="2" placeholder="task or question... (Enter=send, Shift+Enter=newline)" autofocus></textarea><button id="sb" type="submit">Send</button></form>` TO lv.
    APPEND `<script>const ta=document.getElementById('msg');ta.addEventListener('keydown',e=>{if((e.key==='Enter')&&!e.shiftKey){e.preventDefault();ta.form.submit();}});</script>` TO lv.
    APPEND |<p class="it">iters={ mo_session->mv_iterations } tools={ mo_session->mv_tool_calls } &middot; glm-5.3-flash &middot; OSG :8020</p>| TO lv.
    APPEND '</body></html>' TO lv.
    ev_html = concat_lines_of( table = lv ).
  ENDMETHOD.

ENDCLASS.

CLASS zcl_pia_30_f_tui_handler DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_http_extension.
ENDCLASS.

CLASS zcl_pia_30_f_tui_handler IMPLEMENTATION.

  METHOD if_http_extension~handle_request.
    DATA lv TYPE string_table.
    APPEND '<!DOCTYPE html><html><head>' TO lv.
    APPEND '<meta charset="UTF-8"><title>PIA Terminal</title>' TO lv.
    APPEND '<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/xterm@5.3.0/css/xterm.css"/>' TO lv.
    APPEND '<style>body{margin:0;padding:20px;background:#0d1117;min-height:100vh;font-family:monospace}' TO lv.
    APPEND '#terminal{height:calc(100vh - 100px);border:1px solid #30363d;border-radius:6px}' TO lv.
    APPEND '.bar{margin-top:8px;display:flex;gap:8px}' TO lv.
    APPEND '.bar input{flex:1;background:#161b22;color:#e6edf3;border:1px solid #30363d;border-radius:4px;padding:8px;font-family:monospace}' TO lv.
    APPEND '.bar button{background:#238636;color:#fff;border:0;border-radius:4px;padding:8px 16px;cursor:pointer}' TO lv.
    APPEND '</style></head><body>' TO lv.
    APPEND '<div id="terminal"></div>' TO lv.
    APPEND '<div class="bar"><input id="alt" placeholder="type here..."><button id="send">Send</button></div>' TO lv.
    APPEND '<script src="https://cdn.jsdelivr.net/npm/xterm@5.3.0/lib/xterm.js"></script>' TO lv.
    APPEND '<script src="https://cdn.jsdelivr.net/npm/xterm-addon-fit@0.8.0/lib/xterm-addon-fit.js"></script>' TO lv.
    APPEND '<script>' TO lv.
    APPEND 'const APC="/sap/bc/apc/sap/zpia_tui";let ws;' TO lv.
    APPEND 'const fit=new FitAddon.FitAddon();' TO lv.
    APPEND 'const term=new Terminal({cursorBlink:true,fontSize:14,theme:{background:"#0d1117",foreground:"#c9d1d9",cursor:"#58a6ff"}});' TO lv.
    APPEND 'term.loadAddon(fit);term.open(document.getElementById("terminal"));fit.fit();' TO lv.
    APPEND 'window.addEventListener("resize",()=>fit.fit());' TO lv.
    APPEND 'function connect(){' TO lv.
    APPEND 'const url=(location.protocol==="https:"?"wss:":"ws:")+"//"+location.host+APC;' TO lv.
    APPEND 'term.writeln("Connecting...");' TO lv.
    APPEND 'ws=new WebSocket(url);' TO lv.
    APPEND 'ws.onopen=()=>{term.writeln("Connected\\r\\n")};' TO lv.
    APPEND 'ws.onmessage=(e)=>term.write(e.data.replace(/\\n/g,"\\r\\n"));' TO lv.
    APPEND 'ws.onclose=()=>{term.writeln("\\r\\nDisconnected");ws=null;setTimeout(connect,3000)};' TO lv.
    APPEND '}' TO lv.
    APPEND 'connect();' TO lv.
    APPEND 'const alt=document.getElementById("alt");' TO lv.
    APPEND 'function doSend(){if(ws&&ws.readyState===1&&alt.value.trim()){ws.send(alt.value);alt.value=""}}' TO lv.
    APPEND 'alt.addEventListener("keydown",e=>{if(e.key==="Enter")doSend()});' TO lv.
    APPEND 'document.getElementById("send").addEventListener("click",doSend);' TO lv.
    APPEND 'term.onData(d=>{if(d==="\r"||d==="\n"){doSend()}});' TO lv.
    APPEND '</script></body></html>' TO lv.

    server->response->set_header_field( name = 'Content-Type' value = 'text/html; charset=utf-8' ).
    server->response->set_cdata( concat_lines_of( table = lv ) ).
  ENDMETHOD.

ENDCLASS.

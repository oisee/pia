CLASS zcl_pia_30_f_tui_handler DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_http_extension.
ENDCLASS.

CLASS zcl_pia_30_f_tui_handler IMPLEMENTATION.

  METHOD if_http_extension~handle_request.
    " NB: '...' literals pass backslashes through unchanged, so JS escapes are written once (\r, \x1b).
    DATA lv TYPE string_table.
    APPEND '<!DOCTYPE html><html><head>' TO lv.
    APPEND '<meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">' TO lv.
    APPEND '<title>PIA Terminal</title>' TO lv.
    APPEND '<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/xterm@5.3.0/css/xterm.css"/>' TO lv.
    APPEND '<style>body{margin:0;padding:16px;background:#0d1117;min-height:100vh;font-family:monospace}' TO lv.
    APPEND '#terminal{height:calc(100vh - 32px);border:1px solid #30363d;border-radius:6px}' TO lv.
    APPEND '</style></head><body>' TO lv.
    APPEND '<div id="terminal"></div>' TO lv.
    APPEND '<script src="https://cdn.jsdelivr.net/npm/xterm@5.3.0/lib/xterm.js"></script>' TO lv.
    APPEND '<script src="https://cdn.jsdelivr.net/npm/xterm-addon-fit@0.8.0/lib/xterm-addon-fit.js"></script>' TO lv.
    APPEND '<script>' TO lv.
    APPEND 'const APC="/sap/bc/apc/sap/zpia_tui";let ws,input="";' TO lv.
    APPEND 'const fit=new FitAddon.FitAddon();' TO lv.
    APPEND 'const term=new Terminal({cursorBlink:true,fontSize:14,theme:{background:"#0d1117",foreground:"#c9d1d9",cursor:"#58a6ff"}});' TO lv.
    APPEND 'term.loadAddon(fit);term.open(document.getElementById("terminal"));fit.fit();' TO lv.
    APPEND 'window.addEventListener("resize",()=>fit.fit());' TO lv.
    " status line: animated client-side, independent of when the server flushes
    APPEND 'const DONE="\x1b]777;pia-done\x07";' TO lv.
    APPEND 'const FR=["·","✢","✳","✶","✻","✽","✻","✶","✳","✢"];' TO lv.
    APPEND 'const VERBS=["Thinking","Reading","Pondering","Transpiling","Activating","Consulting DDIC",' TO lv.
    APPEND '"Weighing ABAP","Checking syntax","Tinkering","Finagling"];' TO lv.
    APPEND 'let st=null;' TO lv.
    APPEND 'function fmt(s){const m=Math.floor(s/60);return m?m+"m "+(s%60)+"s":s+"s"}' TO lv.
    APPEND 'function draw(){if(!st)return;const s=Math.floor((Date.now()-st.t0)/1000);' TO lv.
    APPEND 'const v=VERBS[Math.floor(s/4+st.v)%VERBS.length];' TO lv.
    APPEND 'term.write("\r\x1b[2K\x1b[38;5;209m"+FR[st.f++%FR.length]+" "+v+"…\x1b[0m\x1b[2m ("+fmt(s)+' TO lv.
    APPEND '" · ↓ "+st.n+" msg · "+(st.b/1024).toFixed(1)+"k)\x1b[0m")}' TO lv.
    APPEND 'function startStatus(){st={t0:Date.now(),f:0,n:0,b:0,v:Math.floor(Math.random()*VERBS.length)};' TO lv.
    APPEND 'st.h=setInterval(draw,120);draw()}' TO lv.
    APPEND 'function clearStatus(){if(st)term.write("\r\x1b[2K")}' TO lv.
    APPEND 'function stopStatus(){if(!st)return;clearInterval(st.h);clearStatus();st=null;prompt()}' TO lv.
    APPEND 'function connect(){' TO lv.
    APPEND 'const url=(location.protocol==="https:"?"wss:":"ws:")+"//"+location.host+APC;' TO lv.
    APPEND 'term.writeln("Connecting...");' TO lv.
    APPEND 'ws=new WebSocket(url);' TO lv.
    APPEND 'ws.onopen=()=>{term.write("\r\n\x1b[32mConnected\x1b[0m\r\n\r\n");prompt()};' TO lv.
    APPEND 'ws.onmessage=(e)=>{let d=e.data;const done=d.includes(DONE);d=d.split(DONE).join("");' TO lv.
    APPEND 'if(st){st.n++;st.b+=d.length;clearStatus()}' TO lv.
    APPEND 'if(d)term.write(d.replace(/(?<!\r)\n/g,"\r\n"));' TO lv.
    APPEND 'if(done)stopStatus();else draw()};' TO lv.
    APPEND 'ws.onclose=()=>{if(st){clearInterval(st.h);st=null}' TO lv.
    APPEND 'term.write("\r\n\x1b[31mDisconnected\x1b[0m\r\n");ws=null;setTimeout(connect,3000)};' TO lv.
    APPEND '}' TO lv.
    APPEND 'function prompt(){term.write("\x1b[36m> \x1b[0m")}' TO lv.
    APPEND 'function send(text){if(ws&&ws.readyState===1){ws.send(text);startStatus()}}' TO lv.
    " clipboard: selection is copied at once; Ctrl+C copies a selection or clears the line; Ctrl+V pastes.
    " Plain http on a LAN address has no navigator.clipboard, so copy falls back to execCommand.
    APPEND 'function copyText(t){if(!t)return;' TO lv.
    APPEND 'if(navigator.clipboard&&window.isSecureContext){navigator.clipboard.writeText(t).catch(()=>legacyCopy(t))}else legacyCopy(t)}' TO lv.
    APPEND 'function legacyCopy(t){const a=document.createElement("textarea");a.value=t;a.style.position="fixed";a.style.opacity="0";' TO lv.
    APPEND 'document.body.appendChild(a);a.select();try{document.execCommand("copy")}catch(e){}a.remove();term.focus()}' TO lv.
    APPEND 'term.onSelectionChange(()=>{const t=term.getSelection();if(t)copyText(t)});' TO lv.
    APPEND 'term.attachCustomKeyEventHandler(e=>{if(e.type!=="keydown"||!e.ctrlKey)return true;const k=e.key.toLowerCase();' TO lv.
    APPEND 'if(k==="c"){if(term.hasSelection()){copyText(term.getSelection());term.clearSelection();return false}' TO lv.
    APPEND 'if(!st&&input){term.write("^C\r\n");input="";prompt()}return false}' TO lv.
    APPEND 'if(k==="v")return false;' TO lv.
    APPEND 'return true});' TO lv.
    APPEND 'function typeText(t){t=t.replace(/\r\n|\r|\n/g," ");input+=t;term.write(t)}' TO lv.
    APPEND 'term.onData((data)=>{if(st)return;' TO lv.
    APPEND 'if(data==="\r"){term.writeln("");if(input.trim())send(input);else prompt();input=""}' TO lv.
    APPEND 'else if(data==="\x7f"){if(input.length>0){input=input.slice(0,-1);term.write("\b \b")}}' TO lv.
    APPEND 'else if(data.length>1){typeText(data.replace(/\x1b\[20[01]~/g,""))}' TO lv.
    APPEND 'else if(data>=" "){typeText(data)}' TO lv.
    APPEND '});' TO lv.
    APPEND 'connect();' TO lv.
    APPEND '</script></body></html>' TO lv.

    server->response->set_header_field( name = 'Content-Type' value = 'text/html; charset=utf-8' ).
    server->response->set_cdata( concat_lines_of( table = lv ) ).
  ENDMETHOD.

ENDCLASS.

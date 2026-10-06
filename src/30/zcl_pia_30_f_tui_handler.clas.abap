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
    APPEND 'const term=new Terminal({cursorBlink:true,fontSize:14,lineHeight:1.2,theme:{background:"#0d1117",foreground:"#c9d1d9",cursor:"#58a6ff"}});' TO lv.
    APPEND 'term.loadAddon(fit);term.open(document.getElementById("terminal"));fit.fit();' TO lv.
    APPEND 'window.addEventListener("resize",()=>fit.fit());' TO lv.
    " Footer = the two live rows at the bottom: the status line (while a turn runs) and the input line.
    " Output is written above the footer, then the footer is redrawn; typing works during a turn and
    " Enter then queues the message until the turn is done (the server takes one turn at a time).
    APPEND 'const DONE="\x1b]777;pia-done\x07",P="\x1b[36m> \x1b[0m";' TO lv.
    APPEND 'const FR=["·","✢","✳","✶","✻","✽","✻","✶","✳","✢"];' TO lv.
    APPEND 'const VERBS=["Thinking","Reading","Pondering","Transpiling","Activating","Consulting DDIC",' TO lv.
    APPEND '"Weighing ABAP","Checking syntax","Tinkering","Finagling"];' TO lv.
    APPEND 'let st=null,queued=[];' TO lv.
    " session id kept in the browser so a conversation survives reconnects; /new starts a fresh one
    APPEND 'function newSid(){const a="ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";let s="";for(let i=0;i<22;i++)s+=a[Math.floor(Math.random()*36)];' TO lv.
    APPEND 'try{localStorage.setItem("pia-sid",s)}catch(e){}return s}' TO lv.
    APPEND 'let sid=(()=>{try{return localStorage.getItem("pia-sid")}catch(e){return null}})()||newSid();' TO lv.
    " input history for Up/Down, kept in the browser
    APPEND 'let hist=(()=>{try{return JSON.parse(localStorage.getItem("pia-hist")||"[]")}catch(e){return[]}})(),hi=hist.length;' TO lv.
    APPEND 'function remember(t){if(hist[hist.length-1]!==t)hist.push(t);if(hist.length>100)hist=hist.slice(-100);hi=hist.length;' TO lv.
    APPEND 'try{localStorage.setItem("pia-hist",JSON.stringify(hist))}catch(e){}}' TO lv.
    APPEND 'function setInput(t){input=t;term.write("\r\x1b[2K"+P+t)}' TO lv.
    " ICM closes a WebSocket after 120 s without data: a heartbeat the server ignores
    APPEND 'setInterval(()=>{if(ws&&ws.readyState===1)ws.send("/hb")},50000);' TO lv.
    APPEND 'function fmt(s){const m=Math.floor(s/60);return m?m+"m "+(s%60)+"s":s+"s"}' TO lv.
    APPEND 'function statusText(){const s=Math.floor((Date.now()-st.t0)/1000);const v=VERBS[Math.floor(s/4+st.v)%VERBS.length];' TO lv.
    APPEND 'const q=queued.length?" · "+queued.length+" queued":"";' TO lv.
    APPEND 'return "\x1b[38;5;209m"+FR[st.f++%FR.length]+" "+v+"…\x1b[0m\x1b[2m ("+fmt(s)+" · ↓ "+st.n+" msg · "+(st.b/1024).toFixed(1)+"k"+q+")\x1b[0m"}' TO lv.
    APPEND 'function clearFooter(){term.write(st?"\r\x1b[2K\x1b[1A\r\x1b[2K":"\r\x1b[2K")}' TO lv.
    APPEND 'function drawFooter(){if(st)term.write(statusText()+"\r\n");term.write(P+input)}' TO lv.
    APPEND 'function above(t){clearFooter();if(t){t=t.replace(/(?<!\r)\n/g,"\r\n");if(!t.endsWith("\n"))t+="\r\n";term.write(t)}drawFooter()}' TO lv.
    APPEND 'function tick(){if(st)term.write("\x1b7\x1b[1A\r\x1b[2K"+statusText()+"\x1b8")}' TO lv.
    APPEND 'function sendNow(t){if(!(ws&&ws.readyState===1))return false;clearFooter();term.write(P+t+"\r\n");' TO lv.
    APPEND 'ws.send(t);st={t0:Date.now(),f:0,n:0,b:0,v:Math.floor(Math.random()*VERBS.length)};st.h=setInterval(tick,120);drawFooter();return true}' TO lv.
    APPEND 'function done(){if(!st)return;clearFooter();clearInterval(st.h);st=null;' TO lv.
    APPEND 'if(queued.length){sendNow(queued.shift())}else drawFooter()}' TO lv.
    APPEND 'function connect(){' TO lv.
    APPEND 'const url=(location.protocol==="https:"?"wss:":"ws:")+"//"+location.host+APC+"?sid="+sid;' TO lv.
    APPEND 'term.writeln("Connecting...");' TO lv.
    APPEND 'ws=new WebSocket(url);' TO lv.
    APPEND 'ws.onopen=()=>{term.write("\x1b[32mConnected\x1b[0m\r\n\r\n");drawFooter()};' TO lv.
    APPEND 'ws.onmessage=(e)=>{let d=e.data;const fin=d.includes(DONE);d=d.split(DONE).join("");' TO lv.
    APPEND 'if(st){st.n++;st.b+=d.length}if(d)above(d);if(fin)done()};' TO lv.
    APPEND 'ws.onclose=()=>{clearFooter();if(st){clearInterval(st.h);st=null}' TO lv.
    APPEND 'term.write("\x1b[31mDisconnected\x1b[0m\r\n");ws=null;setTimeout(connect,3000)};' TO lv.
    APPEND '}' TO lv.
    " clipboard: selection is copied at once; Ctrl+C copies a selection or clears the line; Ctrl+V pastes.
    " Plain http on a LAN address has no navigator.clipboard, so copy falls back to execCommand.
    APPEND 'function copyText(t){if(!t)return;' TO lv.
    APPEND 'if(navigator.clipboard&&window.isSecureContext){navigator.clipboard.writeText(t).catch(()=>legacyCopy(t))}else legacyCopy(t)}' TO lv.
    APPEND 'function legacyCopy(t){const a=document.createElement("textarea");a.value=t;a.style.position="fixed";a.style.opacity="0";' TO lv.
    APPEND 'document.body.appendChild(a);a.select();try{document.execCommand("copy")}catch(e){}a.remove();term.focus()}' TO lv.
    APPEND 'term.onSelectionChange(()=>{const t=term.getSelection();if(t)copyText(t)});' TO lv.
    APPEND 'term.attachCustomKeyEventHandler(e=>{if(e.type!=="keydown"||!e.ctrlKey)return true;const k=e.key.toLowerCase();' TO lv.
    APPEND 'if(k==="c"){if(term.hasSelection()){copyText(term.getSelection());term.clearSelection();return false}' TO lv.
    APPEND 'if(input){input="";term.write("\r\x1b[2K"+P)}return false}' TO lv.
    APPEND 'if(k==="v"){if(navigator.clipboard&&window.isSecureContext&&navigator.clipboard.readText){' TO lv.
    APPEND 'navigator.clipboard.readText().then(t=>{if(t)typeText(t)}).catch(()=>{});e.preventDefault()}return false}' TO lv.
    APPEND 'return true});' TO lv.
    APPEND 'function typeText(t){t=t.replace(/\r\n|\r|\n/g," ");input+=t;term.write(t)}' TO lv.
    " paste through the browser event (works on plain http too); capture phase so xterm does not paste twice
    APPEND 'term.textarea.addEventListener("paste",e=>{const t=e.clipboardData&&e.clipboardData.getData("text");' TO lv.
    APPEND 'if(t){e.preventDefault();e.stopImmediatePropagation();typeText(t)}},true);' TO lv.
    APPEND 'term.onData((data)=>{' TO lv.
    APPEND 'if(data==="\r"){const t=input.trim();input="";if(!t){term.write("\r\x1b[2K"+P);return}' TO lv.
    APPEND 'remember(t);' TO lv.
    APPEND 'if(t==="/new"&&!st){sid=newSid();above("\x1b[2mnew session "+sid+"\x1b[0m");if(ws)ws.close();return}' TO lv.
    APPEND 'if(st){queued.push(t);above("\x1b[2m  queued: "+t+"\x1b[0m")}else if(!sendNow(t)){input=t;term.write(t)}}' TO lv.
    APPEND 'else if(data==="\x7f"){if(input.length>0){input=input.slice(0,-1);term.write("\b \b")}}' TO lv.
    APPEND 'else if(data==="\x1b[A"||data==="\x1bOA"){if(hi>0){hi--;setInput(hist[hi])}}' TO lv.
    APPEND 'else if(data==="\x1b[B"||data==="\x1bOB"){if(hi<hist.length-1){hi++;setInput(hist[hi])}else{hi=hist.length;setInput("")}}' TO lv.
    APPEND 'else if(data.charAt(0)==="\x1b"){}' TO lv.
    APPEND 'else if(data.length>1){typeText(data.replace(/\x1b\[20[01]~/g,""))}' TO lv.
    APPEND 'else if(data>=" "){typeText(data)}' TO lv.
    APPEND '});' TO lv.
    APPEND 'connect();' TO lv.
    APPEND '</script></body></html>' TO lv.

    server->response->set_header_field( name = 'Content-Type' value = 'text/html; charset=utf-8' ).
    server->response->set_cdata( concat_lines_of( table = lv ) ).
  ENDMETHOD.

ENDCLASS.

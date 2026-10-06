REPORT zpia_daemon.
" Starts the PIA turn daemon (ZCL_PIA_30_TURN_DAEMON, name PIA_TURNS) unless it is running.
DATA(lv_error) = zcl_pia_30_turn_daemon=>ensure_running( ).
IF lv_error IS INITIAL.
  WRITE / 'PIA_TURNS daemon running'.
ELSE.
  WRITE: / 'PIA_TURNS daemon not started:', lv_error.
ENDIF.

REPORT zpia_turn.
" Background job of one PIA terminal turn (see zcl_pia_30_turn). The session id comes as P_SID
" (open-steamgate: SUBMIT ... WITH) or from the job name PIA_<sid> (SAP: JOB_SUBMIT, no variant).
PARAMETERS p_sid TYPE c LENGTH 26 LOWER CASE.

IF p_sid IS INITIAL.
  zcl_pia_30_turn=>run_as_job( ).
ELSE.
  zcl_pia_30_turn=>run( condense( CONV string( p_sid ) ) ).
ENDIF.

CLASS zcl_pia_30_turn DEFINITION PUBLIC FINAL CREATE PUBLIC.

  " One agent turn of a terminal session, outside the push channel: load the conversation,
  " take the pending task, run the executor, publish everything over AMC (channel extension =
  " session id), save the conversation. On SAP an APC handler may not run ABAP Unit or write
  " sources itself ("Invalid statement in ABAP push channel"), so the turn runs in a background
  " job or an ABAP daemon; in OSG it may also run inline.

  PUBLIC SECTION.
    CONSTANTS c_job_prefix TYPE string VALUE `PIA_`.

    CLASS-METHODS run IMPORTING iv_sid TYPE string.

    " schedule the turn as an immediate background job named PIA_<sid> (the job finds its sid
    " in its own name, so no variant is needed); returns an error text or ''
    CLASS-METHODS start_job
      IMPORTING iv_sid     TYPE string
      RETURNING VALUE(rv_) TYPE string.

    " the job's own entry point: sid from the running job's name
    CLASS-METHODS run_as_job.

    CLASS-METHODS system_prompt
      IMPORTING iv_backend TYPE string
      RETURNING VALUE(rv_) TYPE string.

ENDCLASS.

CLASS zcl_pia_30_turn IMPLEMENTATION.

  METHOD system_prompt.
    rv_ = |You are PIA (Pi-ABAP Agent), written in ABAP, running on the model { zcl_pia_00_config=>model( ) } (z.ai) |
       && |through backend { iv_backend }. If asked which model you are, say exactly that; never claim another model or vendor. |
       && `Tools: outline(name), read_method(name, method, class), write_method(name, method, source - one METHOD block, class), `
       && `read_object(name, include main|testclasses), write_source(name, source - FULL source, include), activate(name), run_tests(name). `
       && `Rules: prefer outline, read_method and write_method for changing existing methods; use write_source only for new methods, `
       && `changed declarations or a new test include, and then write the FULL source; read before write; always activate after write; `
       && `if activation says publish pending, finish the turn and run_tests in the next turn. Answer briefly in the user language. `
       " a map of PIA's own code, as in the README: the agent can read and change itself
       && `Your own code: ZCL_PIA_00_EXECUTOR (agent loop), ZCL_PIA_00_LLM_HTTP (LLM client: builds requests, parses responses `
       && `and tool calls), ZCL_PIA_00_JSON_UTIL (JSON helpers), ZCL_PIA_00_CONFIG (settings from pia.env), `
       && `ZCL_PIA_00_SESSION and ZCL_PIA_00_SESSION_STORE (conversation), `
       && `ZCL_PIA_00_REGISTRY (tools), ZCL_PIA_15_T_* (the tools), ZCL_PIA_20_B_* (backends), ZCL_PIA_30_* (terminal, turns). `
       && `Unit tests live in the testclasses include of a class.`.
  ENDMETHOD.

  METHOD run.
    DATA lv_task TYPE string.
    DATA(lo_amc) = zcl_pia_00_amc_listener=>new( iv_extension = iv_sid ).
    TRY.
        lv_task = zcl_pia_00_session_store=>take_task( iv_sid ).
        IF lv_task IS INITIAL.
          lo_amc->publish_error( |no pending task for session { iv_sid }| ).
          lo_amc->publish_done( ).
          RETURN.
        ENDIF.
        DATA(lo_session) = zcl_pia_00_session_store=>load( iv_sid ).
        DATA(lo_backend) = zcl_pia_20_backend=>default( ).
        " self-hosting insurance: if PIA's last change to its own code broke reading tool calls, roll it back
        " before asking the LLM (that code could not parse the answer) and end the turn
        DATA(lv_guard) = zcl_pia_15_self_guard=>check_and_restore( lo_backend ).
        IF lv_guard IS NOT INITIAL.
          lo_session->push_message( iv_role = 'user' iv_content = lv_task ).
          lo_session->push_message( iv_role = 'assistant' iv_content = |[PIA runtime] { lv_guard }| ).
          zcl_pia_00_session_store=>save( iv_sid = iv_sid io_session = lo_session ).
          lo_amc->publish_answer( |[PIA runtime] { lv_guard }| ).
          lo_amc->publish_done( ).
          RETURN.
        ENDIF.
        DATA(lo_registry) = zcl_pia_00_registry=>new( ).
        zcl_pia_15_toolset=>register_dev_tools( io_registry = lo_registry io_backend = lo_backend ).
        DATA(lo_llm) = zcl_pia_00_llm_http=>new( VALUE #(
          base_url = 'https://api.z.ai/api/v1/responses'
          model    = zcl_pia_00_config=>model( )
          api_key  = zcl_pia_00_config=>get( `ZAI_API_KEY` )
          api_type = 'responses' ) ).
        DATA(lo_exec) = zcl_pia_00_executor=>new(
          io_llm      = lo_llm
          io_registry = lo_registry
          io_session  = lo_session
          io_listener = lo_amc ).
        DATA(ls_result) = lo_exec->run(
          iv_task           = lv_task
          iv_system         = system_prompt( lo_backend->get_name( ) )
          iv_max_iterations = 8
          iv_continue       = xsdbool( lines( lo_session->get_messages( ) ) > 0 ) ).
        zcl_pia_00_session_store=>save( iv_sid = iv_sid io_session = lo_session ).
        " the LLM refused the request (4xx, not a rate limit) while PIA's own code was changed: roll it back too
        IF ls_result-error CP 'HTTP 4*' AND ls_result-error NP 'HTTP 429*'.
          DATA(lv_back) = zcl_pia_15_self_guard=>check_and_restore(
            io_backend = lo_backend iv_failure = |the LLM refused the request ({ substring( val = ls_result-error len = nmin( val1 = 200 val2 = strlen( ls_result-error ) ) ) })| ).
          IF lv_back IS NOT INITIAL.
            lo_session->push_message( iv_role = 'assistant' iv_content = |[PIA runtime] { lv_back }| ).
            zcl_pia_00_session_store=>save( iv_sid = iv_sid io_session = lo_session ).
            ls_result-error = |{ ls_result-error }\n[PIA runtime] { lv_back }|.
          ENDIF.
        ENDIF.
        IF ls_result-error IS NOT INITIAL.
          lo_amc->publish_error( ls_result-error ).
        ELSE.
          lo_amc->publish_answer( ls_result-answer ).
        ENDIF.
        lo_amc->publish_info( |iters={ ls_result-iterations } tools={ ls_result-tool_calls }| ).
      CATCH cx_root INTO DATA(lx).
        lo_amc->publish_error( lx->get_text( ) ).
    ENDTRY.
    lo_amc->publish_done( ).
  ENDMETHOD.

  METHOD start_job.
    DATA lv_name TYPE c LENGTH 32.  " BTCJOB
    DATA lv_count TYPE c LENGTH 8.  " BTCJOBCNT
    lv_name = c_job_prefix && iv_sid.
    CALL FUNCTION 'JOB_OPEN'
      EXPORTING jobname  = lv_name
      IMPORTING jobcount = lv_count
      EXCEPTIONS OTHERS  = 1.
    IF sy-subrc <> 0.
      rv_ = |JOB_OPEN failed ({ sy-subrc })|.
      RETURN.
    ENDIF.
    IF zcl_pia_20_backend=>default( )->get_name( ) = `SAP-ADT`.
      " SAP: no variant needed, the job finds its sid in its own name (GET_JOB_RUNTIME_INFO)
      CALL FUNCTION 'JOB_SUBMIT'
        EXPORTING authcknam = sy-uname
                  jobcount  = lv_count
                  jobname   = lv_name
                  report    = 'ZPIA_TURN'
        EXCEPTIONS OTHERS   = 1.
      IF sy-subrc <> 0.
        rv_ = |JOB_SUBMIT failed ({ sy-subrc })|.
        RETURN.
      ENDIF.
    ELSE.
      " open-steamgate: no GET_JOB_RUNTIME_INFO; the sid travels as a selection parameter
      DATA lv_sid TYPE c LENGTH 26.
      lv_sid = iv_sid.
      SUBMIT zpia_turn WITH p_sid = lv_sid VIA JOB lv_name NUMBER lv_count AND RETURN.
    ENDIF.
    CALL FUNCTION 'JOB_CLOSE'
      EXPORTING jobcount  = lv_count
                jobname   = lv_name
                strtimmed = abap_true
      EXCEPTIONS OTHERS   = 1.
    IF sy-subrc <> 0.
      rv_ = |JOB_CLOSE failed ({ sy-subrc })|.
    ENDIF.
  ENDMETHOD.

  METHOD run_as_job.
    DATA lv_name TYPE c LENGTH 32.  " BTCJOB
    CALL FUNCTION 'GET_JOB_RUNTIME_INFO'
      IMPORTING jobname = lv_name
      EXCEPTIONS OTHERS = 1.
    IF sy-subrc <> 0 OR lv_name NP 'PIA_*'.
      RETURN.
    ENDIF.
    run( condense( substring( val = lv_name off = strlen( c_job_prefix ) ) ) ).
  ENDMETHOD.

ENDCLASS.

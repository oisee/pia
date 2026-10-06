CLASS zcl_pia_90_agent_run DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.

CLASS zcl_pia_90_agent_run IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.
    out->write( `PIA M1: live agent run` ).

    DATA(lo_backend) = zcl_pia_20_b_osg_store=>new( ).
    DATA(lo_registry) = zcl_pia_00_registry=>new( ).

    zcl_pia_15_toolset=>register_dev_tools( io_registry = lo_registry io_backend = lo_backend ).

    DATA(lo_llm) = zcl_pia_00_llm_http=>new( VALUE #(
      base_url = 'https://api.z.ai/api/v1/responses'
      model    = zcl_pia_00_config=>model( ) api_key = zcl_pia_00_config=>get( `ZAI_API_KEY` ) api_type = 'responses' ) ).

    DATA(lo_session) = zcl_pia_00_session=>new( 'fix ADD in ZCL_PIA_DEMO' ).

    DATA(lo_exec) = zcl_pia_00_executor=>new(
      io_llm      = lo_llm
      io_registry = lo_registry
      io_session  = lo_session ).

    DATA(ls) = lo_exec->run(
      iv_task = 'Class ZCL_PIA_DEMO: method ADD returns a - b but must return a + b. '
             &&  'Read the class, write the full corrected source, activate it.'
      iv_system = 'You are PIA, an ABAP coding agent running inside an ABAP runtime. '
               && 'Tools: read_object(name), write_source(name, source, include), activate(name), run_tests(name). '
               && 'Rules: read before write; write_source takes the COMPLETE class source; '
               && 'always activate after write; the new code goes live in the NEXT step, '
               && 'so finish with a one-line summary right after activate. Be terse.'
      iv_max_iterations = 8 ).

    out->write( |ANSWER: { ls-answer }| ).
    out->write( |RESULT: iters={ ls-iterations } tool_calls={ ls-tool_calls } ok={ ls-ok } err={ ls-error }| ).
    out->write( `--- tool trace ---` ).
    LOOP AT lo_session->get_trace( ) INTO DATA(ls_t).
      out->write( |[{ ls_t-tool }] ok={ ls_t-ok }| ).
      out->write( |  args: { ls_t-args }| ).
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.

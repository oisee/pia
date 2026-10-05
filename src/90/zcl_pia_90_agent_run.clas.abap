CLASS zcl_pia_90_agent_run DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.

CLASS zcl_pia_90_agent_run IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.
    out->write( `PIA M1: live agent run` ).

    DATA(lo_backend) = zcl_pia_20_b_osg_store=>new( ).
    DATA(lo_registry) = zcl_pia_00_registry=>new( ).

    DATA(lo_read) = NEW zcl_pia_10_t_read_object( ).
    lo_read->set_backend( lo_backend ).
    lo_registry->register( lo_read ).

    DATA(lo_write) = NEW zcl_pia_15_t_write_source( ).
    lo_write->set_backend( lo_backend ).
    lo_registry->register( lo_write ).

    DATA(lo_act) = NEW zcl_pia_15_t_activate( ).
    lo_act->set_backend( lo_backend ).
    lo_registry->register( lo_act ).

    DATA(lo_llm) = zcl_pia_00_llm_http=>new( VALUE #(
      base_url = 'https://api.z.ai/api/v1/responses'
      model    = 'glm-5.3-flash' api_key = 'PIA_ZAI_KEY' api_type = 'responses' ) ).

    DATA(lo_session) = zcl_pia_00_session=>new( 'fix ADD in ZCL_PIA_DEMO' ).

    DATA(lo_exec) = zcl_pia_00_executor=>new(
      io_llm      = lo_llm
      io_registry = lo_registry
      io_session  = lo_session ).

    DATA(ls) = lo_exec->run(
      iv_task = 'Class ZCL_PIA_DEMO: method ADD returns a - b but must return a + b. '
             &&  'Read the class, write the full corrected source, activate it.'
      iv_system = 'You are PIA, an ABAP coding agent running inside an ABAP runtime. '
               && 'Tools: read_object(name), write_source(name, source), activate(name). '
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

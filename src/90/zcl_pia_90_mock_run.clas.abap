CLASS zcl_pia_90_mock_run DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.

CLASS zcl_pia_90_mock_run IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.
    out->write( `PIA M1: mock loop` ).
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
    DATA(lo_llm) = zcl_pia_00_llm_mock=>new( ).
    lo_llm->add_response( '{"choices":[{"message":{"role":"assistant","content":"","tool_calls":[{"id":"c1","type":"function","function":{"name":"read_object","arguments":"{\"name\":\"ZCL_PIA_DEMO\"}"}}]},"finish_reason":"tool_calls"}]}' ).
    lo_llm->add_response( '{"choices":[{"message":{"role":"assistant","content":"","tool_calls":[{"id":"c2","type":"function","function":{"name":"write_source","arguments":"{\"name\": \"ZCL_PIA_DEMO\", \"source\": \"CLASS zcl_pia_demo DEFINITION PUBLIC FINAL CREATE PUBLIC.\\n  PUBLIC SECTION.\\n    CLASS-METHODS add\\n      IMPORTING a          TYPE i\\n                b          TYPE i\\n      RETURNING VALUE(rv_) TYPE i.\\n    CLASS-METHODS selfcheck RETURNING VALUE(rv_) TYPE string.\\nENDCLASS.\\n\\nCLASS zcl_pia_demo IMPLEMENTATION.\\n  METHOD add.\\n    rv_ = a + b.\\n  ENDMETHOD.\\n  METHOD selfcheck.\\n    IF zcl_pia_demo=>add( a = 2 b = 2 ) = 4.\\n      rv_ = ''PASS: add(2,2)=4''.\\n    ELSE.\\n      rv_ = |FAIL: add(2,2)={ zcl_pia_demo=>add( a = 2 b = 2 ) }, expected 4|.\\n    ENDIF.\\n  ENDMETHOD.\\nENDCLASS.\"}"}}]},"finish_reason":"tool_calls"}]}' ).
    lo_llm->add_response( '{"choices":[{"message":{"role":"assistant","content":"","tool_calls":[{"id":"c3","type":"function","function":{"name":"activate","arguments":"{\"name\":\"ZCL_PIA_DEMO\"}"}}]},"finish_reason":"tool_calls"}]}' ).
    lo_llm->add_response( '{"choices":[{"message":{"role":"assistant","content":"Fixed: ADD now returns a + b; written and activated."},"finish_reason":"stop"}]}' ).
    DATA(lo_session) = zcl_pia_00_session=>new( |mock fix| ).
    DATA(lo_exec) = zcl_pia_00_executor=>new( io_llm = lo_llm io_registry = lo_registry io_session = lo_session ).
    DATA(ls) = lo_exec->run( iv_task = |fix demo| iv_system = |sys| iv_max_iterations = 6 ).
    out->write( |ANSWER: { ls-answer } ok={ ls-ok } err={ ls-error } tools={ ls-tool_calls }| ).
    LOOP AT lo_session->get_trace( ) INTO DATA(ls_t).
      out->write( |[{ ls_t-tool }] ok={ ls_t-ok } out: { ls_t-output }| ).
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.

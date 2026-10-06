CLASS zcl_pia_p3b_accept DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
  PRIVATE SECTION.
    CONSTANTS c_state TYPE string VALUE `/home/alice/dev/pia/.state/p3b.state`.
    CONSTANTS c_cut TYPE string VALUE `ZCL_PIA_P3B_CUT`.
    DATA mo_out TYPE REF TO if_oo_adt_classrun_out.
    METHODS step1.
    METHODS step2 IMPORTING iv_op TYPE string.
    METHODS step3 IMPORTING iv_gen1 TYPE string iv_op TYPE string.
    METHODS store IMPORTING iv_command TYPE string iv_type TYPE string DEFAULT `CLAS`
                            iv_name TYPE string OPTIONAL iv_include TYPE string OPTIONAL
                            iv_json TYPE string OPTIONAL iv_source TYPE string OPTIONAL
                  RETURNING VALUE(rv_) TYPE string.
    METHODS run_tests IMPORTING iv_label TYPE string iv_json TYPE string.
    METHODS cut_source IMPORTING iv_op TYPE string RETURNING VALUE(rv_) TYPE string.
    METHODS field IMPORTING iv_json TYPE string iv_name TYPE string RETURNING VALUE(rv_) TYPE string.
    METHODS read_state RETURNING VALUE(rv_) TYPE string.
    METHODS write_state IMPORTING iv_ TYPE string.
ENDCLASS.

CLASS zcl_pia_p3b_accept IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.
    DATA lv_state TYPE string.
    DATA lv_step TYPE string.
    DATA lv_a TYPE string.
    DATA lv_b TYPE string.
    mo_out = out.
    lv_state = read_state( ).
    SPLIT lv_state AT `;` INTO lv_step lv_a lv_b.
    CASE lv_step.
      WHEN `2`. step2( lv_a ).
      WHEN `3`. step3( iv_gen1 = lv_a iv_op = lv_b ).
      WHEN OTHERS. step1( ).
    ENDCASE.
  ENDMETHOD.

  METHOD cut_source.
    rv_ = |CLASS zcl_pia_p3b_cut DEFINITION PUBLIC FINAL CREATE PUBLIC. PUBLIC SECTION. | &&
          |CLASS-METHODS add IMPORTING a TYPE i b TYPE i RETURNING VALUE(r) TYPE i. ENDCLASS. | &&
          |CLASS zcl_pia_p3b_cut IMPLEMENTATION. METHOD add. r = a { iv_op } b. ENDMETHOD. ENDCLASS.|.
  ENDMETHOD.

  METHOD step1.
    DATA lv_act TYPE string.
    mo_out->write( `STEP1: create CUT with bug (a - b), red test, activate` ).
    mo_out->write( |create: { store( iv_command = `CREATE` iv_name = c_cut
      iv_json = `{"package":"$TMP","description":"p3b cut"}` iv_source = cut_source( `-` ) ) }| ).
    mo_out->write( |write tests: { store( iv_command = `WRITE` iv_name = c_cut iv_include = `testclasses`
      iv_source = `CLASS ltcl_add DEFINITION FOR TESTING RISK LEVEL HARMLESS DURATION SHORT. PRIVATE SECTION. METHODS add_2_3 FOR TESTING. ENDCLASS. ` &&
                  `CLASS ltcl_add IMPLEMENTATION. METHOD add_2_3. cl_abap_unit_assert=>assert_equals( act = zcl_pia_p3b_cut=>add( a = 2 b = 3 ) exp = 5 msg = 'add' ). ENDMETHOD. ENDCLASS.` ) }| ).
    lv_act = store( iv_command = `ACTIVATE` iv_name = c_cut ).
    mo_out->write( |activate: { lv_act }| ).
    run_tests( iv_label = `run_tests while pending (expect not_run/PUBLICATION_PENDING)`
               iv_json = |\{"targets":[\{"type":"CLAS","name":"{ c_cut }"\}]\}| ).
    write_state( |2;{ field( iv_json = lv_act iv_name = `op_id` ) }| ).
  ENDMETHOD.

  METHOD step2.
    DATA lv_st TYPE string.
    DATA lv_gen TYPE string.
    DATA lv_act TYPE string.
    mo_out->write( `STEP2: published? red run, fix, activate` ).
    lv_st = store( iv_command = `ACTIVATION_STATUS` iv_json = |\{"op_id":"{ iv_op }"\}| ).
    lv_gen = field( iv_json = lv_st iv_name = `generation_id` ).
    mo_out->write( |status: state={ field( iv_json = lv_st iv_name = `state` ) } gen={ lv_gen }| ).
    run_tests( iv_label = `RED (expect ran, fail, expected 5 actual -1)`
               iv_json = |\{"targets":[\{"type":"CLAS","name":"{ c_cut }"\}],"expected_generation":"{ lv_gen }"\}| ).
    mo_out->write( |fix: { store( iv_command = `WRITE` iv_name = c_cut iv_source = cut_source( `+` ) ) }| ).
    lv_act = store( iv_command = `ACTIVATE` iv_name = c_cut ).
    mo_out->write( |activate: { lv_act }| ).
    write_state( |3;{ lv_gen };{ field( iv_json = lv_act iv_name = `op_id` ) }| ).
  ENDMETHOD.

  METHOD step3.
    DATA lv_st TYPE string.
    DATA lv_gen TYPE string.
    mo_out->write( `STEP3: green, mismatch, negatives, delete` ).
    lv_st = store( iv_command = `ACTIVATION_STATUS` iv_json = |\{"op_id":"{ iv_op }"\}| ).
    lv_gen = field( iv_json = lv_st iv_name = `generation_id` ).
    mo_out->write( |status: state={ field( iv_json = lv_st iv_name = `state` ) } gen={ lv_gen }| ).
    run_tests( iv_label = `GREEN (expect ran, pass)`
               iv_json = |\{"targets":[\{"type":"CLAS","name":"{ c_cut }"\}],"expected_generation":"{ lv_gen }"\}| ).
    run_tests( iv_label = `old generation (expect not_run/GENERATION_MISMATCH)`
               iv_json = |\{"targets":[\{"type":"CLAS","name":"{ c_cut }"\}],"expected_generation":"{ iv_gen1 }"\}| ).
    run_tests( iv_label = `missing target (expect class state error/not_found)`
               iv_json = `{"targets":[{"type":"CLAS","name":"ZCL_PIA_P3B_NOPE"}]}` ).
    run_tests( iv_label = `PROG target (expect not_run/NOT_SUPPORTED)`
               iv_json = `{"targets":[{"type":"PROG","name":"ZPIA_NOPE"}]}` ).
    mo_out->write( |status unknown op: { store( iv_command = `ACTIVATION_STATUS` iv_json = `{"op_id":"00000000-0000-0000-0000-000000000000"}` ) }| ).
    mo_out->write( |delete: { store( iv_command = `DELETE` iv_name = c_cut ) }| ).
    write_state( `` ).
    mo_out->write( `STEP3 done` ).
  ENDMETHOD.

  METHOD run_tests.
    mo_out->write( |{ iv_label }: { store( iv_command = `RUN_TESTS` iv_type = `` iv_json = iv_json ) }| ).
  ENDMETHOD.

  METHOD store.
    TRY.
        rv_ = zcl_osd_adt_host=>store( iv_command = iv_command iv_type = iv_type iv_name = iv_name
                                       iv_include = iv_include iv_json = iv_json iv_source = iv_source )-json.
      CATCH cx_root INTO DATA(lx).
        rv_ = |EXCEPTION { lx->get_text( ) }|.
    ENDTRY.
  ENDMETHOD.

  METHOD field.
    rv_ = zcl_pia_00_json_util=>extract_str( iv_json = iv_json iv_name = iv_name ).
  ENDMETHOD.

  METHOD read_state.
    TRY.
        OPEN DATASET c_state FOR INPUT IN TEXT MODE ENCODING UTF-8.
        IF sy-subrc = 0.
          READ DATASET c_state INTO rv_.
          CLOSE DATASET c_state.
        ENDIF.
      CATCH cx_root.
        CLEAR rv_.
    ENDTRY.
  ENDMETHOD.

  METHOD write_state.
    TRY.
        OPEN DATASET c_state FOR OUTPUT IN TEXT MODE ENCODING UTF-8.
        IF sy-subrc = 0.
          IF iv_ IS NOT INITIAL.
            TRANSFER iv_ TO c_state.
          ENDIF.
          CLOSE DATASET c_state.
        ENDIF.
      CATCH cx_root INTO DATA(lx).
        mo_out->write( |state write failed: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.
ENDCLASS.

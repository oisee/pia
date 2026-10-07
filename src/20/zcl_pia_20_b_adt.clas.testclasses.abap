" X2 fixture: a real ABAP Unit runResult from SAP (A4H, a copy of ZCL_PIA_DEMO with add = a - b; class
" name masked as ZCL_X) and the RUN_TESTS JSON fields it must give. open-steamgate pins the same pair.
CLASS ltcl_aunit DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    METHODS red_fixture FOR TESTING.
    METHODS green_fixture FOR TESTING.
    METHODS map IMPORTING iv_xml TYPE string EXPORTING ev_json TYPE string ev_fail TYPE i ev_err TYPE i ev_pass TYPE i.
ENDCLASS.

CLASS zcl_pia_20_b_adt DEFINITION LOCAL FRIENDS ltcl_aunit.

CLASS ltcl_aunit IMPLEMENTATION.

  METHOD map.
    zcl_pia_20_b_adt=>new( )->aunit_to_json( EXPORTING iv_xml = iv_xml
      IMPORTING ev_json = ev_json ev_fail = ev_fail ev_err = ev_err ev_pass = ev_pass ).
  ENDMETHOD.

  METHOD red_fixture.
    DATA(lv_xml) = `<?xml version="1.0" encoding="utf-8"?><aunit:runResult xmlns:aunit="http://www.sap.com/adt/aunit"><program adtcore:uri="/sap/bc/adt/oo/classes/zcl_x" adtcore:type="CLAS/OC" adtcore`
      && `:name="ZCL_X" uriType="semantic" xmlns:adtcore="http://www.sap.com/adt/core"><testClasses><testClass adtcore:uri="/sap/bc/adt/oo/classes/zcl_x#testclass=LTCL_ADD" adtcore:type="CLA`
      && `S/OL" adtcore:name="LTCL_ADD" uriType="semantic" navigationUri="/sap/bc/adt/oo/classes/zcl_x/includes/testclasses#type=CLAS%2FOCL;name=LTCL_ADD" durationCategory="short" riskLevel=`
      && `"harmless"><testMethods><testMethod adtcore:uri="/sap/bc/adt/oo/classes/zcl_x#testclass=LTCL_ADD;testmethod=ADD_2_3" adtcore:type="CLAS/OLI" adtcore:name="ADD_2_3" executionTime="0`
      && `" uriType="semantic" navigationUri="/sap/bc/adt/oo/classes/zcl_x/includes/testclasses#type=CLAS%2FOLD;name=LTCL_ADD%20%20%20%20%20%20%20%20%20%20%20%20%20%20%20%20%20%20%20%20%20%2`
      && `0ADD_2_3" unit="s"><alerts><alert kind="failedAssertion" severity="critical"><title>Critical Assertion Error: 'add'</title><details><detail text="Different values"><details><detail`
      && ` text="Expected [5] Actual [1-]"/></details></detail><detail text="Test 'LTCL_ADD-&gt;ADD_2_3' in Main Program 'ZCL_X=============CP'"/></details><stack><stackEntry adtcore:uri="/s`
      && `ap/bc/adt/oo/classes/zcl_x/includes/testclasses#start=7,0" adtcore:type="CLAS/OCN/testclasses" adtcore:name="ZCL_X" adtcore:description="Include: &lt;ZCL_X=============CCAU&gt; Lin`
      && `e: &lt;7&gt; (ADD_2_3)"/></stack></alert></alerts></testMethod></testMethods></testClass></testClasses></program></aunit:runResult>`.
    map( EXPORTING iv_xml = lv_xml IMPORTING ev_json = DATA(lv_json) ev_fail = DATA(lv_fail) ev_err = DATA(lv_err) ev_pass = DATA(lv_pass) ).
    cl_abap_unit_assert=>assert_equals( act = lv_fail exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lv_err exp = 0 ).
    cl_abap_unit_assert=>assert_equals( act = lv_pass exp = 0 ).
    cl_abap_unit_assert=>assert_char_cp( act = lv_json exp = `{"state":"ran","counts":{"classes":1,"methods":1,"pass":0,"fail":1,"error":0,"skipped":0}*` ).
    cl_abap_unit_assert=>assert_char_cp( act = lv_json exp = `*"classes":[{"name":"LTCL_ADD","state":"ok","methods":[{"name":"ADD_2_3","verdict":"fail"*` ).
    cl_abap_unit_assert=>assert_char_cp( act = lv_json exp = `*"kind":"failedAssertion"*"expected":"5","actual":"1-","line":7,*` ).
  ENDMETHOD.

  METHOD green_fixture.
    DATA(lv_xml) = `<?xml version="1.0" encoding="utf-8"?><aunit:runResult xmlns:aunit="http://www.sap.com/adt/aunit"><program adtcore:uri="/sap/bc/adt/oo/classes/zcl_x" adtcore:type="CLAS/OC" adtcore`
      && `:name="ZCL_X" uriType="semantic" xmlns:adtcore="http://www.sap.com/adt/core"><testClasses><testClass adtcore:uri="/sap/bc/adt/oo/classes/zcl_x#testclass=LTCL_ADD" adtcore:type="CLA`
      && `S/OL" adtcore:name="LTCL_ADD" uriType="semantic" navigationUri="/sap/bc/adt/oo/classes/zcl_x/includes/testclasses#type=CLAS%2FOCL;name=LTCL_ADD" durationCategory="short" riskLevel=`
      && `"harmless"><testMethods><testMethod adtcore:uri="/sap/bc/adt/oo/classes/zcl_x#testclass=LTCL_ADD;testmethod=ADD_2_3" adtcore:type="CLAS/OLI" adtcore:name="ADD_2_3" executionTime="0`
      && `" uriType="semantic" navigationUri="/sap/bc/adt/oo/classes/zcl_x/includes/testclasses#type=CLAS%2FOLD;name=LTCL_ADD%20%20%20%20%20%20%20%20%20%20%20%20%20%20%20%20%20%20%20%20%20%2`
      && `0ADD_2_3" unit="s"/></testMethods></testClass></testClasses></program></aunit:runResult>`.
    map( EXPORTING iv_xml = lv_xml IMPORTING ev_json = DATA(lv_json) ev_fail = DATA(lv_fail) ev_err = DATA(lv_err) ev_pass = DATA(lv_pass) ).
    cl_abap_unit_assert=>assert_equals( act = lv_pass exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lv_fail + lv_err exp = 0 ).
    cl_abap_unit_assert=>assert_char_cp( act = lv_json exp = `*"methods":[{"name":"ADD_2_3","verdict":"pass","alerts":[]}]*` ).
  ENDMETHOD.

ENDCLASS.

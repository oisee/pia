CLASS zcl_pia_20_b_adt DEFINITION PUBLIC FINAL CREATE PUBLIC.

  " Development backend for a real SAP system: ADT REST on the same system through
  " cl_http_client=>create_internal (current user, no password). Not deployed to OSG:
  " there a nested loopback HTTP call is not allowed and zcl_pia_20_b_osg_store is used.
  " run_tests returns the same JSON shape as OSG STORE RUN_TESTS, so tools see one format.

  PUBLIC SECTION.
    INTERFACES zif_pia_20_dev_backend.
    CLASS-METHODS new RETURNING VALUE(ro_) TYPE REF TO zcl_pia_20_b_adt.

  PRIVATE SECTION.
    DATA mo_http TYPE REF TO if_http_client.
    DATA mv_csrf TYPE string.
    DATA mv_last_error TYPE string.

    METHODS call
      IMPORTING iv_method       TYPE string
                iv_path         TYPE string
                iv_body         TYPE string OPTIONAL
                iv_content_type TYPE string OPTIONAL
                iv_accept       TYPE string OPTIONAL
      EXPORTING ev_status       TYPE i
                ev_body         TYPE string.
    METHODS fetch_csrf.
    METHODS class_url IMPORTING iv_name TYPE string RETURNING VALUE(rv_) TYPE string.
    METHODS lock IMPORTING iv_name TYPE string RETURNING VALUE(rv_) TYPE string.
    METHODS unlock IMPORTING iv_name TYPE string iv_handle TYPE string.
    METHODS xml_text IMPORTING iv_ TYPE string RETURNING VALUE(rv_) TYPE string.
    METHODS issues_json IMPORTING iv_xml TYPE string RETURNING VALUE(rv_) TYPE string.
    METHODS aunit_to_json
      IMPORTING iv_xml  TYPE string
      EXPORTING ev_json TYPE string
                ev_fail TYPE i
                ev_err  TYPE i
                ev_pass TYPE i.

ENDCLASS.

CLASS zcl_pia_20_b_adt IMPLEMENTATION.

  METHOD new.
    ro_ = NEW #( ).
    cl_http_client=>create_internal( IMPORTING client = ro_->mo_http ).
    ro_->mo_http->propertytype_accept_cookie = if_http_client=>co_enabled.
    ro_->mo_http->propertytype_logon_popup = if_http_client=>co_disabled.
  ENDMETHOD.

  METHOD zif_pia_20_dev_backend~get_name.
    rv_ = 'SAP-ADT'.
  ENDMETHOD.

  METHOD fetch_csrf.
    DATA lv_status TYPE i.
    DATA lv_body TYPE string.
    mv_csrf = `Fetch`.
    call( EXPORTING iv_method = `GET` iv_path = `/sap/bc/adt/discovery`
          IMPORTING ev_status = lv_status ev_body = lv_body ).
    mv_csrf = mo_http->response->get_header_field( `x-csrf-token` ).
  ENDMETHOD.

  METHOD call.
    DATA lv_try TYPE i.
    IF mv_csrf IS INITIAL AND iv_method <> `GET`.
      fetch_csrf( ).
    ENDIF.
    DO 2 TIMES.
      lv_try = sy-index.
      mo_http->request->set_method( iv_method ).
      " set the pseudo header directly: with set_request_uri the first POST after the CSRF fetch
      " lost its query string (?_action=LOCK) on A4H and was taken as an object update
      mo_http->request->set_header_field( name = `~request_uri` value = iv_path ).
      mo_http->request->set_header_field( name = `x-csrf-token` value = mv_csrf ).
      mo_http->request->set_header_field( name = `x-sap-adt-sessiontype` value = `stateful` ).
      mo_http->request->set_header_field( name = `Accept`
        value = COND string( WHEN iv_accept IS INITIAL THEN `*/*` ELSE iv_accept ) ).
      IF iv_content_type IS NOT INITIAL.
        mo_http->request->set_header_field( name = `Content-Type` value = iv_content_type ).
      ENDIF.
      mo_http->request->set_cdata( iv_body ).
      mo_http->send( EXCEPTIONS OTHERS = 1 ).
      IF sy-subrc = 0.
        mo_http->receive( EXCEPTIONS OTHERS = 1 ).
      ENDIF.
      IF sy-subrc <> 0.
        mo_http->get_last_error( IMPORTING message = ev_body ).
        ev_status = 0.
        RETURN.
      ENDIF.
      mo_http->response->get_status( IMPORTING code = ev_status ).
      ev_body = mo_http->response->get_cdata( ).
      " expired CSRF token: fetch a new one and retry once
      IF ev_status = 403 AND lv_try = 1 AND iv_method <> `GET`
         AND to_lower( mo_http->response->get_header_field( `x-csrf-token` ) ) = `required`.
        fetch_csrf( ).
        CONTINUE.
      ENDIF.
      EXIT.
    ENDDO.
  ENDMETHOD.

  METHOD class_url.
    rv_ = `/sap/bc/adt/oo/classes/` && to_lower( iv_name ).
  ENDMETHOD.

  METHOD lock.
    DATA lv_status TYPE i.
    DATA lv_body TYPE string.
    DO 2 TIMES.
    call( EXPORTING iv_method = `POST`
                    iv_path   = class_url( iv_name ) && `?_action=LOCK&accessMode=MODIFY`
                    iv_accept = `application/vnd.sap.as+xml;charset=UTF-8;dataname=com.sap.adt.lock.result`
          IMPORTING ev_status = lv_status ev_body = lv_body ).
    FIND FIRST OCCURRENCE OF PCRE `<LOCK_HANDLE>([^<]*)</LOCK_HANDLE>` IN lv_body SUBMATCHES rv_.
    IF rv_ IS NOT INITIAL.
      EXIT.
    ENDIF.
    ENDDO.
    IF rv_ IS INITIAL.
      mv_last_error = |LOCK HTTP { lv_status } { substring( val = xml_text( lv_body ) len = nmin( val1 = 300 val2 = strlen( lv_body ) ) ) }|.
    ENDIF.
  ENDMETHOD.

  METHOD unlock.
    DATA lv_status TYPE i.
    DATA lv_body TYPE string.
    call( EXPORTING iv_method = `POST`
                    iv_path   = class_url( iv_name ) && `?_action=UNLOCK&lockHandle=` && escape( val = iv_handle format = cl_abap_format=>e_url_full )
          IMPORTING ev_status = lv_status ev_body = lv_body ).
  ENDMETHOD.

  METHOD zif_pia_20_dev_backend~get_methods.
    DATA lv_status TYPE i.
    DATA lv_body TYPE string.
    CLEAR: et_methods, ev_error.
    call( EXPORTING iv_method = `GET`
                    iv_path   = class_url( iv_name ) && `/objectstructure?version=inactive&withShortDescriptions=false`
                    iv_accept = `application/vnd.sap.adt.objectstructure.v2+xml`
          IMPORTING ev_status = lv_status ev_body = lv_body ).
    IF lv_status <> 200.
      ev_error = |objectstructure of { iv_name }: HTTP { lv_status }|.
      RETURN.
    ENDIF.
    et_methods = zcl_pia_20_adt_structure=>parse( lv_body ).
  ENDMETHOD.

  METHOD zif_pia_20_dev_backend~read_object.
    DATA lv_status TYPE i.
    DATA(lv_include) = COND string( WHEN iv_include IS INITIAL OR to_lower( iv_include ) = `main` THEN `main` ELSE to_lower( iv_include ) ).
    call( EXPORTING iv_method = `GET`
                    iv_path = COND #( WHEN lv_include = `main` THEN class_url( iv_name ) && `/source/main`
                                      ELSE class_url( iv_name ) && `/includes/` && lv_include )
                    iv_accept = `text/plain`
          IMPORTING ev_status = lv_status ev_body = rs_-source ).
    rs_-ok = xsdbool( lv_status = 200 ).
    IF rs_-ok = abap_true.
      rs_-message = |read { iv_name } { lv_include } ({ strlen( rs_-source ) } chars)|.
    ELSE.
      rs_-message = |read { iv_name } failed: HTTP { lv_status }|.
      CLEAR rs_-source.
    ENDIF.
  ENDMETHOD.

  METHOD zif_pia_20_dev_backend~write_source.
    DATA lv_handle TYPE string.
    DATA lv_status TYPE i.
    DATA lv_body TYPE string.
    DATA lv_path TYPE string.
    DATA lv_include TYPE string.
    DATA lv_create TYPE string.
    lv_include = COND #( WHEN iv_include IS INITIAL THEN `main` ELSE to_lower( iv_include ) ).
    " local packages only for now: a transportable write needs an explicit transport (corrNr)
    DATA lv_devclass TYPE tadir-devclass.
    DATA(lv_obj) = to_upper( iv_name ).
    SELECT SINGLE devclass FROM tadir
      WHERE pgmid = 'R3TR' AND object = 'CLAS' AND obj_name = @lv_obj
      INTO @lv_devclass.
    IF sy-subrc <> 0.
      rs_-message = |{ iv_name } does not exist: creating classes is not supported on SAP yet|.
      RETURN.
    ENDIF.
    IF lv_devclass NP '$*'.
      rs_-message = |{ iv_name } is in transportable package { lv_devclass }: only local ($...) packages are written|.
      RETURN.
    ENDIF.
    lv_handle = lock( iv_name ).
    IF lv_handle IS INITIAL.
      rs_-message = |cannot lock { iv_name }: { mv_last_error }|.
      RETURN.
    ENDIF.
    lv_path = COND #( WHEN lv_include = `main` THEN class_url( iv_name ) && `/source/main`
                      ELSE class_url( iv_name ) && `/includes/` && lv_include ).
    lv_path = lv_path && `?lockHandle=` && escape( val = lv_handle format = cl_abap_format=>e_url_full ).
    call( EXPORTING iv_method = `PUT` iv_path = lv_path iv_body = iv_source
                    iv_content_type = `text/plain; charset=utf-8`
          IMPORTING ev_status = lv_status ev_body = lv_body ).
    IF lv_include <> `main` AND ( lv_status = 404 OR lv_body CS `does not have any inactive version` ).
      " the include does not exist yet (or only its name does, as CCAU after a deploy without tests):
      " create it, then write
      call( EXPORTING iv_method = `POST`
                      iv_path   = class_url( iv_name ) && `/includes?lockHandle=` && escape( val = lv_handle format = cl_abap_format=>e_url_full )
                      iv_content_type = `application/vnd.sap.adt.oo.classincludes+xml`
                      iv_body   = `<?xml version="1.0" encoding="UTF-8"?><class:abapClassInclude xmlns:class="http://www.sap.com/adt/oo/classes" `
                               && `xmlns:adtcore="http://www.sap.com/adt/core" adtcore:name="dummy" class:includeType="` && lv_include && `"/>`
            IMPORTING ev_status = lv_status ev_body = lv_body ).
      lv_create = |create include: HTTP { lv_status } { substring( val = xml_text( lv_body ) len = nmin( val1 = 300 val2 = strlen( lv_body ) ) ) }|.
      call( EXPORTING iv_method = `PUT` iv_path = lv_path iv_body = iv_source
                      iv_content_type = `text/plain; charset=utf-8`
            IMPORTING ev_status = lv_status ev_body = lv_body ).
    ENDIF.
    unlock( iv_name = iv_name iv_handle = lv_handle ).
    rs_-ok = xsdbool( lv_status = 200 OR lv_status = 204 ).
    IF rs_-ok = abap_true.
      rs_-message = |written { iv_name } { lv_include } ({ strlen( iv_source ) } chars)|.
    ELSE.
      rs_-message = |write { iv_name } { lv_include } failed: HTTP { lv_status } { xml_text( lv_body ) } { lv_create }|.
    ENDIF.
  ENDMETHOD.

  METHOD zif_pia_20_dev_backend~activate.
    DATA lv_status TYPE i.
    DATA lv_body TYPE string.
    call( EXPORTING iv_method = `POST`
                    iv_path   = `/sap/bc/adt/activation?method=activate&preauditRequested=true`
                    iv_content_type = `application/xml`
                    iv_accept = `application/xml`
                    iv_body   = `<?xml version="1.0" encoding="UTF-8"?><adtcore:objectReferences xmlns:adtcore="http://www.sap.com/adt/core">`
                             && `<adtcore:objectReference adtcore:uri="` && class_url( iv_name ) && `" adtcore:name="` && to_upper( iv_name ) && `"/>`
                             && `</adtcore:objectReferences>`
          IMPORTING ev_status = lv_status ev_body = lv_body ).
    rs_-issues = issues_json( lv_body ).
    " SAP activates synchronously: no op_id, no generation; success is published at once
    " no error messages = success; activationExecuted="false" without messages means nothing was inactive
    IF lv_status = 200 AND rs_-issues = `[]`.
      rs_-ok = abap_true.
      rs_-state = `published`.
    ELSE.
      rs_-ok = abap_false.
      rs_-state = `failed`.
      rs_-failure_stage = `validation`.
      IF rs_-issues = `[]`.
        rs_-issues = |[\{"MESSAGE":"{ zcl_pia_00_json_util=>escape( |HTTP { lv_status } { xml_text( lv_body ) }| ) }"\}]|.
      ENDIF.
    ENDIF.
  ENDMETHOD.

  METHOD zif_pia_20_dev_backend~get_activation_status.
    " synchronous activation: nothing is ever pending on SAP
    rs_-op_id = iv_op_id.
    rs_-state = `published`.
    rs_-ok = abap_true.
  ENDMETHOD.

  METHOD issues_json.
    " chkl:messages -> [{"LINE":..,"MESSAGE":..}] for errors (type E)
    DATA lt_msg TYPE string_table.
    DATA lt TYPE string_table.
    DATA lv_line TYPE string.
    DATA lv_text TYPE string.
    SPLIT iv_xml AT `<msg ` INTO TABLE lt_msg.
    LOOP AT lt_msg INTO DATA(lv_m) FROM 2.
      IF lv_m NP `*type="E"*`.
        CONTINUE.
      ENDIF.
      CLEAR: lv_line, lv_text.
      FIND FIRST OCCURRENCE OF PCRE `#start=(\d+)` IN lv_m SUBMATCHES lv_line.
      FIND FIRST OCCURRENCE OF PCRE `<txt>([^<]*)</txt>` IN lv_m SUBMATCHES lv_text.
      APPEND |\{"LINE":"{ lv_line }","MESSAGE":"{ zcl_pia_00_json_util=>escape( xml_text( lv_text ) ) }"\}| TO lt.
    ENDLOOP.
    rv_ = `[` && concat_lines_of( table = lt sep = `,` ) && `]`.
  ENDMETHOD.

  METHOD zif_pia_20_dev_backend~run_tests.
    DATA lv_refs TYPE string.
    DATA lv_status TYPE i.
    DATA lv_body TYPE string.
    DATA lv_fail TYPE i.
    DATA lv_err TYPE i.
    DATA lv_pass TYPE i.
    LOOP AT it_classes INTO DATA(lv_cls).
      lv_refs = lv_refs && `<adtcore:objectReference adtcore:uri="` && class_url( lv_cls ) && `"/>`.
    ENDLOOP.
    call( EXPORTING iv_method = `POST` iv_path = `/sap/bc/adt/abapunit/testruns`
                    iv_content_type = `application/xml` iv_accept = `application/xml`
                    iv_body = `<?xml version="1.0" encoding="UTF-8"?><aunit:runConfiguration xmlns:aunit="http://www.sap.com/adt/aunit">`
                           && `<external><coverage active="false"/></external><options><uriType value="semantic"/>`
                           && `<testDeterminationStrategy sameProgram="true" assignedTests="false" appendAssignedTestsPreview="true"/>`
                           && `<testRiskLevels harmless="true" dangerous="true" critical="true"/><testDurations short="true" medium="true" long="true"/>`
                           && `<withNavigationUri enabled="false"/></options><adtcore:objectSets xmlns:adtcore="http://www.sap.com/adt/core">`
                           && `<objectSet kind="inclusive"><adtcore:objectReferences>` && lv_refs
                           && `</adtcore:objectReferences></objectSet></adtcore:objectSets></aunit:runConfiguration>`
          IMPORTING ev_status = lv_status ev_body = lv_body ).
    IF lv_status <> 200.
      rs_-message = |run_tests failed: HTTP { lv_status }|.
      rs_-source = |\{"state":"failed","failure_stage":"runner","error":\{"code":"HTTP_{ lv_status }","text":"{ zcl_pia_00_json_util=>escape( xml_text( lv_body ) ) }"\}\}|.
      RETURN.
    ENDIF.
    aunit_to_json( EXPORTING iv_xml = lv_body
                   IMPORTING ev_json = rs_-source ev_fail = lv_fail ev_err = lv_err ev_pass = lv_pass ).
    rs_-ok = xsdbool( lv_fail = 0 AND lv_err = 0 ).
    rs_-message = |tests ran: pass { lv_pass } fail { lv_fail } error { lv_err }|.
  ENDMETHOD.

  METHOD aunit_to_json.
    " aunit:runResult -> {"state":"ran","counts":{..},"classes":[{"name","state","methods":[{"name","verdict","alerts":[..]}]}]}
    DATA lt_cls TYPE string_table.
    DATA lt_mth TYPE string_table.
    DATA lt_cj TYPE string_table.
    DATA lt_mj TYPE string_table.
    DATA lt_aj TYPE string_table.
    DATA lt_det TYPE string_table.
    DATA lt_dj TYPE string_table.
    DATA lv_name TYPE string.
    DATA lv_kind TYPE string.
    DATA lv_sev TYPE string.
    DATA lv_title TYPE string.
    DATA lv_exp TYPE string.
    DATA lv_act TYPE string.
    DATA lv_line TYPE string.
    DATA lv_verdict TYPE string.
    DATA lv_methods TYPE i.
    SPLIT iv_xml AT `<testClass ` INTO TABLE lt_cls.
    LOOP AT lt_cls INTO DATA(lv_c) FROM 2.
      CLEAR: lv_name, lt_mj.
      FIND FIRST OCCURRENCE OF PCRE `adtcore:name="([^"]*)"` IN lv_c SUBMATCHES lv_name.
      SPLIT lv_c AT `<testMethod ` INTO TABLE lt_mth.
      LOOP AT lt_mth INTO DATA(lv_m) FROM 2.
        CLEAR: lt_aj, lv_verdict.
        DATA(lv_mname) = ``.
        FIND FIRST OCCURRENCE OF PCRE `adtcore:name="([^"]*)"` IN lv_m SUBMATCHES lv_mname.
        lv_verdict = `pass`.
        SPLIT lv_m AT `<alert ` INTO TABLE lt_det.
        LOOP AT lt_det INTO DATA(lv_a) FROM 2.
          CLEAR: lv_kind, lv_sev, lv_title, lv_exp, lv_act, lv_line.
          FIND FIRST OCCURRENCE OF PCRE `kind="([^"]*)"` IN lv_a SUBMATCHES lv_kind.
          FIND FIRST OCCURRENCE OF PCRE `severity="([^"]*)"` IN lv_a SUBMATCHES lv_sev.
          FIND FIRST OCCURRENCE OF PCRE `<title>([^<]*)</title>` IN lv_a SUBMATCHES lv_title.
          " details as written by the runner, kept verbatim for the model
          CLEAR lt_dj.
          FIND ALL OCCURRENCES OF PCRE `<detail[^>]*\btext="([^"]*)"` IN lv_a RESULTS DATA(lt_hits).
          LOOP AT lt_hits INTO DATA(ls_hit).
            READ TABLE ls_hit-submatches INDEX 1 INTO DATA(ls_sub).
            DATA(lv_det) = xml_text( substring( val = lv_a off = ls_sub-offset len = ls_sub-length ) ).
            APPEND |"{ zcl_pia_00_json_util=>escape( lv_det ) }"| TO lt_dj.
            FIND FIRST OCCURRENCE OF PCRE `Expected[^\[<]*[\[<]([^\]>]*)[\]>]` IN lv_det SUBMATCHES lv_exp.
            FIND FIRST OCCURRENCE OF PCRE `Actual[^\[<]*[\[<]([^\]>]*)[\]>]` IN lv_det SUBMATCHES lv_act.
          ENDLOOP.
          IF lt_dj IS INITIAL.
            " unknown layout: hand the raw alert (tags removed) to the model rather than nothing
            DATA(lv_raw) = lv_a.
            APPEND |"{ zcl_pia_00_json_util=>escape( xml_text( substring( val = lv_raw len = nmin( val1 = 500 val2 = strlen( lv_raw ) ) ) ) ) }"| TO lt_dj.
          ENDIF.
          FIND FIRST OCCURRENCE OF PCRE `Line:?\s*(?:&lt;)?(\d+)` IN lv_a SUBMATCHES lv_line.
          IF lv_sev = `tolerable`.
            CONTINUE. " warnings do not fail a test
          ENDIF.
          IF lv_kind = `failedAssertion`.
            IF lv_verdict = `pass`. lv_verdict = `fail`. ENDIF.
          ELSE.
            lv_verdict = `error`.
          ENDIF.
          APPEND |\{"kind":"{ lv_kind }","title":"{ zcl_pia_00_json_util=>escape( xml_text( lv_title ) ) }",|
              && |"expected":"{ zcl_pia_00_json_util=>escape( xml_text( lv_exp ) ) }",|
              && |"actual":"{ zcl_pia_00_json_util=>escape( xml_text( lv_act ) ) }",|
              && |"line":{ COND string( WHEN lv_line IS INITIAL THEN `null` ELSE lv_line ) },|
              && |"details":[{ concat_lines_of( table = lt_dj sep = `,` ) }]\}| TO lt_aj.
        ENDLOOP.
        lv_methods = lv_methods + 1.
        CASE lv_verdict.
          WHEN `pass`. ev_pass = ev_pass + 1.
          WHEN `fail`. ev_fail = ev_fail + 1.
          WHEN OTHERS. ev_err = ev_err + 1.
        ENDCASE.
        APPEND |\{"name":"{ lv_mname }","verdict":"{ lv_verdict }","alerts":[{ concat_lines_of( table = lt_aj sep = `,` ) }]\}| TO lt_mj.
      ENDLOOP.
      APPEND |\{"name":"{ lv_name }","state":"ok","methods":[{ concat_lines_of( table = lt_mj sep = `,` ) }]\}| TO lt_cj.
    ENDLOOP.
    ev_json = |\{"state":"ran","counts":\{"classes":{ lines( lt_cj ) },"methods":{ lv_methods },|
           && |"pass":{ ev_pass },"fail":{ ev_fail },"error":{ ev_err },"skipped":0\},|
           && |"classes":[{ concat_lines_of( table = lt_cj sep = `,` ) }]\}|.
  ENDMETHOD.

  METHOD xml_text.
    rv_ = iv_.
    REPLACE ALL OCCURRENCES OF `&lt;` IN rv_ WITH `<`.
    REPLACE ALL OCCURRENCES OF `&gt;` IN rv_ WITH `>`.
    REPLACE ALL OCCURRENCES OF `&quot;` IN rv_ WITH `"`.
    REPLACE ALL OCCURRENCES OF `&apos;` IN rv_ WITH `'`.
    REPLACE ALL OCCURRENCES OF `&amp;` IN rv_ WITH `&`.
  ENDMETHOD.

ENDCLASS.

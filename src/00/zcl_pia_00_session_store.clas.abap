CLASS zcl_pia_00_session_store DEFINITION PUBLIC FINAL CREATE PUBLIC.

  " Persistent conversations and pending tasks, as files beside pia.env (OPEN DATASET):
  " SAP: DIR_HOME of the instance; OSG: OSD_DATASET_HOME (must also be a write root).
  " A session file holds one message per line: role TAB escaped content (escape() leaves no newlines).

  PUBLIC SECTION.
    CLASS-METHODS load
      IMPORTING iv_sid     TYPE string
      RETURNING VALUE(ro_) TYPE REF TO zcl_pia_00_session.
    CLASS-METHODS save
      IMPORTING iv_sid     TYPE string
                io_session TYPE REF TO zcl_pia_00_session.
    CLASS-METHODS put_task
      IMPORTING iv_sid  TYPE string
                iv_task TYPE string.
    " returns the pending task and removes it
    CLASS-METHODS take_task
      IMPORTING iv_sid     TYPE string
      RETURNING VALUE(rv_) TYPE string.
    " letters, digits, '-' and '_' only, so a sid can name a file and a job
    CLASS-METHODS is_valid_sid
      IMPORTING iv_sid     TYPE string
      RETURNING VALUE(rv_) TYPE abap_bool.

    " plain text files beside pia.env (also used for LLM record/replay)
    CLASS-METHODS write_lines IMPORTING iv_file TYPE string it_ TYPE string_table.
    CLASS-METHODS read_lines IMPORTING iv_file TYPE string RETURNING VALUE(rt_) TYPE string_table.
    CLASS-METHODS append_line IMPORTING iv_file TYPE string iv_line TYPE string.

ENDCLASS.

CLASS zcl_pia_00_session_store IMPLEMENTATION.

  METHOD is_valid_sid.
    rv_ = xsdbool( iv_sid IS NOT INITIAL AND strlen( iv_sid ) <= 26 AND iv_sid CO `ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_` ).
  ENDMETHOD.

  METHOD load.
    DATA lt_msg TYPE zif_pia_00_llm=>tt_messages.
    DATA lv_role TYPE string.
    DATA lv_text TYPE string.
    ro_ = zcl_pia_00_session=>new( iv_sid ).
    IF is_valid_sid( iv_sid ) = abap_false.
      RETURN.
    ENDIF.
    LOOP AT read_lines( |pia-session-{ iv_sid }.txt| ) INTO DATA(lv_line).
      SPLIT lv_line AT cl_abap_char_utilities=>horizontal_tab INTO lv_role lv_text.
      IF lv_role IS NOT INITIAL.
        APPEND VALUE #( role = lv_role content = zcl_pia_00_json_util=>unescape( lv_text ) ) TO lt_msg.
      ENDIF.
    ENDLOOP.
    ro_->replace_messages( lt_msg ).
  ENDMETHOD.

  METHOD save.
    DATA lt TYPE string_table.
    IF is_valid_sid( iv_sid ) = abap_false.
      RETURN.
    ENDIF.
    LOOP AT io_session->get_messages( ) INTO DATA(ls_m).
      APPEND ls_m-role && cl_abap_char_utilities=>horizontal_tab && zcl_pia_00_json_util=>escape( ls_m-content ) TO lt.
    ENDLOOP.
    write_lines( iv_file = |pia-session-{ iv_sid }.txt| it_ = lt ).
  ENDMETHOD.

  METHOD put_task.
    DATA lt TYPE string_table.
    IF is_valid_sid( iv_sid ) = abap_false.
      RETURN.
    ENDIF.
    APPEND zcl_pia_00_json_util=>escape( iv_task ) TO lt.
    write_lines( iv_file = |pia-task-{ iv_sid }.txt| it_ = lt ).
  ENDMETHOD.

  METHOD take_task.
    DATA lt TYPE string_table.
    IF is_valid_sid( iv_sid ) = abap_false.
      RETURN.
    ENDIF.
    lt = read_lines( |pia-task-{ iv_sid }.txt| ).
    READ TABLE lt INDEX 1 INTO DATA(lv_line).
    IF sy-subrc = 0.
      rv_ = zcl_pia_00_json_util=>unescape( lv_line ).
    ENDIF.
    DATA(lv_file) = |pia-task-{ iv_sid }.txt|.
    TRY.
        DELETE DATASET lv_file.
      CATCH cx_root.
        write_lines( iv_file = lv_file it_ = VALUE #( ) ).
    ENDTRY.
  ENDMETHOD.

  METHOD write_lines.
    TRY.
        OPEN DATASET iv_file FOR OUTPUT IN TEXT MODE ENCODING UTF-8.
        IF sy-subrc <> 0.
          RETURN.
        ENDIF.
        LOOP AT it_ INTO DATA(lv_line).
          TRANSFER lv_line TO iv_file.
        ENDLOOP.
        CLOSE DATASET iv_file.
      CATCH cx_root.
        RETURN.
    ENDTRY.
  ENDMETHOD.

  METHOD read_lines.
    DATA lv_line TYPE string.
    TRY.
        OPEN DATASET iv_file FOR INPUT IN TEXT MODE ENCODING UTF-8.
        IF sy-subrc <> 0.
          RETURN.
        ENDIF.
        DO.
          READ DATASET iv_file INTO lv_line.
          IF sy-subrc <> 0.
            EXIT.
          ENDIF.
          APPEND lv_line TO rt_.
        ENDDO.
        CLOSE DATASET iv_file.
      CATCH cx_root.
        RETURN.
    ENDTRY.
  ENDMETHOD.

  METHOD append_line.
    TRY.
        OPEN DATASET iv_file FOR APPENDING IN TEXT MODE ENCODING UTF-8.
        IF sy-subrc <> 0.
          RETURN.
        ENDIF.
        TRANSFER iv_line TO iv_file.
        CLOSE DATASET iv_file.
      CATCH cx_root.
        RETURN.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.

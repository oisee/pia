CLASS zcl_pia_00_config DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    " NAME=value lines; never committed. OSG: dir in OSD_DATASET_READ / OSD_DATASET_HOME.
    " SAP: application server file (DIR_HOME or full path).
    CONSTANTS c_file TYPE string VALUE `pia.env`.
    " settings without secrets (PIA_LLM, PIA_MODEL, PIA_TURN_MODE); read when pia.env has no value
    CONSTANTS c_settings TYPE string VALUE `pia-settings.env`.

    CLASS-METHODS get
      IMPORTING iv_name    TYPE string
      RETURNING VALUE(rv_) TYPE string.

    " PIA_MODEL from pia.env, default glm-5.3 (glm-5.3-flash wrote invalid ABAP and empty tool args)
    CLASS-METHODS model
      RETURNING VALUE(rv_) TYPE string.

    CLASS-METHODS llm_config
      RETURNING VALUE(rs_) TYPE zif_pia_00_llm=>ts_config.

  PRIVATE SECTION.
    CLASS-METHODS get_from
      IMPORTING iv_file    TYPE string
                iv_name    TYPE string
                iv_missing TYPE string DEFAULT ``
      RETURNING VALUE(rv_) TYPE string.

    " value part of a NAME=value line (pure helper, for unit tests)
    CLASS-METHODS value_of_line
      IMPORTING iv_line    TYPE string
      RETURNING VALUE(rv_) TYPE string.

ENDCLASS.

CLASS zcl_pia_00_config IMPLEMENTATION.

  METHOD llm_config.
    rs_-base_url = get( `PIA_BASE_URL` ).
    IF rs_-base_url IS INITIAL.
      rs_-base_url = `https://api.z.ai/api/v1/responses`.
    ENDIF.
    rs_-api_type = get( `PIA_API_TYPE` ).
    IF rs_-api_type IS INITIAL.
      rs_-api_type = `responses`.
    ENDIF.
    rs_-model = model( ).
    " Explicit empty PIA_API_KEY disables authentication, even when a legacy key exists.
    rs_-api_key = get_from( iv_file = c_file iv_name = `PIA_API_KEY` iv_missing = `#PIA_UNSET#` ).
    IF rs_-api_key = `#PIA_UNSET#`.
      rs_-api_key = get_from( iv_file = c_settings iv_name = `PIA_API_KEY` iv_missing = `#PIA_UNSET#` ).
    ENDIF.
    IF rs_-api_key = `#PIA_UNSET#`.
      rs_-api_key = get( `ZAI_API_KEY` ).
    ENDIF.
    rs_-temperature = get( `PIA_TEMPERATURE` ).
    rs_-max_tokens = get( `PIA_MAX_TOKENS` ).
  ENDMETHOD.

  METHOD model.
    rv_ = get( `PIA_MODEL` ).
    IF rv_ IS INITIAL.
      rv_ = `glm-5.3`.
    ENDIF.
  ENDMETHOD.

  METHOD get.
    rv_ = get_from( iv_file = c_file iv_name = iv_name ).
    IF rv_ IS INITIAL.
      rv_ = get_from( iv_file = c_settings iv_name = iv_name ).
    ENDIF.
  ENDMETHOD.

  METHOD get_from.
    rv_ = iv_missing.
    DATA lv_line TYPE string.
    DATA lv_key TYPE string.
    DATA lv_off TYPE i.

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
          CLEAR lv_off.
          FIND FIRST OCCURRENCE OF `=` IN lv_line MATCH OFFSET lv_off.
          IF sy-subrc <> 0.
            CONTINUE.
          ENDIF.
          lv_key = substring( val = lv_line len = lv_off ).
          IF lv_key = iv_name.
            rv_ = value_of_line( lv_line ).
            EXIT.
          ENDIF.
        ENDDO.
        CLOSE DATASET iv_file.
      CATCH cx_root.
        rv_ = iv_missing.
    ENDTRY.
  ENDMETHOD.

  METHOD value_of_line.
    " value part of a NAME=value line: cut everything from the first ' #'
    " (inline comment) and trim blanks; secrets with '=' are unaffected
    DATA lv_off TYPE i.
    FIND FIRST OCCURRENCE OF `=` IN iv_line MATCH OFFSET lv_off.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    rv_ = substring( val = iv_line off = lv_off + 1 ).
    FIND FIRST OCCURRENCE OF ` #` IN rv_ MATCH OFFSET lv_off.
    IF sy-subrc = 0.
      rv_ = substring( val = rv_ len = lv_off ).
    ENDIF.
    rv_ = condense( rv_ ).
  ENDMETHOD.

ENDCLASS.

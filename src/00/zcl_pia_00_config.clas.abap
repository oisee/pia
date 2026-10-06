CLASS zcl_pia_00_config DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    " NAME=value lines; never committed. OSG: dir in OSD_DATASET_READ / OSD_DATASET_HOME.
    " SAP: application server file (DIR_HOME or full path).
    CONSTANTS c_file TYPE string VALUE `pia.env`.

    CLASS-METHODS get
      IMPORTING iv_name    TYPE string
      RETURNING VALUE(rv_) TYPE string.

    " PIA_MODEL from pia.env, default glm-5.3 (glm-5.3-flash wrote invalid ABAP and empty tool args)
    CLASS-METHODS model
      RETURNING VALUE(rv_) TYPE string.

ENDCLASS.

CLASS zcl_pia_00_config IMPLEMENTATION.

  METHOD model.
    rv_ = get( `PIA_MODEL` ).
    IF rv_ IS INITIAL.
      rv_ = `glm-5.3`.
    ENDIF.
  ENDMETHOD.

  METHOD get.
    DATA lv_line TYPE string.
    DATA lv_key TYPE string.
    DATA lv_off TYPE i.
    DATA lv_from TYPE i.

    TRY.
        OPEN DATASET c_file FOR INPUT IN TEXT MODE ENCODING UTF-8.
        IF sy-subrc <> 0.
          RETURN.
        ENDIF.
        DO.
          READ DATASET c_file INTO lv_line.
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
            lv_from = lv_off + 1.
            rv_ = substring( val = lv_line off = lv_from ).
            EXIT.
          ENDIF.
        ENDDO.
        CLOSE DATASET c_file.
      CATCH cx_root.
        CLEAR rv_.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.

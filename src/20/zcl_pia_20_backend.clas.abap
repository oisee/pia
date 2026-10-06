CLASS zcl_pia_20_backend DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    " OSG (ZCL_OSD_ADT_HOST present): STORE backend; real SAP: ADT over internal HTTP.
    " Both are created dynamically, so each system only needs the backend it runs.
    CLASS-METHODS default
      RETURNING VALUE(ro_) TYPE REF TO zif_pia_20_dev_backend.

ENDCLASS.

CLASS zcl_pia_20_backend IMPLEMENTATION.

  METHOD default.
    DATA lv_class TYPE string.
    cl_abap_typedescr=>describe_by_name( EXPORTING p_name = 'ZCL_OSD_ADT_HOST' EXCEPTIONS type_not_found = 1 OTHERS = 2 ).
    lv_class = COND #( WHEN sy-subrc = 0 THEN `ZCL_PIA_20_B_OSG_STORE` ELSE `ZCL_PIA_20_B_ADT` ).
    CALL METHOD (lv_class)=>new RECEIVING ro_ = ro_.
  ENDMETHOD.

ENDCLASS.

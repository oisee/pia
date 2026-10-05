INTERFACE zif_pia_00_tool PUBLIC.

  TYPES: BEGIN OF ts_param,
           name     TYPE string,
           type     TYPE string,
           desc     TYPE string,
           required TYPE abap_bool,
         END OF ts_param.
  TYPES tt_params TYPE STANDARD TABLE OF ts_param WITH EMPTY KEY.

  TYPES: BEGIN OF ts_call,
           id        TYPE string,
           name      TYPE string,
           arguments TYPE string,
         END OF ts_call.
  TYPES tt_calls TYPE STANDARD TABLE OF ts_call WITH EMPTY KEY.

  TYPES: BEGIN OF ts_result,
           call_id TYPE string,
           ok      TYPE abap_bool,
           output  TYPE string,
         END OF ts_result.

  CONSTANTS: c_perm_read  TYPE string VALUE 'READ',
             c_perm_write TYPE string VALUE 'WRITE',
             c_perm_exec  TYPE string VALUE 'EXECUTE'.

  METHODS get_name        RETURNING VALUE(rv_) TYPE string.
  METHODS get_description RETURNING VALUE(rv_) TYPE string.
  METHODS get_params      RETURNING VALUE(rt_) TYPE tt_params.
  METHODS get_permission  RETURNING VALUE(rv_) TYPE string.
  METHODS invoke
    IMPORTING iv_arguments TYPE string
              iv_call_id   TYPE string OPTIONAL
    RETURNING VALUE(rs_)   TYPE ts_result.

ENDINTERFACE.

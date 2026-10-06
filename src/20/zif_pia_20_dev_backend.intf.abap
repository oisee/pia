INTERFACE zif_pia_20_dev_backend PUBLIC.

  TYPES: BEGIN OF ts_result,
           ok      TYPE abap_bool,
           message TYPE string,
           source  TYPE string,
         END OF ts_result.

  TYPES: BEGIN OF ts_activation,
           state         TYPE string,   " checked|pending|published|failed
           op_id         TYPE string,
           generation_id TYPE string,
           issues        TYPE string,   " JSON array
           failure_stage TYPE string,   " validation|step|build|promotion|revision|recovery
           ok            TYPE abap_bool,
         END OF ts_activation.

  METHODS read_object
    IMPORTING iv_name    TYPE string
    RETURNING VALUE(rs_) TYPE ts_result.

  METHODS write_source
    IMPORTING iv_name    TYPE string
              iv_source  TYPE string
              iv_include TYPE string OPTIONAL   " '' = main, 'testclasses' = local tests
    RETURNING VALUE(rs_) TYPE ts_result.

  " ok = ran with no fail/error; message = one-line summary; source = raw result JSON
  METHODS run_tests
    IMPORTING it_classes             TYPE string_table
              iv_expected_generation TYPE string OPTIONAL
    RETURNING VALUE(rs_)             TYPE ts_result.

  METHODS activate
    IMPORTING iv_name    TYPE string
    RETURNING VALUE(rs_) TYPE ts_activation.

  METHODS get_activation_status
    IMPORTING iv_op_id   TYPE string
    RETURNING VALUE(rs_) TYPE ts_activation.

  METHODS get_name RETURNING VALUE(rv_) TYPE string.

ENDINTERFACE.

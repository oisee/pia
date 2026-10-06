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
           ok            TYPE abap_bool,
         END OF ts_activation.

  METHODS read_object
    IMPORTING iv_name    TYPE string
    RETURNING VALUE(rs_) TYPE ts_result.

  METHODS write_source
    IMPORTING iv_name    TYPE string
                iv_source TYPE string
    RETURNING VALUE(rs_) TYPE ts_result.

  METHODS activate
    IMPORTING iv_name    TYPE string
    RETURNING VALUE(rs_) TYPE ts_activation.

  METHODS get_activation_status
    IMPORTING iv_op_id   TYPE string
    RETURNING VALUE(rs_) TYPE ts_activation.

  METHODS get_name RETURNING VALUE(rv_) TYPE string.

ENDINTERFACE.

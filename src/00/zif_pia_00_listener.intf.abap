INTERFACE zif_pia_00_listener PUBLIC.

  METHODS on_event
    IMPORTING iv_type TYPE string
              iv_data TYPE string.

ENDINTERFACE.

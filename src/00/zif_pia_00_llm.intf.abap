INTERFACE zif_pia_00_llm PUBLIC.

  TYPES: BEGIN OF ts_config,
           base_url TYPE string,
           model    TYPE string,
           api_key  TYPE string,
           api_type TYPE string, " 'chat' | 'responses'
         END OF ts_config.

  " conversation messages; owned here so the interface does not depend on the session
  TYPES: BEGIN OF ts_message,
           role    TYPE string,
           content TYPE string,
         END OF ts_message.
  TYPES tt_messages TYPE STANDARD TABLE OF ts_message WITH EMPTY KEY.

  " Нормализованный вызов: адаптер парсит свой формат, executor не знает wire
  METHODS chat
    IMPORTING
      it_messages   TYPE tt_messages
      iv_tools_json TYPE string OPTIONAL
    EXPORTING
      et_calls      TYPE zif_pia_00_tool=>tt_calls
      ev_answer     TYPE string
      ev_assistant_raw TYPE string  " replayable JSON (конвенция session)
      ev_body       TYPE string
      ev_status     TYPE i
      ev_error      TYPE string.

ENDINTERFACE.

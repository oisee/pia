CLASS zcl_pia_20_adt_structure DEFINITION PUBLIC FINAL CREATE PUBLIC.

  " The method ranges of a class as the system reports them: the ADT objectstructure document
  " (GET /sap/bc/adt/oo/classes/<name>/objectstructure, the same on SAP and in open-steamgate's ADT facade),
  " read with sXML. PIA does not parse ABAP itself: each method's definitionBlock and implementationBlock
  " links carry the include and the line range (#start=line,col;end=line,col).
  PUBLIC SECTION.
    TYPES: BEGIN OF ts_span,
             method    TYPE string,
             owner     TYPE string,   " the class or local test class the method belongs to
             include   TYPE string,   " main | testclasses (of the implementation)
             def_from  TYPE i,
             def_to    TYPE i,
             impl_from TYPE i,
             impl_to   TYPE i,
           END OF ts_span.
    TYPES tt_span TYPE STANDARD TABLE OF ts_span WITH EMPTY KEY.

    CLASS-METHODS parse IMPORTING iv_xml TYPE string RETURNING VALUE(rt_) TYPE tt_span.
    " the same tree as JSON: open-steamgate's STORE PARSE OUTLINE (what its ADT objectstructure is built from)
    CLASS-METHODS parse_outline_json IMPORTING iv_json TYPE string RETURNING VALUE(rt_) TYPE tt_span.

  PRIVATE SECTION.
    " include and lines of an ADT source link such as ./includes/testclasses#start=7,2;end=9,11
    CLASS-METHODS range
      IMPORTING iv_href    TYPE string
      EXPORTING ev_include TYPE string
                ev_from    TYPE i
                ev_to      TYPE i.

ENDCLASS.

CLASS zcl_pia_20_adt_structure IMPLEMENTATION.

  METHOD parse_outline_json.
    " sXML reads JSON as object/array/str elements whose name attribute is the key
    TYPES: BEGIN OF ts_obj,
             type TYPE string,
             name TYPE string,
             rel  TYPE string,
             href TYPE string,
             span TYPE ts_span,
           END OF ts_obj.
    DATA lt_stack TYPE STANDARD TABLE OF ts_obj WITH EMPTY KEY.
    DATA lt_elems TYPE string_table.   " open element names: a close node need not carry its name
    DATA lv_key TYPE string.
    DATA lv_depth TYPE i.
    DATA(lo_reader) = cl_sxml_string_reader=>create( cl_abap_codepage=>convert_to( iv_json ) ).
    DO.
      DATA(lo_node) = lo_reader->read_next_node( ).
      IF lo_node IS INITIAL.
        EXIT.
      ENDIF.
      CASE lo_node->type.
        WHEN if_sxml_node=>co_nt_element_open.
          DATA(lo_open) = CAST if_sxml_open_element( lo_node ).
          CLEAR lv_key.
          LOOP AT lo_open->get_attributes( ) INTO DATA(lo_attr).
            IF lo_attr->qname-name = 'name'.
              lv_key = lo_attr->get_value( ).
            ENDIF.
          ENDLOOP.
          APPEND lo_open->qname-name TO lt_elems.
          IF lo_open->qname-name = 'object'.
            APPEND INITIAL LINE TO lt_stack.
          ENDIF.
        WHEN if_sxml_node=>co_nt_value.
          lv_depth = lines( lt_stack ).
          IF lv_depth > 0.
            DATA(lv_value) = CAST if_sxml_value_node( lo_node )->get_value( ).
            CASE lv_key.
              WHEN 'type'. lt_stack[ lv_depth ]-type = lv_value.
              WHEN 'name'. lt_stack[ lv_depth ]-name = lv_value.
              WHEN 'rel'. lt_stack[ lv_depth ]-rel = lv_value.
              WHEN 'href'. lt_stack[ lv_depth ]-href = lv_value.
            ENDCASE.
          ENDIF.
        WHEN if_sxml_node=>co_nt_element_close.
          DATA(lv_closed) = ``.
          IF lt_elems IS NOT INITIAL.
            lv_closed = lt_elems[ lines( lt_elems ) ].
            DELETE lt_elems INDEX lines( lt_elems ).
          ENDIF.
          IF lv_closed <> 'object'.
            CONTINUE.
          ENDIF.
          lv_depth = lines( lt_stack ).
          IF lv_depth = 0.
            CONTINUE.
          ENDIF.
          DATA(ls_obj) = lt_stack[ lv_depth ].
          DELETE lt_stack INDEX lv_depth.
          IF ls_obj-rel IS NOT INITIAL.
            " a link: belongs to the method that holds the links array
            DATA(lv_m) = lines( lt_stack ).
            IF lv_m > 0.
              IF ls_obj-rel CP '*implementationBlock'.
                range( EXPORTING iv_href = ls_obj-href IMPORTING ev_include = lt_stack[ lv_m ]-span-include
                                 ev_from = lt_stack[ lv_m ]-span-impl_from ev_to = lt_stack[ lv_m ]-span-impl_to ).
              ELSEIF ls_obj-rel CP '*definitionBlock'.
                range( EXPORTING iv_href = ls_obj-href
                       IMPORTING ev_from = lt_stack[ lv_m ]-span-def_from ev_to = lt_stack[ lv_m ]-span-def_to ).
              ENDIF.
            ENDIF.
          ELSEIF ls_obj-type = 'CLAS/OM' OR ls_obj-type = 'CLAS/OLD'.
            DATA(ls_span) = ls_obj-span.
            ls_span-method = to_upper( ls_obj-name ).
            LOOP AT lt_stack INTO DATA(ls_parent) WHERE name IS NOT INITIAL.
              ls_span-owner = to_upper( ls_parent-name ).
            ENDLOOP.
            APPEND ls_span TO rt_.
          ENDIF.
      ENDCASE.
    ENDDO.
  ENDMETHOD.

  METHOD range.
    CLEAR: ev_include, ev_from, ev_to.
    ev_include = COND #( WHEN iv_href CS 'includes/testclasses' THEN `testclasses` ELSE `main` ).
    DATA lv_from TYPE string.
    DATA lv_to TYPE string.
    FIND FIRST OCCURRENCE OF PCRE `start=(\d+),\d+;end=(\d+)` IN iv_href SUBMATCHES lv_from lv_to.
    IF sy-subrc = 0.
      ev_from = lv_from.
      ev_to = lv_to.
    ENDIF.
  ENDMETHOD.

  METHOD parse.
    TYPES: BEGIN OF ts_elem,
             type TYPE string,
             name TYPE string,
           END OF ts_elem.
    DATA lt_stack TYPE STANDARD TABLE OF ts_elem WITH EMPTY KEY.
    DATA lt_elems TYPE string_table.   " open element names: a close node need not carry its name
    DATA ls_span TYPE ts_span.
    DATA lv_in_method TYPE abap_bool.
    DATA lv_type TYPE string.
    DATA lv_name TYPE string.
    DATA lv_rel TYPE string.
    DATA lv_href TYPE string.
    DATA(lo_reader) = cl_sxml_string_reader=>create( cl_abap_codepage=>convert_to( iv_xml ) ).
    DO.
      DATA(lo_node) = lo_reader->read_next_node( ).
      IF lo_node IS INITIAL.
        EXIT.
      ENDIF.
      CASE lo_node->type.
        WHEN if_sxml_node=>co_nt_element_open.
          DATA(lo_open) = CAST if_sxml_open_element( lo_node ).
          APPEND lo_open->qname-name TO lt_elems.
          CLEAR: lv_type, lv_name, lv_rel, lv_href.
          LOOP AT lo_open->get_attributes( ) INTO DATA(lo_attr).
            CASE lo_attr->qname-name.
              WHEN 'type'. lv_type = lo_attr->get_value( ).
              WHEN 'name'. lv_name = lo_attr->get_value( ).
              WHEN 'rel'. lv_rel = lo_attr->get_value( ).
              WHEN 'href'. lv_href = lo_attr->get_value( ).
            ENDCASE.
          ENDLOOP.
          IF lo_open->qname-name = 'objectStructureElement'.
            " methods of the class (CLAS/OM) and of local test classes (CLAS/OLD)
            IF lv_type = 'CLAS/OM' OR lv_type = 'CLAS/OLD'.
              CLEAR ls_span.
              ls_span-method = to_upper( lv_name ).
              LOOP AT lt_stack INTO DATA(ls_parent) WHERE type <> 'CLAS/OM' AND type <> 'CLAS/OLD'.
                ls_span-owner = to_upper( ls_parent-name ).
              ENDLOOP.
              lv_in_method = abap_true.
            ENDIF.
            APPEND VALUE #( type = lv_type name = lv_name ) TO lt_stack.
          ELSEIF lo_open->qname-name = 'link' AND lv_in_method = abap_true.
            IF lv_rel CP '*implementationBlock'.
              range( EXPORTING iv_href = lv_href IMPORTING ev_include = ls_span-include
                                                           ev_from = ls_span-impl_from ev_to = ls_span-impl_to ).
            ELSEIF lv_rel CP '*definitionBlock'.
              range( EXPORTING iv_href = lv_href IMPORTING ev_from = ls_span-def_from ev_to = ls_span-def_to ).
            ENDIF.
          ENDIF.
        WHEN if_sxml_node=>co_nt_element_close.
          DATA(lv_closed) = ``.
          IF lt_elems IS NOT INITIAL.
            lv_closed = lt_elems[ lines( lt_elems ) ].
            DELETE lt_elems INDEX lines( lt_elems ).
          ENDIF.
          IF lv_closed = 'objectStructureElement'.
            DATA(lv_last) = lines( lt_stack ).
            IF lv_last > 0.
              DATA(ls_top) = lt_stack[ lv_last ].
              DELETE lt_stack INDEX lv_last.
              IF ls_top-type = 'CLAS/OM' OR ls_top-type = 'CLAS/OLD'.
                APPEND ls_span TO rt_.
                lv_in_method = abap_false.
              ENDIF.
            ENDIF.
          ENDIF.
      ENDCASE.
    ENDDO.
  ENDMETHOD.

ENDCLASS.

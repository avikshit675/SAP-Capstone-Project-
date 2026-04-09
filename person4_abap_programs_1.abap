*&---------------------------------------------------------------------*
*  PERSON 4 — ABAP Programs (3 files)
*  NLP Customer Complaint Router — SAP ABAP Capstone Project
*&---------------------------------------------------------------------*
*  PROGRAM 1: ZSD_COMPLAINT_EXTRACTOR  — Read SD tickets from SAP tables
*  PROGRAM 2: ZSD_COMPLAINT_ROUTER     — Call Flask API + get predictions
*  PROGRAM 3: ZSD_COMPLAINT_DASHBOARD  — ALV display with color coding
*&---------------------------------------------------------------------*
*  NOTE: Run these in SAP GUI (SE38 / SE80)
*  Flask API must be running at http://localhost:5000
*&---------------------------------------------------------------------*


*&---------------------------------------------------------------------*
*& PROGRAM 1: ZSD_COMPLAINT_EXTRACTOR
*& Reads SD service ticket data from SAP tables (or simulated data)
*&---------------------------------------------------------------------*
PROGRAM zsd_complaint_extractor.

" ── Type Definitions ──────────────────────────────────────────────────
TYPES: BEGIN OF ty_ticket,
  ticket_id   TYPE vbeln,       " Sales document number (SD)
  customer_id TYPE kunnr,       " Customer number
  complaint   TYPE string,      " Complaint text (from VBAKTXT or custom)
  created_on  TYPE erdat,       " Creation date
END OF ty_ticket.

DATA: lt_tickets TYPE TABLE OF ty_ticket,
      ls_ticket  TYPE ty_ticket.

" ── Option A: Read from real SAP SD tables ────────────────────────────
" Use this if you have SD module configured with service orders
"
" SELECT vbeln kunnr erdat
"   FROM vbak
"   INTO TABLE @DATA(lt_vbak)
"   WHERE auart = 'ZSR'          " Z-type service request
"   AND   erdat >= @sy-datum - 30.
"
" LOOP AT lt_vbak INTO DATA(ls_vbak).
"   ls_ticket-ticket_id   = ls_vbak-vbeln.
"   ls_ticket-customer_id = ls_vbak-kunnr.
"   ls_ticket-created_on  = ls_vbak-erdat.
"   " Read complaint text from long text or custom table
"   CALL FUNCTION 'READ_TEXT'
"     EXPORTING id     = 'VBBK'
"               language = sy-langu
"               name   = ls_vbak-vbeln
"               object = 'VBBK'
"     TABLES lines = DATA(lt_lines).
"   CONCATENATE LINES OF lt_lines INTO ls_ticket-complaint SEPARATED BY ' '.
"   APPEND ls_ticket TO lt_tickets.
" ENDLOOP.

" ── Option B: Simulated data (use this for demo/testing) ──────────────
DATA: lv_today TYPE erdat.
lv_today = sy-datum.

DEFINE add_ticket.
  CLEAR ls_ticket.
  ls_ticket-ticket_id   = &1.
  ls_ticket-customer_id = &2.
  ls_ticket-complaint   = &3.
  ls_ticket-created_on  = lv_today.
  APPEND ls_ticket TO lt_tickets.
END-OF-DEFINITION.

add_ticket '0000001001' 'CUST001' 'I was charged twice for the same invoice number'.
add_ticket '0000001002' 'CUST002' 'My package has not arrived after 2 weeks, order still pending'.
add_ticket '0000001003' 'CUST003' 'The product I received is completely broken and defective'.
add_ticket '0000001004' 'CUST004' 'I want a full refund for my cancelled order immediately'.
add_ticket '0000001005' 'CUST005' 'Cannot login to my account, it keeps getting locked out'.
add_ticket '0000001006' 'CUST006' 'Wrong tax amount on my invoice, billing error please check'.
add_ticket '0000001007' 'CUST007' 'Shipment was delayed by 10 days without any notification'.
add_ticket '0000001008' 'CUST008' 'Product stopped working after 2 days, poor quality issue'.
add_ticket '0000001009' 'CUST009' 'Refund pending for 3 weeks, please process my return'.
add_ticket '0000001010' 'CUST010' 'My account profile is not updating, password reset not working'.

" ── Export to file (for Python / as handoff to Program 2) ─────────────
DATA: lv_filename TYPE string VALUE 'C:\SAP\complaints_export.csv',
      lt_lines    TYPE TABLE OF string,
      lv_line     TYPE string.

" Header
lv_line = 'ticket_id,customer_id,complaint,created_on'.
APPEND lv_line TO lt_lines.

LOOP AT lt_tickets INTO ls_ticket.
  CONCATENATE ls_ticket-ticket_id ','
              ls_ticket-customer_id ','
              ls_ticket-complaint ','
              ls_ticket-created_on
         INTO lv_line.
  APPEND lv_line TO lt_lines.
ENDLOOP.

CALL FUNCTION 'GUI_DOWNLOAD'
  EXPORTING filename = lv_filename
            filetype = 'ASC'
  TABLES    data_tab = lt_lines.

IF sy-subrc = 0.
  MESSAGE 'Complaints exported to CSV successfully!' TYPE 'S'.
ELSE.
  MESSAGE 'Export failed. Check file path.' TYPE 'E'.
ENDIF.

WRITE: / '✅ Extracted', lines( lt_tickets ), 'tickets.'.
WRITE: / '📁 File saved to:', lv_filename.


*&---------------------------------------------------------------------*
*& PROGRAM 2: ZSD_COMPLAINT_ROUTER
*& Calls Flask API for each ticket and stores predictions
*&---------------------------------------------------------------------*
PROGRAM zsd_complaint_router.

" ── Type Definitions ──────────────────────────────────────────────────
TYPES: BEGIN OF ty_prediction,
  ticket_id   TYPE string,
  complaint   TYPE string,
  category    TYPE string,
  route_to    TYPE string,
  priority    TYPE string,
  confidence  TYPE string,
END OF ty_prediction.

DATA: lt_predictions TYPE TABLE OF ty_prediction,
      ls_prediction  TYPE ty_prediction.

" ── Flask API Configuration ───────────────────────────────────────────
CONSTANTS: lc_api_host TYPE string VALUE 'localhost',
           lc_api_port TYPE string VALUE '5000',
           lc_api_path TYPE string VALUE '/predict_batch'.

" ── Ticket Data (same as Program 1, or read from file) ───────────────
TYPES: BEGIN OF ty_ticket,
  ticket_id   TYPE string,
  complaint   TYPE string,
END OF ty_ticket.

DATA: lt_tickets TYPE TABLE OF ty_ticket.

" Add sample tickets (in real scenario, read from DB or file)
DATA(ls_t1) = VALUE ty_ticket( ticket_id = 'TKT1001'
  complaint = 'I was charged twice for the same invoice' ).
DATA(ls_t2) = VALUE ty_ticket( ticket_id = 'TKT1002'
  complaint = 'Package not delivered after 2 weeks' ).
DATA(ls_t3) = VALUE ty_ticket( ticket_id = 'TKT1003'
  complaint = 'Product received is broken and defective' ).
DATA(ls_t4) = VALUE ty_ticket( ticket_id = 'TKT1004'
  complaint = 'Want full refund for cancelled order' ).
DATA(ls_t5) = VALUE ty_ticket( ticket_id = 'TKT1005'
  complaint = 'Cannot login to account, it is locked' ).

APPEND ls_t1 TO lt_tickets.
APPEND ls_t2 TO lt_tickets.
APPEND ls_t3 TO lt_tickets.
APPEND ls_t4 TO lt_tickets.
APPEND ls_t5 TO lt_tickets.

" ── Build JSON Request Body ───────────────────────────────────────────
DATA: lo_http_client TYPE REF TO if_http_client,
      lv_json_body   TYPE string,
      lv_json_item   TYPE string,
      lv_response    TYPE string,
      lv_status      TYPE i.

" Build JSON manually (no external library needed)
DATA(lv_items) = ''.
LOOP AT lt_tickets INTO DATA(ls_ticket).
  CONCATENATE '{"ticket_id":"' ls_ticket-ticket_id
              '","complaint":"' ls_ticket-complaint '"}'
         INTO lv_json_item.
  IF lv_items IS INITIAL.
    lv_items = lv_json_item.
  ELSE.
    CONCATENATE lv_items ',' lv_json_item INTO lv_items.
  ENDIF.
ENDLOOP.

CONCATENATE '{"complaints":[' lv_items ']}' INTO lv_json_body.

" ── Call Flask API via HTTP ───────────────────────────────────────────
CALL METHOD cl_http_client=>create_by_destination
  EXPORTING destination = 'FLASK_API'         " SM59 destination
  IMPORTING client      = lo_http_client
  EXCEPTIONS OTHERS     = 4.

" If SM59 not configured, use direct URL:
IF sy-subrc <> 0.
  CALL METHOD cl_http_client=>create_by_url
    EXPORTING url    = 'http://localhost:5000/predict_batch'
    IMPORTING client = lo_http_client
    EXCEPTIONS OTHERS = 4.
ENDIF.

IF lo_http_client IS NOT INITIAL.
  " Set method and headers
  lo_http_client->request->set_method( 'POST' ).
  lo_http_client->request->set_header_field(
    name  = 'Content-Type'
    value = 'application/json' ).

  " Set request body
  lo_http_client->request->set_cdata( data = lv_json_body ).

  " Send request
  lo_http_client->send( EXCEPTIONS OTHERS = 4 ).
  lo_http_client->receive( EXCEPTIONS OTHERS = 4 ).

  " Get response
  lv_status = lo_http_client->response->get_status( ).
  lv_response = lo_http_client->response->get_cdata( ).

  IF lv_status = 200.
    WRITE: / '✅ API call successful!'.
    WRITE: / 'Response:', lv_response.

    " ── Parse JSON Response ─────────────────────────────────────────
    " Simple manual parsing — extract key fields
    " In production use /UI2/CL_JSON or CALL TRANSFORMATION
    DATA: lv_pos    TYPE i,
          lv_start  TYPE i,
          lv_end    TYPE i,
          lv_field  TYPE string.

    " Simple extraction using FIND
    DATA(lv_work) = lv_response.
    WHILE lv_work CS '"ticket_id"'.
      CLEAR ls_prediction.

      " Extract ticket_id
      FIND REGEX '"ticket_id"\s*:\s*"([^"]+)"' IN lv_work
        SUBMATCHES ls_prediction-ticket_id.
      " Extract category
      FIND REGEX '"category"\s*:\s*"([^"]+)"' IN lv_work
        SUBMATCHES ls_prediction-category.
      " Extract route_to
      FIND REGEX '"route_to"\s*:\s*"([^"]+)"' IN lv_work
        SUBMATCHES ls_prediction-route_to.
      " Extract priority
      FIND REGEX '"priority"\s*:\s*"([^"]+)"' IN lv_work
        SUBMATCHES ls_prediction-priority.
      " Extract confidence
      FIND REGEX '"confidence"\s*:\s*([0-9.]+)' IN lv_work
        SUBMATCHES ls_prediction-confidence.

      IF ls_prediction-ticket_id IS NOT INITIAL.
        APPEND ls_prediction TO lt_predictions.
      ENDIF.

      " Move past this entry
      lv_pos = strlen( lv_work ).
      IF lv_pos > 50.
        lv_work = lv_work+50.
      ELSE.
        EXIT.
      ENDIF.
    ENDWHILE.

  ELSE.
    WRITE: / '❌ API Error. Status:', lv_status.
    " Fallback: use dummy predictions for demo
    LOOP AT lt_tickets INTO ls_ticket.
      ls_prediction-ticket_id  = ls_ticket-ticket_id.
      ls_prediction-category   = 'Billing Issue'.
      ls_prediction-route_to   = 'Finance Team'.
      ls_prediction-priority   = 'HIGH'.
      ls_prediction-confidence = '0.85'.
      APPEND ls_prediction TO lt_predictions.
    ENDLOOP.
  ENDIF.

  lo_http_client->close( ).
ENDIF.

" Store predictions in memory table for Program 3
" In production: write to Z-table
EXPORT lt_predictions TO MEMORY ID 'COMPLAINT_PREDICTIONS'.
WRITE: / '✅', lines( lt_predictions ), 'predictions stored in memory.'.


*&---------------------------------------------------------------------*
*& PROGRAM 3: ZSD_COMPLAINT_DASHBOARD
*& ALV Grid with color-coded complaint routing results
*&---------------------------------------------------------------------*
PROGRAM zsd_complaint_dashboard.

" ── Type Definitions ──────────────────────────────────────────────────
TYPES: BEGIN OF ty_display,
  traffic_light TYPE c LENGTH 1,     " For ALV color
  ticket_id     TYPE string,
  customer_id   TYPE string,
  complaint     TYPE string,
  category      TYPE string,
  route_to      TYPE string,
  priority      TYPE string,
  confidence    TYPE string,
  status        TYPE string,
END OF ty_display.

DATA: lt_display  TYPE TABLE OF ty_display,
      ls_display  TYPE ty_display,
      lt_alv_cat  TYPE lvc_t_fcat,
      ls_alv_cat  TYPE lvc_s_fcat,
      ls_layout   TYPE lvc_s_layo,
      lo_alv      TYPE REF TO cl_gui_alv_grid,
      lo_custom   TYPE REF TO cl_gui_custom_container.

" ── Load Predictions ──────────────────────────────────────────────────
TYPES: BEGIN OF ty_prediction,
  ticket_id  TYPE string,
  complaint  TYPE string,
  category   TYPE string,
  route_to   TYPE string,
  priority   TYPE string,
  confidence TYPE string,
END OF ty_prediction.

DATA: lt_predictions TYPE TABLE OF ty_prediction.

IMPORT lt_predictions FROM MEMORY ID 'COMPLAINT_PREDICTIONS'.

" If memory import failed, use sample data
IF lt_predictions IS INITIAL.
  APPEND VALUE ty_prediction(
    ticket_id = 'TKT1001' complaint = 'Charged twice for invoice'
    category = 'Billing Issue' route_to = 'Finance Team'
    priority = 'HIGH' confidence = '0.94' ) TO lt_predictions.
  APPEND VALUE ty_prediction(
    ticket_id = 'TKT1002' complaint = 'Package not delivered'
    category = 'Delivery Problem' route_to = 'Logistics Team'
    priority = 'MEDIUM' confidence = '0.91' ) TO lt_predictions.
  APPEND VALUE ty_prediction(
    ticket_id = 'TKT1003' complaint = 'Product is broken'
    category = 'Product Defect' route_to = 'Quality Team'
    priority = 'HIGH' confidence = '0.88' ) TO lt_predictions.
  APPEND VALUE ty_prediction(
    ticket_id = 'TKT1004' complaint = 'Want full refund'
    category = 'Refund Request' route_to = 'Finance Team'
    priority = 'MEDIUM' confidence = '0.96' ) TO lt_predictions.
  APPEND VALUE ty_prediction(
    ticket_id = 'TKT1005' complaint = 'Cannot login to account'
    category = 'Account Issue' route_to = 'IT Support Team'
    priority = 'LOW' confidence = '0.89' ) TO lt_predictions.
ENDIF.

" ── Prepare Display Table with Colors ─────────────────────────────────
LOOP AT lt_predictions INTO DATA(ls_pred).
  CLEAR ls_display.
  ls_display-ticket_id   = ls_pred-ticket_id.
  ls_display-complaint   = ls_pred-complaint.
  ls_display-category    = ls_pred-category.
  ls_display-route_to    = ls_pred-route_to.
  ls_display-priority    = ls_pred-priority.
  ls_display-confidence  = ls_pred-confidence.
  ls_display-status      = 'PENDING'.

  " Set traffic light color based on priority
  CASE ls_pred-priority.
    WHEN 'HIGH'.
      ls_display-traffic_light = '1'.  " Red
    WHEN 'MEDIUM'.
      ls_display-traffic_light = '2'.  " Yellow
    WHEN 'LOW'.
      ls_display-traffic_light = '3'.  " Green
    WHEN OTHERS.
      ls_display-traffic_light = '2'.
  ENDCASE.

  APPEND ls_display TO lt_display.
ENDLOOP.

" ── Field Catalog ─────────────────────────────────────────────────────
DEFINE add_field.
  CLEAR ls_alv_cat.
  ls_alv_cat-fieldname = &1.
  ls_alv_cat-coltext   = &2.
  ls_alv_cat-outputlen = &3.
  APPEND ls_alv_cat TO lt_alv_cat.
END-OF-DEFINITION.

add_field 'TRAFFIC_LIGHT' 'Risk'       5.
add_field 'TICKET_ID'     'Ticket ID'  12.
add_field 'CUSTOMER_ID'   'Customer'   10.
add_field 'COMPLAINT'     'Complaint'  45.
add_field 'CATEGORY'      'Category'   18.
add_field 'ROUTE_TO'      'Route To'   18.
add_field 'PRIORITY'      'Priority'   10.
add_field 'CONFIDENCE'    'Confidence' 12.
add_field 'STATUS'        'Status'     12.

" Traffic light field configuration
READ TABLE lt_alv_cat INTO ls_alv_cat
  WITH KEY fieldname = 'TRAFFIC_LIGHT'.
IF sy-subrc = 0.
  ls_alv_cat-just   = 'C'.
  MODIFY lt_alv_cat FROM ls_alv_cat
    TRANSPORTING just WHERE fieldname = 'TRAFFIC_LIGHT'.
ENDIF.

" ── Layout ────────────────────────────────────────────────────────────
ls_layout-info_fname = 'TRAFFIC_LIGHT'.   " Color column
ls_layout-cwidth_opt = abap_true.         " Auto column width
ls_layout-zebra      = abap_true.         " Zebra stripes
ls_layout-grid_title = 'SAP AI Complaint Router — Prediction Dashboard'.

" ── Display ALV ───────────────────────────────────────────────────────
CALL FUNCTION 'REUSE_ALV_GRID_DISPLAY_LVC'
  EXPORTING
    i_structure_name = 'TY_DISPLAY'
    is_layout        = ls_layout
    it_fieldcat      = lt_alv_cat
    i_default        = 'X'
    i_save           = 'A'
  TABLES
    t_outtab         = lt_display
  EXCEPTIONS
    OTHERS           = 4.

IF sy-subrc <> 0.
  " Fallback: simple WRITE output
  WRITE: / '╔══ SAP AI COMPLAINT ROUTER DASHBOARD ══╗'.
  WRITE: /.
  WRITE: /5  'Ticket ID',
         20  'Category',
         40  'Route To',
         60  'Priority',
         72  'Confidence'.
  WRITE: / SY-ULINE.

  LOOP AT lt_display INTO ls_display.
    WRITE: /5  ls_display-ticket_id,
           20  ls_display-category,
           40  ls_display-route_to.

    CASE ls_display-priority.
      WHEN 'HIGH'.
        FORMAT COLOR COL_NEGATIVE.
        WRITE: 60 ls_display-priority.
        FORMAT COLOR OFF.
      WHEN 'MEDIUM'.
        FORMAT COLOR COL_WARNING.
        WRITE: 60 ls_display-priority.
        FORMAT COLOR OFF.
      WHEN 'LOW'.
        FORMAT COLOR COL_POSITIVE.
        WRITE: 60 ls_display-priority.
        FORMAT COLOR OFF.
    ENDCASE.

    WRITE: 72 ls_display-confidence.
  ENDLOOP.

  WRITE: / SY-ULINE.
  WRITE: / 'Total tickets processed:', lines( lt_display ).
ENDIF.

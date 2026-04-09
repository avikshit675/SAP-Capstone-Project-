# SAP-Capstone-Project
NLP-powered customer complaint classification system
# SAP AI Complaint Router

**NLP-Driven Intelligent Customer Complaint Classification and 
Automated Routing System Integrated with SAP SD Module**

---

## Team ID
CU_CP_Team_15179

## Team Members
- Avikshit Banewar (Team Leader)
- Swarlaxmi Dhamale
- Sayali Barve
- Harshal Bhosale

**Mentor:** Prof. Amol Patil  
**Institute:** PVPIT Bavdhan, Pune  
**University:** Savitribai Phule Pune University  
**Academic Year:** 2025-26

---

## Problem Statement
Large enterprises using SAP manually route hundreds of unstructured 
customer complaints daily to appropriate departments, resulting in 
routing inconsistencies, processing delays, and absence of 
priority-aware automation — necessitating an intelligent NLP-based 
classification system directly integrated with SAP SD for real-time 
automated complaint routing.

---

## Project Overview
AI-powered system that reads customer complaint text, classifies it 
into one of 5 categories, and routes it to the correct SAP SD team 
automatically with confidence scoring.

---

## Complaint Categories
| Category | Routes To | Priority |
|---|---|---|
| Billing Issue | Finance Team | HIGH |
| Delivery Problem | Logistics Team | MEDIUM |
| Product Defect | Quality Team | HIGH |
| Refund Request | Finance Team | MEDIUM |
| Account Issue | IT Support Team | LOW |

---

## Model Performance
| Model | Accuracy | F1 Score |
|---|---|---|
| Logistic Regression | 88% | 0.87 |
| Random Forest | 92% | 0.91 |
| **XGBoost (Best)** | **94%** | **0.94** |
| Bidirectional LSTM | 92% | 0.92 |

---

## Tech Stack
- **ML/DL:** Python, scikit-learn, XGBoost, TensorFlow/Keras
- **NLP:** TF-IDF Vectorizer, Bidirectional LSTM
- **Backend:** Flask REST API
- **SAP:** ABAP, CL_HTTP_CLIENT, ALV Grid, VBAK/VBAP tables

---

## File Structure
| File | Description |
|---|---|
| data_eda_1.ipynb | Person 1 — Data generation and EDA |
| ml_models_2.ipynb | Person 2 — Classical ML models |
| dl_model_3.ipynb | Person 3 — Bidirectional LSTM |
| flask_app.py | Person 3 — Flask API + Web UI |
| person4_abap_programs_1.abap | Person 4 — SAP ABAP programs |
| train.csv / test.csv | Training and testing datasets |
| model_xgb.pkl | Trained XGBoost model |
| tfidf_vectorizer.pkl | TF-IDF vectorizer |
| label_encoder.pkl | Label encoder |
| model_lstm.h5 | Trained BiLSTM model |
| eda_dashboard.png | EDA visualization |
| ml_comparison.png | Model comparison chart |
| lstm_training.png | LSTM training history |

---

## How to Run
1. Install dependencies: pip install pandas numpy scikit-learn xgboost tensorflow flask
2. Run notebooks in order: data_eda_1 → ml_models_2 → dl_model_3
3. Start Flask server: python flask_app.py
4. Open browser: http://localhost:5000

# ============================================================
# PERSON 3 — Flask API + Web UI
# NLP Customer Complaint Router — SAP ABAP Capstone Project
# ============================================================
# Run: python app.py
# API runs at: http://localhost:5000
# ============================================================

from flask import Flask, request, jsonify, render_template_string
import joblib
import pickle
import numpy as np
import re
import warnings
warnings.filterwarnings('ignore')

from tensorflow.keras.models import load_model
from tensorflow.keras.preprocessing.sequence import pad_sequences

app = Flask(__name__)

# ── Load Models ────────────────────────────────────────────────────────────────

print("🔄 Loading models...")

# Classical ML (XGBoost) — fast, reliable
tfidf      = joblib.load('tfidf_vectorizer.pkl')
xgb_model  = joblib.load('model_xgb.pkl')
le_xgb     = joblib.load('label_encoder.pkl')

# Deep Learning (LSTM)
lstm_model = load_model('model_lstm.h5')
with open('tokenizer.pkl', 'rb') as f:
    tokenizer = pickle.load(f)
le_dl      = joblib.load('label_encoder_dl.pkl')

MAX_LEN = 50
print("✅ All models loaded!")

# ── Config ────────────────────────────────────────────────────────────────────

ROUTING_MAP = {
    'Billing Issue':    'Finance Team',
    'Delivery Problem': 'Logistics Team',
    'Product Defect':   'Quality Team',
    'Refund Request':   'Finance Team',
    'Account Issue':    'IT Support Team',
}

PRIORITY_MAP = {
    'Billing Issue':    'HIGH',
    'Delivery Problem': 'MEDIUM',
    'Product Defect':   'HIGH',
    'Refund Request':   'MEDIUM',
    'Account Issue':    'LOW',
}

PRIORITY_COLOR = {
    'HIGH':   '#E74C3C',
    'MEDIUM': '#F39C12',
    'LOW':    '#2ECC71',
}

def clean_text(text):
    text = text.lower()
    text = re.sub(r'[^a-zA-Z\s]', '', text)
    text = re.sub(r'\s+', ' ', text).strip()
    return text

def predict_xgb(text):
    cleaned = clean_text(text)
    vec     = tfidf.transform([cleaned])
    pred    = le_xgb.inverse_transform(xgb_model.predict(vec))[0]
    proba   = float(xgb_model.predict_proba(vec).max())
    return pred, proba

def predict_lstm(text):
    cleaned = clean_text(text)
    seq     = tokenizer.texts_to_sequences([cleaned])
    padded  = pad_sequences(seq, maxlen=MAX_LEN, padding='post')
    proba_arr = lstm_model.predict(padded, verbose=0)[0]
    pred_idx  = np.argmax(proba_arr)
    pred      = le_dl.inverse_transform([pred_idx])[0]
    proba     = float(proba_arr[pred_idx])
    return pred, proba

# ── API Routes ────────────────────────────────────────────────────────────────

@app.route('/predict', methods=['POST'])
def predict():
    """
    POST /predict
    Body: { "complaint": "my invoice is wrong", "model": "xgb" }
    model options: "xgb" (default) or "lstm"
    """
    data = request.get_json()
    if not data or 'complaint' not in data:
        return jsonify({'error': 'Missing complaint field'}), 400

    complaint  = data['complaint']
    model_type = data.get('model', 'xgb')

    if model_type == 'lstm':
        category, confidence = predict_lstm(complaint)
    else:
        category, confidence = predict_xgb(complaint)

    result = {
        'complaint':   complaint,
        'category':    category,
        'route_to':    ROUTING_MAP.get(category, 'General Support'),
        'priority':    PRIORITY_MAP.get(category, 'MEDIUM'),
        'confidence':  round(confidence, 4),
        'model_used':  model_type.upper(),
    }
    return jsonify(result)


@app.route('/predict_batch', methods=['POST'])
def predict_batch():
    """
    POST /predict_batch
    Body: { "complaints": ["text1", "text2", ...] }
    Used by ABAP to send multiple tickets at once
    """
    data = request.get_json()
    if not data or 'complaints' not in data:
        return jsonify({'error': 'Missing complaints field'}), 400

    results = []
    for item in data['complaints']:
        ticket_id = item.get('ticket_id', 'N/A')
        complaint = item.get('complaint', '')
        category, confidence = predict_xgb(complaint)
        results.append({
            'ticket_id':  ticket_id,
            'category':   category,
            'route_to':   ROUTING_MAP.get(category, 'General Support'),
            'priority':   PRIORITY_MAP.get(category, 'MEDIUM'),
            'confidence': round(confidence, 4),
        })

    return jsonify({'predictions': results, 'count': len(results)})


@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'ok', 'models_loaded': ['XGBoost', 'LSTM']})


# ── Web UI ────────────────────────────────────────────────────────────────────

HTML_TEMPLATE = """
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>SAP Complaint Router — AI Dashboard</title>
<link href="https://fonts.googleapis.com/css2?family=Syne:wght@400;600;700;800&family=DM+Sans:wght@300;400;500&display=swap" rel="stylesheet">
<style>
  :root {
    --bg: #0a0e1a;
    --card: #111827;
    --border: #1e293b;
    --accent: #6366f1;
    --accent2: #a78bfa;
    --text: #e2e8f0;
    --muted: #64748b;
    --high: #ef4444;
    --med: #f59e0b;
    --low: #10b981;
  }
  * { margin:0; padding:0; box-sizing:border-box; }
  body {
    background: var(--bg);
    color: var(--text);
    font-family: 'DM Sans', sans-serif;
    min-height: 100vh;
    padding: 40px 20px;
  }
  .header {
    text-align: center;
    margin-bottom: 48px;
  }
  .header h1 {
    font-family: 'Syne', sans-serif;
    font-size: 2.8rem;
    font-weight: 800;
    background: linear-gradient(135deg, #6366f1, #a78bfa, #38bdf8);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    background-clip: text;
    letter-spacing: -1px;
  }
  .header p {
    color: var(--muted);
    font-size: 1rem;
    margin-top: 8px;
    font-weight: 300;
  }
  .sap-badge {
    display: inline-block;
    background: linear-gradient(135deg, #1e4d8c, #0070d2);
    color: white;
    font-size: 0.75rem;
    font-weight: 600;
    padding: 4px 12px;
    border-radius: 20px;
    margin-top: 10px;
    letter-spacing: 1px;
  }
  .container { max-width: 900px; margin: 0 auto; }

  .card {
    background: var(--card);
    border: 1px solid var(--border);
    border-radius: 16px;
    padding: 32px;
    margin-bottom: 24px;
  }
  .card h2 {
    font-family: 'Syne', sans-serif;
    font-size: 1.1rem;
    font-weight: 600;
    color: var(--accent2);
    margin-bottom: 20px;
    text-transform: uppercase;
    letter-spacing: 1px;
  }

  textarea {
    width: 100%;
    min-height: 120px;
    background: #0f172a;
    border: 1px solid var(--border);
    border-radius: 10px;
    padding: 16px;
    color: var(--text);
    font-family: 'DM Sans', sans-serif;
    font-size: 1rem;
    resize: vertical;
    transition: border-color 0.2s;
    outline: none;
  }
  textarea:focus { border-color: var(--accent); }

  .controls {
    display: flex;
    gap: 12px;
    margin-top: 16px;
    align-items: center;
    flex-wrap: wrap;
  }
  select {
    background: #0f172a;
    border: 1px solid var(--border);
    border-radius: 8px;
    color: var(--text);
    padding: 10px 16px;
    font-family: 'DM Sans', sans-serif;
    font-size: 0.9rem;
    cursor: pointer;
    outline: none;
  }
  button {
    background: linear-gradient(135deg, var(--accent), var(--accent2));
    border: none;
    border-radius: 8px;
    color: white;
    padding: 12px 32px;
    font-family: 'Syne', sans-serif;
    font-size: 1rem;
    font-weight: 600;
    cursor: pointer;
    transition: transform 0.15s, opacity 0.15s;
    letter-spacing: 0.5px;
  }
  button:hover { transform: translateY(-1px); opacity: 0.9; }
  button:active { transform: translateY(0); }
  button:disabled { opacity: 0.5; cursor: not-allowed; }

  .result-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
    gap: 16px;
    margin-top: 8px;
  }
  .result-item {
    background: #0f172a;
    border: 1px solid var(--border);
    border-radius: 10px;
    padding: 16px 20px;
  }
  .result-item .label {
    font-size: 0.7rem;
    text-transform: uppercase;
    letter-spacing: 1.5px;
    color: var(--muted);
    margin-bottom: 6px;
  }
  .result-item .value {
    font-family: 'Syne', sans-serif;
    font-size: 1.05rem;
    font-weight: 700;
    color: var(--text);
  }
  .priority-HIGH   { color: var(--high) !important; }
  .priority-MEDIUM { color: var(--med)  !important; }
  .priority-LOW    { color: var(--low)  !important; }

  .confidence-bar {
    margin-top: 20px;
  }
  .confidence-bar .label {
    font-size: 0.75rem;
    color: var(--muted);
    margin-bottom: 6px;
    display: flex;
    justify-content: space-between;
  }
  .bar-bg {
    background: var(--border);
    border-radius: 99px;
    height: 8px;
    overflow: hidden;
  }
  .bar-fill {
    height: 100%;
    border-radius: 99px;
    background: linear-gradient(90deg, var(--accent), var(--accent2));
    transition: width 0.6s ease;
  }

  .examples {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
    margin-top: 12px;
  }
  .example-btn {
    background: transparent;
    border: 1px solid var(--border);
    border-radius: 6px;
    color: var(--muted);
    padding: 6px 12px;
    font-size: 0.8rem;
    font-family: 'DM Sans', sans-serif;
    font-weight: 400;
    cursor: pointer;
    transition: all 0.2s;
  }
  .example-btn:hover {
    border-color: var(--accent);
    color: var(--accent2);
    background: rgba(99,102,241,0.08);
    transform: none;
  }

  .hidden { display: none; }
  .loading { color: var(--muted); font-style: italic; }

  .history-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 0.88rem;
  }
  .history-table th {
    text-align: left;
    padding: 10px 12px;
    color: var(--muted);
    font-weight: 500;
    border-bottom: 1px solid var(--border);
    font-size: 0.75rem;
    text-transform: uppercase;
    letter-spacing: 1px;
  }
  .history-table td {
    padding: 10px 12px;
    border-bottom: 1px solid #0f172a;
  }
  .history-table tr:hover td { background: rgba(99,102,241,0.04); }
  .badge {
    display: inline-block;
    padding: 2px 10px;
    border-radius: 99px;
    font-size: 0.72rem;
    font-weight: 600;
  }
  .badge-HIGH   { background: rgba(239,68,68,0.15);   color: var(--high); }
  .badge-MEDIUM { background: rgba(245,158,11,0.15);  color: var(--med);  }
  .badge-LOW    { background: rgba(16,185,129,0.15);  color: var(--low);  }
</style>
</head>
<body>
<div class="container">
  <div class="header">
    <h1>SAP Complaint Router</h1>
    <p>AI-Powered Customer Ticket Classification & Routing</p>
    <span class="sap-badge">SAP SD MODULE INTEGRATION</span>
  </div>

  <!-- Input Card -->
  <div class="card">
    <h2>🎯 Analyze Complaint</h2>
    <textarea id="complaintInput" placeholder="Type a customer complaint here...&#10;e.g. My invoice shows the wrong amount, I was charged twice"></textarea>

    <div style="margin-top:12px;">
      <p style="font-size:0.8rem; color:var(--muted); margin-bottom:8px;">Quick examples:</p>
      <div class="examples">
        <button class="example-btn" onclick="fillExample('I was charged twice for the same order')">💳 Billing</button>
        <button class="example-btn" onclick="fillExample('My package has not arrived after 2 weeks')">📦 Delivery</button>
        <button class="example-btn" onclick="fillExample('The product I received is completely broken')">🔧 Defect</button>
        <button class="example-btn" onclick="fillExample('I want a full refund for my cancelled order')">💰 Refund</button>
        <button class="example-btn" onclick="fillExample('I cannot login to my account, it keeps getting locked')">🔐 Account</button>
      </div>
    </div>

    <div class="controls">
      <select id="modelSelect">
        <option value="xgb">XGBoost (Fast)</option>
        <option value="lstm">LSTM (Deep Learning)</option>
      </select>
      <button onclick="predict()" id="predictBtn">Analyze →</button>
    </div>
  </div>

  <!-- Result Card -->
  <div class="card hidden" id="resultCard">
    <h2>📊 Prediction Result</h2>
    <div class="result-grid" id="resultGrid"></div>
    <div class="confidence-bar" id="confBar"></div>
  </div>

  <!-- History Card -->
  <div class="card hidden" id="historyCard">
    <h2>📋 Session History</h2>
    <table class="history-table">
      <thead>
        <tr>
          <th>#</th>
          <th>Complaint</th>
          <th>Category</th>
          <th>Route To</th>
          <th>Priority</th>
          <th>Confidence</th>
          <th>Model</th>
        </tr>
      </thead>
      <tbody id="historyBody"></tbody>
    </table>
  </div>
</div>

<script>
let historyData = [];
let counter = 1;

function fillExample(text) {
  document.getElementById('complaintInput').value = text;
}

async function predict() {
  const complaint = document.getElementById('complaintInput').value.trim();
  const model     = document.getElementById('modelSelect').value;
  if (!complaint) return;

  const btn = document.getElementById('predictBtn');
  btn.disabled = true;
  btn.textContent = 'Analyzing...';

  try {
    const res = await fetch('/predict', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ complaint, model })
    });
    const data = await res.json();
    displayResult(data);
    addToHistory(data, counter++);
  } catch(e) {
    alert('API error: ' + e.message);
  } finally {
    btn.disabled = false;
    btn.textContent = 'Analyze →';
  }
}

function displayResult(data) {
  const pColor = data.priority === 'HIGH' ? '#ef4444' : data.priority === 'MEDIUM' ? '#f59e0b' : '#10b981';
  const confPct = Math.round(data.confidence * 100);

  document.getElementById('resultGrid').innerHTML = `
    <div class="result-item">
      <div class="label">Category</div>
      <div class="value">${data.category}</div>
    </div>
    <div class="result-item">
      <div class="label">Route To</div>
      <div class="value">${data.route_to}</div>
    </div>
    <div class="result-item">
      <div class="label">Priority</div>
      <div class="value priority-${data.priority}">${data.priority}</div>
    </div>
    <div class="result-item">
      <div class="label">Model Used</div>
      <div class="value">${data.model_used}</div>
    </div>
  `;

  document.getElementById('confBar').innerHTML = `
    <div class="label">
      <span>Confidence Score</span>
      <span style="color:var(--accent2); font-weight:600;">${confPct}%</span>
    </div>
    <div class="bar-bg">
      <div class="bar-fill" style="width:0%" id="fillBar"></div>
    </div>
  `;

  document.getElementById('resultCard').classList.remove('hidden');
  setTimeout(() => {
    document.getElementById('fillBar').style.width = confPct + '%';
  }, 50);
}

function addToHistory(data, num) {
  const tbody = document.getElementById('historyBody');
  const short = data.complaint.length > 40 ? data.complaint.slice(0, 40) + '...' : data.complaint;
  const row = document.createElement('tr');
  row.innerHTML = `
    <td style="color:var(--muted)">${num}</td>
    <td>${short}</td>
    <td style="color:var(--accent2)">${data.category}</td>
    <td>${data.route_to}</td>
    <td><span class="badge badge-${data.priority}">${data.priority}</span></td>
    <td>${Math.round(data.confidence * 100)}%</td>
    <td style="color:var(--muted)">${data.model_used}</td>
  `;
  tbody.insertBefore(row, tbody.firstChild);
  document.getElementById('historyCard').classList.remove('hidden');
}

document.getElementById('complaintInput').addEventListener('keydown', (e) => {
  if (e.key === 'Enter' && e.ctrlKey) predict();
});
</script>
</body>
</html>
"""

@app.route('/')
def index():
    return render_template_string(HTML_TEMPLATE)


if __name__ == '__main__':
    print("\n🚀 Starting Flask server...")
    print("   Web UI:  http://localhost:5000")
    print("   API:     http://localhost:5000/predict")
    print("   Health:  http://localhost:5000/health")
    app.run(debug=True, host='0.0.0.0', port=5000)

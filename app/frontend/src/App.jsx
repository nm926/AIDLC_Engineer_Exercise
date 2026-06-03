import React, { useMemo, useState } from "react";

const defaultPayload = {
  transaction_id: `TX-${Date.now()}`,
  user_id: "U100",
  amount: 12000,
  location: "Delhi"
};

function App() {
  const [payload, setPayload] = useState(defaultPayload);
  const [loading, setLoading] = useState(false);
  const [response, setResponse] = useState(null);
  const [error, setError] = useState("");

  const riskClass = useMemo(() => {
    if (!response) return "risk-neutral";
    if (response.risk_score >= 0.5) return "risk-high";
    if (response.risk_score >= 0.2) return "risk-medium";
    return "risk-low";
  }, [response]);

  const handleChange = (event) => {
    const { name, value } = event.target;
    setPayload((prev) => ({
      ...prev,
      [name]: name === "amount" ? Number(value) : value
    }));
  };

  const handleSubmit = async (event) => {
    event.preventDefault();
    setLoading(true);
    setError("");

    try {
      const res = await fetch("/check-payment", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload)
      });

      if (!res.ok) {
        const text = await res.text();
        throw new Error(text || `Request failed with status ${res.status}`);
      }

      const data = await res.json();
      setResponse(data);
    } catch (err) {
      setResponse(null);
      setError(err.message || "Failed to check payment");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="app-shell">
      <div className="ambient-gradient" />
      <main className="layout">
        <section className="panel form-panel">
          <h1>Payment Fraud Console</h1>
          <p className="subtitle">
            Submit payment details to the FastAPI fraud engine and review the decision instantly.
          </p>

          <form onSubmit={handleSubmit} className="form-grid">
            <label>
              Transaction ID
              <input name="transaction_id" value={payload.transaction_id} onChange={handleChange} required />
            </label>

            <label>
              User ID
              <input name="user_id" value={payload.user_id} onChange={handleChange} required />
            </label>

            <label>
              Amount
              <input name="amount" type="number" min="0" step="0.01" value={payload.amount} onChange={handleChange} required />
            </label>

            <label>
              Location
              <input name="location" value={payload.location} onChange={handleChange} required />
            </label>

            <button type="submit" disabled={loading}>
              {loading ? "Checking..." : "Run Fraud Check"}
            </button>
          </form>
        </section>

        <section className={`panel response-panel ${riskClass}`}>
          <h2>Decision</h2>
          {!response && !error && <p>No request submitted yet.</p>}
          {error && <p className="error">{error}</p>}
          {response && (
            <>
              <p className="message">{response.message}</p>
              <dl>
                <div>
                  <dt>Transaction</dt>
                  <dd>{response.transaction_id}</dd>
                </div>
                <div>
                  <dt>Risk Score</dt>
                  <dd>{response.risk_score}</dd>
                </div>
                <div>
                  <dt>Fraud Detected</dt>
                  <dd>{String(response.fraud_detected)}</dd>
                </div>
              </dl>
            </>
          )}
        </section>
      </main>
    </div>
  );
}

export default App;

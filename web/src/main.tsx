import React from "react";
import ReactDOM from "react-dom/client";
import App from "./App";

// TODO: wire up the dashboard (basket composition, tracking-error chart, rebalance cost panel)
// and the agent chat panel once mcp-server's axum API exists.
ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
);

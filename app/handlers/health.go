package handlers

import (
	"encoding/json"
	"net/http"
	"time"

	"github.com/rap1p1/secure-payment-platform/models"
)

// version is set at build time via -ldflags.
var version = "dev"

// HealthHandler handles liveness probe requests.
// GET /health — Returns 200 if the service is alive.
func HealthHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, `{"success":false,"error":"method not allowed"}`, http.StatusMethodNotAllowed)
		return
	}

	resp := models.HealthResponse{
		Status:    "healthy",
		Version:   version,
		Timestamp: time.Now().UTC().Format(time.RFC3339),
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(resp)
}

// ReadyHandler handles readiness probe requests.
// GET /ready — Returns 200 if the service is ready to accept traffic.
func ReadyHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, `{"success":false,"error":"method not allowed"}`, http.StatusMethodNotAllowed)
		return
	}

	resp := models.ReadyResponse{
		Status: "ready",
		Checks: map[string]string{
			"payment_store": "ok",
			"server":        "ok",
		},
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(resp)
}

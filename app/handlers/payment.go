package handlers

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/rap1p1/secure-payment-platform/models"
)

// PaymentHandler manages payment CRUD operations with an in-memory store.
type PaymentHandler struct {
	mu       sync.RWMutex
	payments map[string]*models.Payment
	logger   *slog.Logger
}

// NewPaymentHandler creates a new PaymentHandler with an initialized store.
func NewPaymentHandler(logger *slog.Logger) *PaymentHandler {
	return &PaymentHandler{
		payments: make(map[string]*models.Payment),
		logger:   logger,
	}
}

// ServeHTTP routes payment requests based on HTTP method and path.
func (h *PaymentHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	// Route: /api/v1/payments
	// Route: /api/v1/payments/{id}
	path := strings.TrimPrefix(r.URL.Path, "/api/v1/payments")
	path = strings.TrimPrefix(path, "/")

	switch {
	case r.Method == http.MethodPost && path == "":
		h.createPayment(w, r)
	case r.Method == http.MethodGet && path == "":
		h.listPayments(w, r)
	case r.Method == http.MethodGet && path != "":
		h.getPayment(w, r, path)
	default:
		writeError(w, "method not allowed", http.StatusMethodNotAllowed)
	}
}

// createPayment handles POST /api/v1/payments
func (h *PaymentHandler) createPayment(w http.ResponseWriter, r *http.Request) {
	var req models.PaymentRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, "invalid request body: "+err.Error(), http.StatusBadRequest)
		return
	}

	if err := req.Validate(); err != nil {
		writeError(w, err.Error(), http.StatusBadRequest)
		return
	}

	// Generate unique identifiers
	paymentID := uuid.New().String()
	txnID, _ := generateTransactionID()
	now := time.Now().UTC()

	payment := &models.Payment{
		ID:            paymentID,
		Amount:        req.Amount,
		Currency:      req.Currency,
		Status:        models.StatusCompleted, // Mock: instant completion
		Description:   req.Description,
		MerchantID:    req.MerchantID,
		TransactionID: txnID,
		CreatedAt:     now,
		UpdatedAt:     now,
	}

	// Store payment
	h.mu.Lock()
	h.payments[paymentID] = payment
	h.mu.Unlock()

	h.logger.Info("payment created",
		slog.String("payment_id", paymentID),
		slog.String("transaction_id", txnID),
		slog.Float64("amount", req.Amount),
		slog.String("currency", req.Currency),
		slog.String("merchant_id", req.MerchantID),
	)

	resp := models.PaymentResponse{
		Success: true,
		Data:    payment,
	}

	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(resp)
}

// getPayment handles GET /api/v1/payments/{id}
func (h *PaymentHandler) getPayment(w http.ResponseWriter, r *http.Request, id string) {
	h.mu.RLock()
	payment, exists := h.payments[id]
	h.mu.RUnlock()

	if !exists {
		writeError(w, models.ErrPaymentNotFound.Error(), http.StatusNotFound)
		return
	}

	resp := models.PaymentResponse{
		Success: true,
		Data:    payment,
	}

	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(resp)
}

// listPayments handles GET /api/v1/payments
func (h *PaymentHandler) listPayments(w http.ResponseWriter, r *http.Request) {
	h.mu.RLock()
	payments := make([]*models.Payment, 0, len(h.payments))
	for _, p := range h.payments {
		payments = append(payments, p)
	}
	h.mu.RUnlock()

	resp := models.PaymentListResponse{
		Success: true,
		Data:    payments,
		Total:   len(payments),
	}

	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(resp)
}

// writeError sends a JSON error response.
func writeError(w http.ResponseWriter, message string, statusCode int) {
	w.WriteHeader(statusCode)
	json.NewEncoder(w).Encode(models.PaymentResponse{
		Success: false,
		Error:   message,
	})
}

// generateTransactionID creates a unique transaction ID with TXN- prefix.
func generateTransactionID() (string, error) {
	bytes := make([]byte, 8)
	if _, err := rand.Read(bytes); err != nil {
		return "", fmt.Errorf("failed to generate transaction ID: %w", err)
	}
	return "TXN-" + hex.EncodeToString(bytes), nil
}

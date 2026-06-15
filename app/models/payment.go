package models

import "time"

// PaymentStatus represents the status of a payment transaction.
type PaymentStatus string

const (
	StatusPending   PaymentStatus = "PENDING"
	StatusCompleted PaymentStatus = "COMPLETED"
	StatusFailed    PaymentStatus = "FAILED"
	StatusRefunded  PaymentStatus = "REFUNDED"
)

// Payment represents a payment transaction in the system.
type Payment struct {
	ID            string        `json:"id"`
	Amount        float64       `json:"amount"`
	Currency      string        `json:"currency"`
	Status        PaymentStatus `json:"status"`
	Description   string        `json:"description,omitempty"`
	MerchantID    string        `json:"merchant_id"`
	TransactionID string        `json:"transaction_id"`
	CreatedAt     time.Time     `json:"created_at"`
	UpdatedAt     time.Time     `json:"updated_at"`
}

// PaymentRequest represents the incoming request to create a payment.
type PaymentRequest struct {
	Amount      float64 `json:"amount"`
	Currency    string  `json:"currency"`
	Description string  `json:"description,omitempty"`
	MerchantID  string  `json:"merchant_id"`
}

// PaymentResponse wraps a payment with additional metadata.
type PaymentResponse struct {
	Success bool     `json:"success"`
	Data    *Payment `json:"data,omitempty"`
	Error   string   `json:"error,omitempty"`
}

// PaymentListResponse wraps a list of payments.
type PaymentListResponse struct {
	Success bool       `json:"success"`
	Data    []*Payment `json:"data"`
	Total   int        `json:"total"`
}

// HealthResponse represents the health check response.
type HealthResponse struct {
	Status    string `json:"status"`
	Version   string `json:"version"`
	Timestamp string `json:"timestamp"`
}

// ReadyResponse represents the readiness check response.
type ReadyResponse struct {
	Status string `json:"status"`
	Checks map[string]string `json:"checks"`
}

// Validate checks if a PaymentRequest has valid fields.
func (r *PaymentRequest) Validate() error {
	if r.Amount <= 0 {
		return ErrInvalidAmount
	}
	if r.Currency == "" {
		return ErrMissingCurrency
	}
	if r.MerchantID == "" {
		return ErrMissingMerchantID
	}
	// Validate supported currencies
	validCurrencies := map[string]bool{
		"USD": true, "EUR": true, "GBP": true, "VND": true, "JPY": true,
	}
	if !validCurrencies[r.Currency] {
		return ErrUnsupportedCurrency
	}
	return nil
}

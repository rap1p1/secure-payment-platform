package models

import "errors"

var (
	// ErrInvalidAmount is returned when the payment amount is zero or negative.
	ErrInvalidAmount = errors.New("amount must be greater than zero")

	// ErrMissingCurrency is returned when currency is not provided.
	ErrMissingCurrency = errors.New("currency is required")

	// ErrMissingMerchantID is returned when merchant_id is not provided.
	ErrMissingMerchantID = errors.New("merchant_id is required")

	// ErrUnsupportedCurrency is returned when an unsupported currency is used.
	ErrUnsupportedCurrency = errors.New("unsupported currency; supported: USD, EUR, GBP, VND, JPY")

	// ErrPaymentNotFound is returned when a payment ID does not exist.
	ErrPaymentNotFound = errors.New("payment not found")
)

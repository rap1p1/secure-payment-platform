// Package main is the entry point for the Secure Payment Platform service.
// This is a demo financial service used to showcase SLSA Level 3 supply chain security.
package main

import (
	"context"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/rap1p1/secure-payment-platform/handlers"
	"github.com/rap1p1/secure-payment-platform/middleware"
)

// Build-time variables injected via -ldflags.
var (
	version   = "dev"
	buildTime = "unknown"
	gitCommit = "unknown"
)

func main() {
	// Initialize structured JSON logger
	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: slog.LevelInfo,
	}))
	slog.SetDefault(logger)

	// Determine port from environment or default
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	// Log startup info
	logger.Info("starting secure-payment-platform",
		slog.String("version", version),
		slog.String("build_time", buildTime),
		slog.String("git_commit", gitCommit),
		slog.String("port", port),
	)

	// Initialize handlers
	paymentHandler := handlers.NewPaymentHandler(logger)

	// Setup routes
	mux := http.NewServeMux()
	mux.HandleFunc("/health", handlers.HealthHandler)
	mux.HandleFunc("/ready", handlers.ReadyHandler)
	mux.Handle("/api/v1/payments", paymentHandler)
	mux.Handle("/api/v1/payments/", paymentHandler)

	// Root endpoint - service info
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/" {
			http.NotFound(w, r)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		fmt.Fprintf(w, `{"service":"secure-payment-platform","version":"%s","docs":"/api/v1/payments"}`, version)
	})

	// Apply middleware chain: SecurityHeaders → Recovery → Logging → Handler
	var handler http.Handler = mux
	handler = middleware.Logging(logger)(handler)
	handler = middleware.Recovery(logger)(handler)
	handler = middleware.SecurityHeaders(handler)

	// Configure server with timeouts (security best practice)
	server := &http.Server{
		Addr:         ":" + port,
		Handler:      handler,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	// Graceful shutdown
	done := make(chan os.Signal, 1)
	signal.Notify(done, os.Interrupt, syscall.SIGTERM)

	go func() {
		logger.Info("server listening", slog.String("addr", server.Addr))
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			logger.Error("server failed to start", slog.Any("error", err))
			os.Exit(1)
		}
	}()

	// Wait for shutdown signal
	sig := <-done
	logger.Info("shutdown signal received", slog.String("signal", sig.String()))

	// Give active requests 30 seconds to complete
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := server.Shutdown(ctx); err != nil {
		logger.Error("server shutdown error", slog.Any("error", err))
		os.Exit(1)
	}

	logger.Info("server stopped gracefully")
}

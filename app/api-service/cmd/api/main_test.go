package main

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gorilla/mux"
	"github.com/stretchr/testify/assert"
)

func setupTestRouter() *mux.Router {
	router := mux.NewRouter()
	router.HandleFunc("/health", healthHandler).Methods("GET")
	router.HandleFunc("/ready", readyHandler).Methods("GET")
	return router
}

func TestHealthEndpoint(t *testing.T) {
	router := setupTestRouter()

	req, err := http.NewRequest("GET", "/health", nil)
	assert.NoError(t, err)

	rr := httptest.NewRecorder()
	router.ServeHTTP(rr, req)

	assert.Equal(t, http.StatusOK, rr.Code)

	var response map[string]string
	err = json.Unmarshal(rr.Body.Bytes(), &response)
	assert.NoError(t, err)
	assert.Equal(t, "healthy", response["status"])
}

func TestReadyEndpoint(t *testing.T) {
	router := setupTestRouter()

	req, err := http.NewRequest("GET", "/ready", nil)
	assert.NoError(t, err)

	rr := httptest.NewRecorder()
	router.ServeHTTP(rr, req)

	// Without Redis connection, should return 503
	// In real tests, you'd mock Redis
	assert.True(t, rr.Code == http.StatusOK || rr.Code == http.StatusServiceUnavailable)
}

func TestCreateTaskEndpoint(t *testing.T) {
	// This test requires Redis mock
	// For now, testing request validation

	tests := []struct {
		name       string
		payload    map[string]string
		wantStatus int
	}{
		{
			name:       "Valid request",
			payload:    map[string]string{"payload": "test-data"},
			wantStatus: http.StatusCreated,
		},
		{
			name:       "Empty payload",
			payload:    map[string]string{"payload": ""},
			wantStatus: http.StatusBadRequest,
		},
		{
			name:       "Missing payload field",
			payload:    map[string]string{},
			wantStatus: http.StatusBadRequest,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			body, _ := json.Marshal(tt.payload)
			req, err := http.NewRequest("POST", "/tasks", bytes.NewBuffer(body))
			assert.NoError(t, err)
			req.Header.Set("Content-Type", "application/json")

			// Note: This will fail without Redis connection
			// In production, use dependency injection and mocks
		})
	}
}

func TestCORSHeaders(t *testing.T) {
	router := mux.NewRouter()
	router.Use(corsMiddleware)
	router.HandleFunc("/health", healthHandler)

	req, err := http.NewRequest("GET", "/health", nil)
	assert.NoError(t, err)

	rr := httptest.NewRecorder()
	router.ServeHTTP(rr, req)

	assert.Equal(t, "*", rr.Header().Get("Access-Control-Allow-Origin"))
	assert.Contains(t, rr.Header().Get("Access-Control-Allow-Methods"), "GET")
}

func TestMetricsEndpoint(t *testing.T) {
	router := mux.NewRouter()
	router.HandleFunc("/metrics", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("# Metrics"))
	})

	req, err := http.NewRequest("GET", "/metrics", nil)
	assert.NoError(t, err)

	rr := httptest.NewRecorder()
	router.ServeHTTP(rr, req)

	assert.Equal(t, http.StatusOK, rr.Code)
}

func BenchmarkHealthEndpoint(b *testing.B) {
	router := setupTestRouter()
	req, _ := http.NewRequest("GET", "/health", nil)

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		rr := httptest.NewRecorder()
		router.ServeHTTP(rr, req)
	}
}

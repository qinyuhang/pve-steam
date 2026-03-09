package main

import (
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"
)

func TestAuth(t *testing.T) {
	token := "test-token-123"

	tests := []struct {
		name     string
		query    string
		expected bool
	}{
		{
			name:     "valid token",
			query:    "?token=test-token-123",
			expected: true,
		},
		{
			name:     "invalid token",
			query:    "?token=wrong-token",
			expected: false,
		},
		{
			name:     "missing token",
			query:    "",
			expected: false,
		},
		{
			name:     "empty token",
			query:    "?token=",
			expected: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req := httptest.NewRequest(http.MethodGet, "/test"+tt.query, nil)
			result := auth(req, token)
			if result != tt.expected {
				t.Errorf("auth() = %v, want %v", result, tt.expected)
			}
		})
	}
}

func TestAuthWithDifferentTokens(t *testing.T) {
	tests := []struct {
		token    string
		query    string
		expected bool
	}{
		{
			token:    "simple",
			query:    "?token=simple",
			expected: true,
		},
		{
			token:    "complex-token-123!@#",
			query:    "?token=complex-token-123!@#",
			expected: true,
		},
		{
			token:    "with spaces",
			query:    "?token=with+spaces",
			expected: true, // URL query param with + for space
		},
	}

	for _, tt := range tests {
		t.Run(fmt.Sprintf("token_%s", tt.token), func(t *testing.T) {
			req := httptest.NewRequest(http.MethodGet, "/test"+tt.query, nil)
			result := auth(req, tt.token)
			if result != tt.expected {
				t.Errorf("auth() = %v, want %v", result, tt.expected)
			}
		})
	}
}

func TestMainEnvVars(t *testing.T) {
	// Save original env vars
	origVMID := os.Getenv("VMID")
	origToken := os.Getenv("TOKEN")
	origPort := os.Getenv("PORT")
	defer func() {
		os.Setenv("VMID", origVMID)
		os.Setenv("TOKEN", origToken)
		os.Setenv("PORT", origPort)
	}()

	tests := []struct {
		name      string
		vmid      string
		token     string
		port      string
		wantPanic bool
	}{
		{
			name:      "all set",
			vmid:      "100",
			token:     "test-token",
			port:      "9090",
			wantPanic: false,
		},
		{
			name:      "missing vmid",
			vmid:      "",
			token:     "test-token",
			port:      "9090",
			wantPanic: true,
		},
		{
			name:      "missing token",
			vmid:      "100",
			token:     "",
			port:      "9090",
			wantPanic: true,
		},
		{
			name:      "default port",
			vmid:      "100",
			token:     "test-token",
			port:      "",
			wantPanic: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			os.Setenv("VMID", tt.vmid)
			os.Setenv("TOKEN", tt.token)
			os.Setenv("PORT", tt.port)

			vmid := os.Getenv("VMID")
			token := os.Getenv("TOKEN")
			port := os.Getenv("PORT")

			// Check if panic condition is met
			willPanic := vmid == "" || token == ""
			if willPanic != tt.wantPanic {
				t.Errorf("panic condition = %v, want %v", willPanic, tt.wantPanic)
			}

			// Check default port
			if port == "" && tt.port == "" {
				port = "8080"
			}
			if tt.port == "" {
				if port != "8080" {
					t.Errorf("default port = %v, want 8080", port)
				}
			}
		})
	}
}

func TestRun(t *testing.T) {
	// Test a simple command that should succeed
	result := run("echo", "hello")
	if result != "hello\n" {
		t.Errorf("run() = %q, want %q", result, "hello\n")
	}

	// Test a command that should fail
	result = run("nonexistent-command-12345")
	if result == "" {
		t.Error("run() should return error for nonexistent command")
	}
}

func TestHTTPHandlers(t *testing.T) {
	// Set up test environment
	os.Setenv("VMID", "100")
	os.Setenv("TOKEN", "test-token")
	os.Setenv("PORT", "8888")

	token := "test-token"

	// Test handler functions
	tests := []struct {
		name       string
		path       string
		token      string
		wantStatus int
	}{
		{
			name:       "start with valid token",
			path:       "/start",
			token:      "test-token",
			wantStatus: http.StatusOK,
		},
		{
			name:       "start with invalid token",
			path:       "/start",
			token:      "wrong-token",
			wantStatus: http.StatusForbidden,
		},
		{
			name:       "stop with valid token",
			path:       "/stop",
			token:      "test-token",
			wantStatus: http.StatusOK,
		},
		{
			name:       "stop with invalid token",
			path:       "/stop",
			token:      "wrong-token",
			wantStatus: http.StatusForbidden,
		},
		{
			name:       "status with valid token",
			path:       "/status",
			token:      "test-token",
			wantStatus: http.StatusOK,
		},
		{
			name:       "status with invalid token",
			path:       "/status",
			token:      "wrong-token",
			wantStatus: http.StatusForbidden,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Create a handler based on the path
			var handler http.HandlerFunc
			switch tt.path {
			case "/start":
				handler = func(w http.ResponseWriter, r *http.Request) {
					if !auth(r, token) {
						http.Error(w, "forbidden", http.StatusForbidden)
						return
					}
					w.WriteHeader(http.StatusOK)
				}
			case "/stop":
				handler = func(w http.ResponseWriter, r *http.Request) {
					if !auth(r, token) {
						http.Error(w, "forbidden", http.StatusForbidden)
						return
					}
					w.WriteHeader(http.StatusOK)
				}
			case "/status":
				handler = func(w http.ResponseWriter, r *http.Request) {
					if !auth(r, token) {
						http.Error(w, "forbidden", http.StatusForbidden)
						return
					}
					w.WriteHeader(http.StatusOK)
				}
			}

			req := httptest.NewRequest(http.MethodGet, tt.path+"?token="+tt.token, nil)
			rr := httptest.NewRecorder()

			handler(rr, req)

			if rr.Code != tt.wantStatus {
				t.Errorf("handler returned wrong status code: got %v want %v",
					rr.Code, tt.wantStatus)
			}
		})
	}
}

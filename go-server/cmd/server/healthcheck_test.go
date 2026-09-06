package main

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestCheckHealth(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))
	defer server.Close()

	if err := checkHealth(server.Client(), server.URL); err != nil {
		t.Fatalf("checkHealth() error = %v", err)
	}
}

func TestCheckHealthRejectsNonSuccess(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusServiceUnavailable)
	}))
	defer server.Close()

	if err := checkHealth(server.Client(), server.URL); err == nil {
		t.Fatal("checkHealth() succeeded for an unhealthy server")
	}
}

package handler

import "net/http"

// notImplemented is a placeholder for endpoints whose full service logic is pending.
// Once oapi-codegen is run against api/openapi.yaml, handlers will implement the
// generated ServerInterface; this stub keeps the route table shape visible in the meantime.
func NotImplemented(w http.ResponseWriter, r *http.Request) {
	http.Error(w, "not implemented", http.StatusNotImplemented)
}

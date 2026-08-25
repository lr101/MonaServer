package handler

import (
	"testing"

	"github.com/lrprojects/monaserver/internal/apperrors"
)

func TestServiceErrorResponsesUsePlainTextBody(t *testing.T) {
	resp := serviceErrResp(apperrors.New(409, "already exists"))
	body, ok := resp.Body.([]byte)
	if !ok {
		t.Fatalf("error body type = %T, want []byte", resp.Body)
	}
	if string(body) != "already exists" {
		t.Fatalf("error body = %q", body)
	}
}

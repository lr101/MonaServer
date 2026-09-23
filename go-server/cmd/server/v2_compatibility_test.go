package main

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/google/uuid"

	genapi "github.com/lrprojects/monaserver/internal/gen/api"
	genserver "github.com/lrprojects/monaserver/internal/gen/server"
)

type v2CompatibilityAuthServicer struct {
	genserver.AuthAPIServicer
	loginRequest   genserver.UserLoginRequest
	signupRequest  genserver.UserRequestDto
	refreshRequest genserver.RefreshTokenRequestDto
	loginStatus    int
}

func (s *v2CompatibilityAuthServicer) UserLogin(_ context.Context, request genserver.UserLoginRequest) (genserver.ImplResponse, error) {
	s.loginRequest = request
	if s.loginStatus != 0 {
		return genserver.Response(s.loginStatus, nil), nil
	}
	return genserver.Response(http.StatusOK, genserver.TokenResponseDto{
		AccessToken:  "legacy-access-token",
		RefreshToken: "7f6f5cc4-3f09-4a6d-8e6d-3f2ab5c7f3d1",
		UserId:       "7f6f5cc4-3f09-4a6d-8e6d-3f2ab5c7f3d1",
	}), nil
}

func (s *v2CompatibilityAuthServicer) CreateUser(_ context.Context, request genserver.UserRequestDto) (genserver.ImplResponse, error) {
	s.signupRequest = request
	return genserver.Response(http.StatusCreated, genserver.TokenResponseDto{
		AccessToken:  "legacy-signup-access-token",
		RefreshToken: "3d3f3a6f-7a1d-4c77-99b4-f8b4f6db18c3",
		UserId:       "3d3f3a6f-7a1d-4c77-99b4-f8b4f6db18c3",
	}), nil
}

func (s *v2CompatibilityAuthServicer) RefreshToken(_ context.Context, request genserver.RefreshTokenRequestDto) (genserver.ImplResponse, error) {
	s.refreshRequest = request
	return genserver.Response(http.StatusOK, genserver.TokenResponseDto{
		AccessToken:  "legacy-refreshed-access-token",
		RefreshToken: request.RefreshToken,
		UserId:       request.UserId,
	}), nil
}

func TestV2LoginFixtureUsesRegeneratedPayloadAndTokenShape(t *testing.T) {
	username := "alice"
	password := "correct-horse"
	clientPayload := genapi.UserLoginJSONRequestBody{Username: &username, Password: &password}
	payload, err := json.Marshal(clientPayload)
	if err != nil {
		t.Fatalf("marshal generated v2 login payload: %v", err)
	}

	servicer := &v2CompatibilityAuthServicer{}
	controller := genserver.NewAuthAPIController(servicer)
	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodPost, "/api/v2/public/login", strings.NewReader(string(payload)))
	controller.UserLogin(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("v2 login status = %d, want 200", recorder.Code)
	}
	if servicer.loginRequest.Username != username || servicer.loginRequest.Password != password {
		t.Fatalf("v2 login request = %#v, want username/password fixture", servicer.loginRequest)
	}
	var response genapi.TokenResponseDto
	if err := json.NewDecoder(recorder.Body).Decode(&response); err != nil {
		t.Fatalf("decode generated v2 token response: %v", err)
	}
	if response.AccessToken != "legacy-access-token" || response.UserId != uuid.MustParse("7f6f5cc4-3f09-4a6d-8e6d-3f2ab5c7f3d1") {
		t.Fatalf("v2 token response = %#v, want retained token fields", response)
	}
}

func TestV2SignupFixtureRetainsCreatedStatusAndFields(t *testing.T) {
	clientPayload := genapi.CreateUserJSONRequestBody{
		Name:     "alice",
		Email:    "alice@example.com",
		Password: "correct-horse",
	}
	payload, err := json.Marshal(clientPayload)
	if err != nil {
		t.Fatalf("marshal generated v2 signup payload: %v", err)
	}

	servicer := &v2CompatibilityAuthServicer{}
	controller := genserver.NewAuthAPIController(servicer)
	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodPost, "/api/v2/public/signup", strings.NewReader(string(payload)))
	controller.CreateUser(recorder, request)

	if recorder.Code != http.StatusCreated {
		t.Fatalf("v2 signup status = %d, want 201", recorder.Code)
	}
	if servicer.signupRequest.Name != "alice" || servicer.signupRequest.Email != "alice@example.com" || servicer.signupRequest.Password != "correct-horse" {
		t.Fatalf("v2 signup request = %#v, want retained fields", servicer.signupRequest)
	}
	var response genapi.TokenResponseDto
	if err := json.NewDecoder(recorder.Body).Decode(&response); err != nil {
		t.Fatalf("decode generated v2 signup token response: %v", err)
	}
	if response.AccessToken != "legacy-signup-access-token" {
		t.Fatalf("signup access token = %q, want legacy-signup-access-token", response.AccessToken)
	}
}

func TestV2RefreshFixtureRetainsStatusAndUUIDFields(t *testing.T) {
	refreshToken := uuid.MustParse("7f6f5cc4-3f09-4a6d-8e6d-3f2ab5c7f3d1")
	userID := uuid.MustParse("3d3f3a6f-7a1d-4c77-99b4-f8b4f6db18c3")
	clientPayload := genapi.RefreshTokenJSONRequestBody{RefreshToken: &refreshToken, UserId: &userID}
	payload, err := json.Marshal(clientPayload)
	if err != nil {
		t.Fatalf("marshal generated v2 refresh payload: %v", err)
	}

	servicer := &v2CompatibilityAuthServicer{}
	controller := genserver.NewAuthAPIController(servicer)
	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodPost, "/api/v2/public/refresh", strings.NewReader(string(payload)))
	controller.RefreshToken(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("v2 refresh status = %d, want retained runtime status 200", recorder.Code)
	}
	if servicer.refreshRequest.RefreshToken != refreshToken.String() || servicer.refreshRequest.UserId != userID.String() {
		t.Fatalf("v2 refresh request = %#v, want UUID strings", servicer.refreshRequest)
	}
	var response genapi.TokenResponseDto
	if err := json.NewDecoder(recorder.Body).Decode(&response); err != nil {
		t.Fatalf("decode generated v2 refresh token response: %v", err)
	}
	if response.RefreshToken != refreshToken || response.UserId != userID {
		t.Fatalf("v2 refresh response = %#v, want UUID fields", response)
	}
}

func TestV2LoginErrorFixtureRetainsLegacyErrorEnvelope(t *testing.T) {
	username := "alice"
	password := "wrong-password"
	clientPayload := genapi.UserLoginJSONRequestBody{Username: &username, Password: &password}
	payload, err := json.Marshal(clientPayload)
	if err != nil {
		t.Fatalf("marshal generated v2 login error payload: %v", err)
	}

	servicer := &v2CompatibilityAuthServicer{loginStatus: http.StatusBadRequest}
	controller := genserver.NewAuthAPIController(servicer)
	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodPost, "/api/v2/public/login", strings.NewReader(string(payload)))
	controller.UserLogin(recorder, request)

	if recorder.Code != http.StatusBadRequest {
		t.Fatalf("v2 login error status = %d, want 400", recorder.Code)
	}
	var response map[string]string
	if err := json.NewDecoder(recorder.Body).Decode(&response); err != nil {
		t.Fatalf("decode generated v2 error response: %v", err)
	}
	if response["error"] != http.StatusText(http.StatusBadRequest) {
		t.Fatalf("v2 error response = %#v, want legacy error envelope", response)
	}
}

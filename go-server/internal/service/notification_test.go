package service

import "testing"

func TestFirebaseOptionsUseApplicationDefaultCredentialsWithoutPath(t *testing.T) {
	if got := firebaseOptions(""); len(got) != 0 {
		t.Fatalf("empty config path produced %d explicit credential options, want ADC", len(got))
	}
	if got := firebaseOptions("service-account.json"); len(got) != 1 {
		t.Fatalf("credential path produced %d options, want 1", len(got))
	}
}

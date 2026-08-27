package password

import (
	"crypto/sha256"
	"encoding/hex"
	"strings"
	"testing"

	"golang.org/x/crypto/bcrypt"
)

func TestHashAndVerify(t *testing.T) {
	h, err := Hash("secret123")
	if err != nil {
		t.Fatal(err)
	}
	if !Verify(h, "secret123") {
		t.Fatal("verify should succeed")
	}
	if Verify(h, "wrong") {
		t.Fatal("verify should fail for wrong password")
	}
}

func TestHashUsesTaggedBcryptFormat(t *testing.T) {
	h, err := Hash("secret123")
	if err != nil {
		t.Fatal(err)
	}
	if !strings.HasPrefix(h, "{bcrypt}$2") {
		t.Fatalf("hash %q does not use the tagged bcrypt format", h)
	}
}

func TestVerifyAcceptsTaggedBcryptHash(t *testing.T) {
	raw, err := bcrypt.GenerateFromPassword([]byte("secret123"), bcrypt.MinCost)
	if err != nil {
		t.Fatal(err)
	}
	if !Verify("{bcrypt}"+string(raw), "secret123") {
		t.Fatal("tagged bcrypt hash should verify")
	}
	if Verify("{bcrypt}"+string(raw), "wrong") {
		t.Fatal("tagged bcrypt hash should reject a wrong password")
	}
}

func TestVerifyAcceptsLegacyUnsaltedSHA256Hash(t *testing.T) {
	sum := sha256.Sum256([]byte("secret123"))
	legacy := hex.EncodeToString(sum[:])
	if !Verify(legacy, "secret123") {
		t.Fatal("legacy SHA-256 hash should verify")
	}
	if Verify(legacy, "wrong") {
		t.Fatal("legacy SHA-256 hash should reject a wrong password")
	}
}

func TestVerifyKeepsAcceptingRawGoBcryptHashes(t *testing.T) {
	raw, err := bcrypt.GenerateFromPassword([]byte("secret123"), bcrypt.MinCost)
	if err != nil {
		t.Fatal(err)
	}
	if !Verify(string(raw), "secret123") {
		t.Fatal("raw bcrypt hashes created by the previous Go server should still verify")
	}
}

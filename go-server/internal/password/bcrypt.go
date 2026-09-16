package password

import (
	"crypto/sha256"
	"crypto/subtle"
	"encoding/hex"
	"strings"

	"golang.org/x/crypto/bcrypt"
)

const bcryptPrefix = "{bcrypt}"

// bcrypt accepts at most 72 input bytes. Password API contracts may allow a
// longer UTF-8 string, so long inputs are domain-separated and reduced to a
// fixed digest before bcrypt. The same preparation is applied on verify;
// short passwords continue to use their original bytes and remain wire
// compatible with existing hashes.
const longPasswordDomain = "monaserver:bcrypt-long-password:v1:"

func bcryptInput(plain string) []byte {
	input := []byte(plain)
	if len(input) <= 72 {
		return input
	}
	digest := sha256.Sum256(input)
	prepared := make([]byte, 0, len(longPasswordDomain)+len(digest))
	prepared = append(prepared, longPasswordDomain...)
	prepared = append(prepared, digest[:]...)
	return prepared
}

func Hash(plain string) (string, error) {
	b, err := bcrypt.GenerateFromPassword(bcryptInput(plain), bcrypt.DefaultCost)
	if err != nil {
		return "", err
	}
	return bcryptPrefix + string(b), nil
}

func Verify(hash, plain string) bool {
	switch {
	case strings.HasPrefix(hash, bcryptPrefix):
		return bcrypt.CompareHashAndPassword([]byte(strings.TrimPrefix(hash, bcryptPrefix)), bcryptInput(plain)) == nil
	case strings.HasPrefix(hash, "$2"):
		return bcrypt.CompareHashAndPassword([]byte(hash), bcryptInput(plain)) == nil
	case strings.HasPrefix(hash, "{"):
		return false
	default:
		sum := sha256.Sum256([]byte(plain))
		encoded := hex.EncodeToString(sum[:])
		return len(hash) == len(encoded) && subtle.ConstantTimeCompare([]byte(hash), []byte(encoded)) == 1
	}
}

func NeedsUpgrade(hash string) bool {
	return !strings.HasPrefix(hash, bcryptPrefix)
}

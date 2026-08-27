package password

import (
	"crypto/sha256"
	"crypto/subtle"
	"encoding/hex"
	"strings"

	"golang.org/x/crypto/bcrypt"
)

const bcryptPrefix = "{bcrypt}"

func Hash(plain string) (string, error) {
	b, err := bcrypt.GenerateFromPassword([]byte(plain), bcrypt.DefaultCost)
	if err != nil {
		return "", err
	}
	return bcryptPrefix + string(b), nil
}

func Verify(hash, plain string) bool {
	switch {
	case strings.HasPrefix(hash, bcryptPrefix):
		return bcrypt.CompareHashAndPassword([]byte(strings.TrimPrefix(hash, bcryptPrefix)), []byte(plain)) == nil
	case strings.HasPrefix(hash, "$2"):
		return bcrypt.CompareHashAndPassword([]byte(hash), []byte(plain)) == nil
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

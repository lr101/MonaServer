package service

import (
	"crypto/aes"
	"crypto/cipher"
	cryptorand "crypto/rand"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"strings"
	"sync"
	"time"
)

var (
	ErrDeliveryKeyUnavailable = errors.New("delivery encryption key unavailable")
	ErrInvalidDeliveryPayload = errors.New("invalid encrypted delivery payload")
	ErrDeliveryPayloadExpired = errors.New("encrypted delivery payload expired")
	ErrDeliveryTTLTooLong     = errors.New("encrypted delivery payload TTL too long")
)

const defaultDeliveryPayloadTTL = 15 * time.Minute

// EncryptedDeliveryPayload is the only form of a short-lived delivery
// payload that may be persisted.  Ciphertext is nonce-prefixed AES-GCM data;
// KeyID is a lookup label and never contains key material.
type EncryptedDeliveryPayload struct {
	Ciphertext []byte    `json:"ciphertext"`
	KeyID      string    `json:"keyId"`
	ExpiresAt  time.Time `json:"expiresAt"`
}

// DeliveryKeyRing keeps the active key for new payloads and retained keys for
// decrypting attempts created before a rotation. Removing an old key causes
// decryption to fail closed, which is preferable to guessing or sending a
// payload with unknown provenance.
type DeliveryKeyRing struct {
	mu       sync.RWMutex
	keys     map[string][]byte
	activeID string
	maxTTL   time.Duration
}

// NewDeliveryKeyRing validates all configured AES keys and the active key.
// A 32-byte key is required so deployments do not accidentally configure a
// weak or truncated delivery secret.
func NewDeliveryKeyRing(keys map[string][]byte, activeID string, maxTTL time.Duration) (*DeliveryKeyRing, error) {
	if maxTTL <= 0 {
		maxTTL = defaultDeliveryPayloadTTL
	}
	activeID = strings.TrimSpace(activeID)
	if activeID == "" {
		return nil, ErrDeliveryKeyUnavailable
	}
	ring := &DeliveryKeyRing{keys: make(map[string][]byte, len(keys)), activeID: activeID, maxTTL: maxTTL}
	for id, key := range keys {
		if err := validateDeliveryKey(id, key); err != nil {
			return nil, err
		}
		ring.keys[id] = append([]byte(nil), key...)
	}
	if _, ok := ring.keys[activeID]; !ok {
		return nil, ErrDeliveryKeyUnavailable
	}
	return ring, nil
}

func validateDeliveryKey(id string, key []byte) error {
	if strings.TrimSpace(id) == "" || len(key) != 32 {
		return ErrDeliveryKeyUnavailable
	}
	if _, err := aes.NewCipher(key); err != nil {
		return fmt.Errorf("%w: %v", ErrDeliveryKeyUnavailable, err)
	}
	return nil
}

// AddKey installs a retained key. It does not make the key active until
// SetActiveKey succeeds, allowing rotation to be staged safely.
func (r *DeliveryKeyRing) AddKey(id string, key []byte) error {
	if r == nil {
		return ErrDeliveryKeyUnavailable
	}
	if err := validateDeliveryKey(id, key); err != nil {
		return err
	}
	r.mu.Lock()
	r.keys[strings.TrimSpace(id)] = append([]byte(nil), key...)
	r.mu.Unlock()
	return nil
}

func (r *DeliveryKeyRing) SetActiveKey(id string) error {
	if r == nil {
		return ErrDeliveryKeyUnavailable
	}
	id = strings.TrimSpace(id)
	r.mu.Lock()
	defer r.mu.Unlock()
	if _, ok := r.keys[id]; !ok {
		return ErrDeliveryKeyUnavailable
	}
	r.activeID = id
	return nil
}

func (r *DeliveryKeyRing) RemoveKey(id string) error {
	if r == nil {
		return ErrDeliveryKeyUnavailable
	}
	r.mu.Lock()
	defer r.mu.Unlock()
	if strings.TrimSpace(id) == r.activeID {
		return ErrDeliveryKeyUnavailable
	}
	delete(r.keys, strings.TrimSpace(id))
	return nil
}

// EncryptPayload seals plaintext for one delivery attempt. The expiry is
// stored outside ciphertext for efficient DB retention and checked again on
// decryption. TTL cannot exceed the configured short-lived maximum.
func (r *DeliveryKeyRing) EncryptPayload(plaintext []byte, now time.Time, ttl time.Duration) (EncryptedDeliveryPayload, error) {
	if r == nil || len(plaintext) == 0 || now.IsZero() {
		return EncryptedDeliveryPayload{}, ErrInvalidDeliveryPayload
	}
	if ttl <= 0 {
		ttl = defaultDeliveryPayloadTTL
	}
	r.mu.RLock()
	keyID := r.activeID
	key := append([]byte(nil), r.keys[keyID]...)
	maxTTL := r.maxTTL
	r.mu.RUnlock()
	if len(key) == 0 || keyID == "" {
		return EncryptedDeliveryPayload{}, ErrDeliveryKeyUnavailable
	}
	if ttl > maxTTL {
		return EncryptedDeliveryPayload{}, ErrDeliveryTTLTooLong
	}
	block, err := aes.NewCipher(key)
	if err != nil {
		return EncryptedDeliveryPayload{}, ErrDeliveryKeyUnavailable
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return EncryptedDeliveryPayload{}, ErrDeliveryKeyUnavailable
	}
	nonce := make([]byte, gcm.NonceSize())
	if _, err := io.ReadFull(cryptorand.Reader, nonce); err != nil {
		return EncryptedDeliveryPayload{}, fmt.Errorf("generate delivery nonce: %w", err)
	}
	sealed := gcm.Seal(nonce, nonce, plaintext, []byte(keyID))
	return EncryptedDeliveryPayload{Ciphertext: sealed, KeyID: keyID, ExpiresAt: now.Add(ttl)}, nil
}

func (r *DeliveryKeyRing) DecryptPayload(envelope EncryptedDeliveryPayload, now time.Time) ([]byte, error) {
	if r == nil || len(envelope.Ciphertext) == 0 || strings.TrimSpace(envelope.KeyID) == "" || now.IsZero() || envelope.ExpiresAt.IsZero() {
		return nil, ErrInvalidDeliveryPayload
	}
	if !now.Before(envelope.ExpiresAt) {
		return nil, ErrDeliveryPayloadExpired
	}
	r.mu.RLock()
	key := append([]byte(nil), r.keys[envelope.KeyID]...)
	r.mu.RUnlock()
	if len(key) == 0 {
		return nil, ErrDeliveryKeyUnavailable
	}
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, ErrDeliveryKeyUnavailable
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil || len(envelope.Ciphertext) < gcm.NonceSize()+gcm.Overhead() {
		return nil, ErrInvalidDeliveryPayload
	}
	nonce, ciphertext := envelope.Ciphertext[:gcm.NonceSize()], envelope.Ciphertext[gcm.NonceSize():]
	plaintext, err := gcm.Open(nil, nonce, ciphertext, []byte(envelope.KeyID))
	if err != nil {
		return nil, ErrInvalidDeliveryPayload
	}
	return plaintext, nil
}

func MarshalEncryptedDeliveryPayload(payload EncryptedDeliveryPayload) ([]byte, error) {
	if len(payload.Ciphertext) == 0 || strings.TrimSpace(payload.KeyID) == "" || payload.ExpiresAt.IsZero() {
		return nil, ErrInvalidDeliveryPayload
	}
	return json.Marshal(payload)
}

func UnmarshalEncryptedDeliveryPayload(raw []byte) (EncryptedDeliveryPayload, error) {
	var payload EncryptedDeliveryPayload
	if len(raw) == 0 || json.Unmarshal(raw, &payload) != nil || len(payload.Ciphertext) == 0 || strings.TrimSpace(payload.KeyID) == "" || payload.ExpiresAt.IsZero() {
		return EncryptedDeliveryPayload{}, ErrInvalidDeliveryPayload
	}
	return payload, nil
}

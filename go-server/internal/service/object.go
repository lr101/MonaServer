package service

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"time"

	"github.com/google/uuid"
	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
)

// Object wraps MinIO with the bucket layout used by the Kotlin ObjectServiceImpl:
//
//	pins/{id}.png
//	groups/{id}/group_pin.png
//	groups/{id}/group_profile.png
//	groups/{id}/group_profile_small.png
//	users/{id}/profile.png
//	users/{id}/profile_small.png
type Object struct {
	client        *minio.Client // internal endpoint — used for all API operations
	presignClient *minio.Client // external endpoint — used only for PresignedGetObject
	bucket        string
	urlExpiry     time.Duration
}

// NewObject creates an Object service.
// endpoint is the internal S3 address used for API calls (e.g. "rustfs:9000").
// externalEndpoint is the address clients will use to download presigned URLs
// (e.g. "10.0.2.2:9000"). When empty, endpoint is used for both.
// Using separate clients ensures the presigned URL's Host and its HMAC signature
// are both computed over the external address, so the signature remains valid
// when the client actually fetches the URL.
func NewObject(endpoint, externalEndpoint, accessKey, secretKey, bucket string, useSSL bool, urlExpiry time.Duration) (*Object, error) {
	opts := &minio.Options{
		Creds:  credentials.NewStaticV4(accessKey, secretKey, ""),
		Secure: useSSL,
		// Region must be set to prevent minio-go from calling GetBucketLocation on
		// every presign operation. Without it, each PresignedGetObject triggers an
		// HTTP round-trip to the endpoint — the external endpoint is reachable by
		// mobile clients but not from inside the Docker network, causing a 30-second
		// TCP timeout per call.
		Region: "us-east-1",
	}
	client, err := minio.New(endpoint, opts)
	if err != nil {
		return nil, err
	}
	extEndpoint := externalEndpoint
	if extEndpoint == "" {
		extEndpoint = endpoint
	}
	presignClient, err := minio.New(extEndpoint, opts)
	if err != nil {
		return nil, err
	}
	return &Object{client: client, presignClient: presignClient, bucket: bucket, urlExpiry: urlExpiry}, nil
}

// EnsureBucket creates the bucket if absent (idempotent).
func (o *Object) EnsureBucket(ctx context.Context) error {
	ok, err := o.client.BucketExists(ctx, o.bucket)
	if err != nil {
		return err
	}
	if ok {
		return nil
	}
	return o.client.MakeBucket(ctx, o.bucket, minio.MakeBucketOptions{})
}

func (o *Object) Put(ctx context.Context, key string, data []byte, contentType string) error {
	_, err := o.client.PutObject(ctx, o.bucket, key, bytes.NewReader(data), int64(len(data)),
		minio.PutObjectOptions{ContentType: contentType})
	return err
}

func (o *Object) Get(ctx context.Context, key string) ([]byte, error) {
	obj, err := o.client.GetObject(ctx, o.bucket, key, minio.GetObjectOptions{})
	if err != nil {
		return nil, err
	}
	defer obj.Close()
	return io.ReadAll(obj)
}

// GetIfExists reads an object while treating a missing key as normal state.
func (o *Object) GetIfExists(ctx context.Context, key string) ([]byte, bool, error) {
	if _, err := o.client.StatObject(ctx, o.bucket, key, minio.StatObjectOptions{}); err != nil {
		switch minio.ToErrorResponse(err).Code {
		case "NoSuchKey", "NoSuchObject", "NotFound":
			return nil, false, nil
		default:
			return nil, false, err
		}
	}
	data, err := o.Get(ctx, key)
	if err != nil {
		return nil, false, err
	}
	return data, true, nil
}

func (o *Object) Remove(ctx context.Context, key string) error {
	return o.client.RemoveObject(ctx, o.bucket, key, minio.RemoveObjectOptions{})
}

// PresignedGet returns a time-limited presigned URL for the object.
// URL generation is pure local HMAC computation — no network call is made.
// If the object does not exist in RustFS the URL will 404 when the client fetches it.
// The external client is used so the Host in the signature matches what the caller sees.
func (o *Object) PresignedGet(ctx context.Context, key string) (string, error) {
	u, err := o.presignClient.PresignedGetObject(ctx, o.bucket, key, o.urlExpiry, nil)
	if err != nil {
		return "", err
	}
	return u.String(), nil
}

// PinKey returns pins/{id}.png.
func PinKey(id uuid.UUID) string { return fmt.Sprintf("pins/%s.png", id) }

// GroupPinKey returns groups/{id}/group_pin.png.
func GroupPinKey(id uuid.UUID) string { return fmt.Sprintf("groups/%s/group_pin.png", id) }

// GroupProfileKey returns groups/{id}/group_profile.png (or _small).
func GroupProfileKey(id uuid.UUID, small bool) string {
	if small {
		return fmt.Sprintf("groups/%s/group_profile_small.png", id)
	}
	return fmt.Sprintf("groups/%s/group_profile.png", id)
}

// UserProfileKey returns users/{id}/profile.png (or _small).
func UserProfileKey(id uuid.UUID, small bool) string {
	if small {
		return fmt.Sprintf("users/%s/profile_small.png", id)
	}
	return fmt.Sprintf("users/%s/profile.png", id)
}

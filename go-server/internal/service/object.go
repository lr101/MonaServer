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
//   pins/{id}.png
//   groups/{id}/group_pin.png
//   groups/{id}/group_profile.png
//   groups/{id}/group_profile_small.png
//   users/{id}/profile.png
//   users/{id}/profile_small.png
type Object struct {
	client     *minio.Client
	bucket     string
	urlExpiry  time.Duration
}

func NewObject(endpoint, accessKey, secretKey, bucket string, useSSL bool, urlExpiry time.Duration) (*Object, error) {
	c, err := minio.New(endpoint, &minio.Options{
		Creds:  credentials.NewStaticV4(accessKey, secretKey, ""),
		Secure: useSSL,
	})
	if err != nil {
		return nil, err
	}
	return &Object{client: c, bucket: bucket, urlExpiry: urlExpiry}, nil
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

func (o *Object) Remove(ctx context.Context, key string) error {
	return o.client.RemoveObject(ctx, o.bucket, key, minio.RemoveObjectOptions{})
}

// PresignedGet returns a time-limited URL to download the object. Empty string
// if the object does not exist.
func (o *Object) PresignedGet(ctx context.Context, key string) (string, error) {
	_, err := o.client.StatObject(ctx, o.bucket, key, minio.StatObjectOptions{})
	if err != nil {
		return "", nil
	}
	u, err := o.client.PresignedGetObject(ctx, o.bucket, key, o.urlExpiry, nil)
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

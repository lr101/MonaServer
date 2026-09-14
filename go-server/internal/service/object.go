package service

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/aws/smithy-go"
	smithyhttp "github.com/aws/smithy-go/transport/http"
	"github.com/google/uuid"
)

// Object wraps the S3-compatible object service with the bucket layout used by
// the Kotlin ObjectServiceImpl:
//
//	pins/{id}.png
//	groups/{id}/group_pin.png
//	groups/{id}/group_profile.png
//	groups/{id}/group_profile_small.png
//	users/{id}/profile.png
//	users/{id}/profile_small.png
type Object struct {
	client        *s3.Client        // internal endpoint — used for all API operations
	presignClient *s3.PresignClient // external endpoint — used only for presigned URLs
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
	client, err := newS3Client(endpoint, accessKey, secretKey, useSSL)
	if err != nil {
		return nil, err
	}
	extEndpoint := externalEndpoint
	if extEndpoint == "" {
		extEndpoint = endpoint
	}
	presignS3Client, err := newS3Client(extEndpoint, accessKey, secretKey, useSSL)
	if err != nil {
		return nil, err
	}
	return &Object{
		client:        client,
		presignClient: s3.NewPresignClient(presignS3Client),
		bucket:        bucket,
		urlExpiry:     urlExpiry,
	}, nil
}

func newS3Client(endpoint, accessKey, secretKey string, useSSL bool) (*s3.Client, error) {
	cfg, err := config.LoadDefaultConfig(context.Background(),
		config.WithRegion("us-east-1"),
		config.WithCredentialsProvider(credentials.NewStaticCredentialsProvider(accessKey, secretKey, "")),
	)
	if err != nil {
		return nil, err
	}
	return s3.NewFromConfig(cfg, func(options *s3.Options) {
		options.BaseEndpoint = aws.String(s3EndpointURL(endpoint, useSSL))
		options.UsePathStyle = true
	}), nil
}

func s3EndpointURL(endpoint string, useSSL bool) string {
	if strings.HasPrefix(endpoint, "http://") || strings.HasPrefix(endpoint, "https://") {
		return endpoint
	}
	scheme := "http"
	if useSSL {
		scheme = "https"
	}
	return scheme + "://" + endpoint
}

// EnsureBucket creates the bucket if absent (idempotent).
func (o *Object) EnsureBucket(ctx context.Context) error {
	_, err := o.client.HeadBucket(ctx, &s3.HeadBucketInput{Bucket: aws.String(o.bucket)})
	if err == nil {
		return nil
	}
	if !isNotFound(err) {
		return err
	}
	_, err = o.client.CreateBucket(ctx, &s3.CreateBucketInput{Bucket: aws.String(o.bucket)})
	return err
}

func (o *Object) Put(ctx context.Context, key string, data []byte, contentType string) error {
	_, err := o.client.PutObject(ctx, &s3.PutObjectInput{
		Bucket:      aws.String(o.bucket),
		Key:         aws.String(key),
		Body:        bytes.NewReader(data),
		ContentType: aws.String(contentType),
	})
	return err
}

func (o *Object) Get(ctx context.Context, key string) ([]byte, error) {
	obj, err := o.client.GetObject(ctx, &s3.GetObjectInput{
		Bucket: aws.String(o.bucket),
		Key:    aws.String(key),
	})
	if err != nil {
		return nil, err
	}
	defer obj.Body.Close()
	return io.ReadAll(obj.Body)
}

// GetIfExists reads an object while treating a missing key as normal state.
func (o *Object) GetIfExists(ctx context.Context, key string) ([]byte, bool, error) {
	if _, err := o.client.HeadObject(ctx, &s3.HeadObjectInput{
		Bucket: aws.String(o.bucket),
		Key:    aws.String(key),
	}); err != nil {
		if isNotFound(err) {
			return nil, false, nil
		}
		return nil, false, err
	}
	data, err := o.Get(ctx, key)
	if err != nil {
		return nil, false, err
	}
	return data, true, nil
}

func (o *Object) Remove(ctx context.Context, key string) error {
	_, err := o.client.DeleteObject(ctx, &s3.DeleteObjectInput{
		Bucket: aws.String(o.bucket),
		Key:    aws.String(key),
	})
	return err
}

// PresignedGet returns a time-limited presigned URL for the object.
// URL generation is pure local HMAC computation — no network call is made.
// If the object does not exist in RustFS the URL will 404 when the client fetches it.
// The external client is used so the Host in the signature matches what the caller sees.
func (o *Object) PresignedGet(ctx context.Context, key string) (string, error) {
	req, err := o.presignClient.PresignGetObject(ctx, &s3.GetObjectInput{
		Bucket: aws.String(o.bucket),
		Key:    aws.String(key),
	}, func(options *s3.PresignOptions) {
		options.Expires = o.urlExpiry
	})
	if err != nil {
		return "", err
	}
	return req.URL, nil
}

func isNotFound(err error) bool {
	var responseError *smithyhttp.ResponseError
	if errors.As(err, &responseError) && responseError.HTTPStatusCode() == http.StatusNotFound {
		return true
	}

	var apiError smithy.APIError
	if !errors.As(err, &apiError) {
		return false
	}
	switch apiError.ErrorCode() {
	case "NoSuchBucket", "NoSuchKey", "NoSuchObject", "NotFound":
		return true
	default:
		return false
	}
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

package image

import (
	"bytes"
	"embed"
	"image"
	"image/color"
	"image/jpeg"
	"image/png"
	"log"

	"github.com/disintegration/imaging"
)

var (
	pinPhotoMask image.Image // pin_image.png
	pinBorder    image.Image // pin_border.png
)

const (
	pinW         = 100
	pinH         = 100
	pinCX        = 50.0
	pinCY        = 43.0
	pinPhotoR    = 39.5
	pinOuterR    = 42.5
	pinStemHW    = 3.0
	pinStemBaseY = 83
	pinStemTipY  = 99
	pinDiameter  = 79
	pinXOffset   = 11
	pinYOffset   = 4
)

//go:embed resources
var assets embed.FS

func init() {
	pinPhotoMask = mustLoad("resources/pin_image.png")
	pinBorder = mustLoad("resources/pin_border.png")
}

func mustLoad(name string) image.Image {
	data, err := assets.ReadFile(name)
	if err != nil {
		log.Fatalf("loading template %s: %v", name, err)
	}
	img, err := png.Decode(bytes.NewReader(data))
	if err != nil {
		log.Fatalf("decoding template %s: %v", name, err)
	}
	return img
}

// CompressJPEG resizes an image to fit within (maxW,maxH) and re-encodes as JPEG
// at the given quality. Mirrors ImageHelper.compressImage (thumbnailator).
func CompressJPEG(raw []byte, maxW, maxH, quality int) ([]byte, error) {
	img, err := imaging.Decode(bytes.NewReader(raw))
	if err != nil {
		return nil, err
	}
	img = imaging.Fit(img, maxW, maxH, imaging.Lanczos)
	var buf bytes.Buffer
	if err := jpeg.Encode(&buf, img, &jpeg.Options{Quality: quality}); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}

func CompressProfileJPEG(raw []byte, maxSize int) ([]byte, error) {
	return CompressJPEG(raw, maxSize, maxSize, taggedJPEGQuality(len(raw)))
}

func CompressPinJPEG(raw []byte) ([]byte, error) {
	img, err := imaging.Decode(bytes.NewReader(raw))
	if err != nil {
		return nil, err
	}
	img = imaging.Resize(img, 720, 960, imaging.Lanczos)
	var buf bytes.Buffer
	if err := jpeg.Encode(&buf, img, &jpeg.Options{Quality: taggedJPEGQuality(len(raw))}); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}

func taggedJPEGQuality(sizeBytes int) int {
	sizeKB := sizeBytes / 1024
	switch {
	case sizeKB > 2500:
		return 30
	case sizeKB > 1500:
		return 50
	case sizeKB > 750:
		return 80
	default:
		return 90
	}
}

// ResizePNG resizes an image to fit and encodes it as PNG.
func ResizePNG(raw []byte, maxW, maxH int) ([]byte, error) {
	img, err := imaging.Decode(bytes.NewReader(raw))
	if err != nil {
		return nil, err
	}
	img = imaging.Fit(img, maxW, maxH, imaging.Lanczos)
	var buf bytes.Buffer
	if err := png.Encode(&buf, img); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}

func notTransparent(img image.Image, x, y int) bool {
	b := img.Bounds()
	if x < b.Min.X || x >= b.Max.X || y < b.Min.Y || y >= b.Max.Y {
		return false
	}
	_, _, _, a := img.At(x, y).RGBA()
	return a != 0
}

func ComposePin(userPhoto []byte) ([]byte, error) {
	raw, err := imaging.Decode(bytes.NewReader(userPhoto))
	if err != nil {
		return nil, err
	}

	diam := pinDiameter // SIZE_GROUP_PIN_DIAMETER
	photo := imaging.Fill(raw, diam, diam, imaging.Center, imaging.Lanczos)

	out := image.NewNRGBA(image.Rect(0, 0, pinW, pinH))
	for y := 0; y < pinH; y++ {
		for x := 0; x < pinW; x++ {
			switch {
			case x >= pinXOffset && x < pinXOffset+diam &&
				y >= pinYOffset && y < pinYOffset+diam &&
				notTransparent(pinPhotoMask, x, y):
				r, g, b, _ := photo.At(x-pinXOffset, y-pinYOffset).RGBA()
				out.Set(x, y, color.NRGBA{uint8(r >> 8), uint8(g >> 8), uint8(b >> 8), 255})

			case notTransparent(pinBorder, x, y):
				r, g, b, _ := pinBorder.At(x, y).RGBA()
				out.Set(x, y, color.NRGBA{uint8(r >> 8), uint8(g >> 8), uint8(b >> 8), 255})

				// default: leave fully transparent (NRGBA zero value)
			}
		}
	}

	var buf bytes.Buffer
	if err := png.Encode(&buf, out); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}

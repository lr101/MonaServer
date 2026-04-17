package image

import (
	"bytes"
	_ "embed"
	"image"
	"image/color"
	"image/jpeg"
	"image/png"

	"github.com/disintegration/imaging"
)

//go:embed assets/pin_image.png
var pinTemplatePNG []byte

//go:embed assets/pin_border.png
var pinBorderPNG []byte

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

// ComposePin overlays userPhoto onto the pin-shaped template, masking by the
// template's alpha channel, then draws the border on top. Mirrors
// ImageHelper.getPinImage (per-pixel alpha copy).
func ComposePin(userPhoto []byte) ([]byte, error) {
	tmpl, err := png.Decode(bytes.NewReader(pinTemplatePNG))
	if err != nil {
		return nil, err
	}
	border, err := png.Decode(bytes.NewReader(pinBorderPNG))
	if err != nil {
		return nil, err
	}
	photo, err := imaging.Decode(bytes.NewReader(userPhoto))
	if err != nil {
		return nil, err
	}

	b := tmpl.Bounds()
	photo = imaging.Fill(photo, b.Dx(), b.Dy(), imaging.Center, imaging.Lanczos)
	out := image.NewRGBA(b)

	for y := b.Min.Y; y < b.Max.Y; y++ {
		for x := b.Min.X; x < b.Max.X; x++ {
			_, _, _, ta := tmpl.At(x, y).RGBA()
			if ta == 0 {
				continue
			}
			pr, pg, pb, _ := photo.At(x, y).RGBA()
			out.Set(x, y, color.RGBA{uint8(pr >> 8), uint8(pg >> 8), uint8(pb >> 8), uint8(ta >> 8)})
		}
	}
	// draw border on top (composite)
	for y := b.Min.Y; y < b.Max.Y; y++ {
		for x := b.Min.X; x < b.Max.X; x++ {
			br, bg, bb, ba := border.At(x, y).RGBA()
			if ba == 0 {
				continue
			}
			out.Set(x, y, color.RGBA{uint8(br >> 8), uint8(bg >> 8), uint8(bb >> 8), uint8(ba >> 8)})
		}
	}
	var buf bytes.Buffer
	if err := png.Encode(&buf, out); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}

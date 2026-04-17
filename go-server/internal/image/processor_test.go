package image

import (
	"bytes"
	"image"
	"image/color"
	"image/png"
	"testing"
)

func makeTestPNG(w, h int, c color.RGBA) []byte {
	img := image.NewRGBA(image.Rect(0, 0, w, h))
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			img.Set(x, y, c)
		}
	}
	var buf bytes.Buffer
	_ = png.Encode(&buf, img)
	return buf.Bytes()
}

func TestCompressJPEG(t *testing.T) {
	in := makeTestPNG(800, 600, color.RGBA{255, 0, 0, 255})
	out, err := CompressJPEG(in, 400, 300, 80)
	if err != nil {
		t.Fatal(err)
	}
	if len(out) == 0 {
		t.Fatal("empty output")
	}
}

func TestResizePNG(t *testing.T) {
	in := makeTestPNG(200, 200, color.RGBA{0, 255, 0, 255})
	out, err := ResizePNG(in, 50, 50)
	if err != nil {
		t.Fatal(err)
	}
	img, err := png.Decode(bytes.NewReader(out))
	if err != nil {
		t.Fatal(err)
	}
	if img.Bounds().Dx() > 50 || img.Bounds().Dy() > 50 {
		t.Fatalf("not resized: %v", img.Bounds())
	}
}

func TestComposePin(t *testing.T) {
	photo := makeTestPNG(256, 256, color.RGBA{50, 100, 200, 255})
	out, err := ComposePin(photo)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := png.Decode(bytes.NewReader(out)); err != nil {
		t.Fatalf("result not a valid PNG: %v", err)
	}
}

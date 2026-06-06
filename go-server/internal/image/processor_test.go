package image

import (
	"bytes"
	"image"
	"image/color"
	"image/png"
	"math"
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
	photoColor := color.RGBA{50, 100, 200, 255}
	photo := makeTestPNG(256, 256, photoColor)

	out, err := ComposePin(photo)
	if err != nil {
		t.Fatal(err)
	}
	img, err := png.Decode(bytes.NewReader(out))
	if err != nil {
		t.Fatalf("result not a valid PNG: %v", err)
	}

	// Output must be exactly 100×100.
	b := img.Bounds()
	if b.Dx() != pinW || b.Dy() != pinH {
		t.Fatalf("expected %dx%d canvas, got %dx%d", pinW, pinH, b.Dx(), b.Dy())
	}

	// Centre of the photo circle should carry the photo colour.
	cx, cy := int(pinCX), int(pinCY)
	r, g, bv, a := img.At(cx, cy).RGBA()
	if a == 0 {
		t.Fatalf("pixel at photo-area centre (%d,%d) is fully transparent", cx, cy)
	}
	if uint8(r>>8) != photoColor.R || uint8(g>>8) != photoColor.G || uint8(bv>>8) != photoColor.B {
		t.Fatalf("pixel at (%d,%d) = R%d G%d B%d, want R%d G%d B%d",
			cx, cy, uint8(r>>8), uint8(g>>8), uint8(bv>>8),
			photoColor.R, photoColor.G, photoColor.B)
	}

	// A pixel in the border ring (between pinPhotoR and pinOuterR) must be non-transparent.
	borderR := int((pinPhotoR + pinOuterR) / 2)
	bx, by := int(pinCX)+borderR, int(pinCY)
	_, _, _, ba := img.At(bx, by).RGBA()
	if ba == 0 {
		t.Errorf("border pixel at (%d,%d) should be non-transparent", bx, by)
	}

	// A pixel in the stem should be non-transparent.
	sx, sy := int(pinCX), (pinStemBaseY+pinStemTipY)/2
	_, _, _, sa := img.At(sx, sy).RGBA()
	if sa == 0 {
		t.Errorf("stem pixel at (%d,%d) should be non-transparent", sx, sy)
	}

	// Corners of the canvas must be transparent (outside pin shape).
	for _, pt := range [][2]int{{0, 0}, {99, 0}, {0, 99}, {99, 99}} {
		dx := float64(pt[0]) - pinCX
		dy := float64(pt[1]) - pinCY
		d := math.Sqrt(dx*dx + dy*dy)
		if d > pinOuterR { // only check corners that are geometrically outside
			_, _, _, a := img.At(pt[0], pt[1]).RGBA()
			if a != 0 {
				t.Errorf("corner (%d,%d) should be transparent, got alpha=%d", pt[0], pt[1], a)
			}
		}
	}
}

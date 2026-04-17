package password

import "testing"

func TestHashAndVerify(t *testing.T) {
	h, err := Hash("secret123")
	if err != nil {
		t.Fatal(err)
	}
	if !Verify(h, "secret123") {
		t.Fatal("verify should succeed")
	}
	if Verify(h, "wrong") {
		t.Fatal("verify should fail for wrong password")
	}
}

package output

import "testing"

func TestValidateFilename(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name string
		want bool
	}{
		{name: "backup.sh", want: true},
		{name: "relatorio_2026-09-30.sh", want: true},
		{name: "", want: false},
		{name: "../backup.sh", want: false},
		{name: "dir/backup.sh", want: false},
		{name: "dir\\backup.sh", want: false},
		{name: "backup script.sh", want: false},
		{name: "relatório.sh", want: false},
		{name: "backup..sh", want: false},
	}

	for _, tt := range tests {
		tt := tt
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()
			got := ValidateFilename(tt.name) == nil
			if got != tt.want {
				t.Fatalf("ValidateFilename(%q) valid=%v, want %v", tt.name, got, tt.want)
			}
		})
	}
}

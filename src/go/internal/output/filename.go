package output

import (
	"errors"
	"fmt"
	"strings"
)

const MaxFilenameLength = 128

var (
	ErrEmptyFilename       = errors.New("filename vazio")
	ErrFilenameTooLong     = errors.New("filename excede o limite")
	ErrInvalidFilenameChar = errors.New("filename contém caractere inválido")
	ErrUnsafeFilename      = errors.New("filename inseguro")
)

// ValidateFilename enforces the deterministic output rule proposed in
// ARCHITECTURE_REVIEW_V2: basename only, no path separators, no "..",
// and a conservative ASCII character set.
func ValidateFilename(name string) error {
	if name == "" {
		return ErrEmptyFilename
	}
	if len(name) > MaxFilenameLength {
		return fmt.Errorf("%w: máximo %d bytes", ErrFilenameTooLong, MaxFilenameLength)
	}
	if strings.Contains(name, "..") || strings.ContainsAny(name, "/\\") {
		return ErrUnsafeFilename
	}

	for i := 0; i < len(name); i++ {
		c := name[i]
		if (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '.' || c == '_' || c == '-' {
			continue
		}
		return fmt.Errorf("%w: byte 0x%02x", ErrInvalidFilenameChar, c)
	}

	return nil
}

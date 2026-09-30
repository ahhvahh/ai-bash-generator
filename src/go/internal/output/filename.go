package output

import (
	"errors"
	"fmt"
	"strings"
	"unicode"
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
	if strings.Contains(name, "..") || strings.ContainsAny(name, `/\\`) {
		return ErrUnsafeFilename
	}

	for _, r := range name {
		if unicode.IsLetter(r) || unicode.IsDigit(r) || r == '.' || r == '_' || r == '-' {
			continue
		}
		return fmt.Errorf("%w: %q", ErrInvalidFilenameChar, r)
	}

	return nil
}

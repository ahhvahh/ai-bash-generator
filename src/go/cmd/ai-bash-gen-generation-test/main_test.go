package main

import "testing"

func TestSmokeCases(t *testing.T) {
    if len(cases) != 10 {
        t.Fatalf("quantidade de casos=%d, esperado=10", len(cases))
    }
    seen := map[string]bool{}
    for i, tc := range cases {
        if tc.Name == "" { t.Fatalf("caso %d sem nome", i) }
        if tc.Prompt == "" { t.Fatalf("caso %s sem prompt", tc.Name) }
        if len(tc.Required) == 0 { t.Fatalf("caso %s sem requisitos", tc.Name) }
        if seen[tc.Name] { t.Fatalf("caso duplicado: %s", tc.Name) }
        seen[tc.Name] = true
    }
}

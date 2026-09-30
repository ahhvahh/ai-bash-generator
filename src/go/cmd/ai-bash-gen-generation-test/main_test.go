package main

import (
    "context"
    "crypto/sha256"
    "encoding/hex"
    "testing"

    "github.com/ahhvahh/ai-bash-generator/internal/protocol"
)

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

func TestTenGeneratedScriptFixturesAreCoherent(t *testing.T) {
    fixtures := map[string]string{
        "01-echo": "#!/usr/bin/env bash\nset -Eeuo pipefail\necho \"Ola A-Bioma\"\n",
        "02-pwd": "#!/usr/bin/env bash\nset -Eeuo pipefail\npwd\n",
        "03-ls": "#!/usr/bin/env bash\nset -Eeuo pipefail\nls -la\n",
        "04-df": "#!/usr/bin/env bash\nset -Eeuo pipefail\ndf -h\n",
        "05-find-sort-head": "#!/usr/bin/env bash\nset -Eeuo pipefail\nfind /var/log -type f -printf \"%s %p\\n\" | sort -nr | head -n 10\n",
        "06-tar-backup": "#!/usr/bin/env bash\nset -Eeuo pipefail\ntar -czf /tmp/etc-backup.tar.gz /etc\n",
        "07-systemctl": "#!/usr/bin/env bash\nset -Eeuo pipefail\nsystemctl is-active --quiet ssh || exit 1\n",
        "08-pipeline-texto": "#!/usr/bin/env bash\nset -Eeuo pipefail\nawk -F: '{print $7}' /etc/passwd | sort | uniq -c\n",
        "09-rsync-dry-run": "#!/usr/bin/env bash\nset -Eeuo pipefail\nrsync -a --dry-run /srv/dados/ /backup/dados/\n",
        "10-backup-robusto": "#!/usr/bin/env bash\nset -Eeuo pipefail\ntmp=\"$(mktemp -d)\"\ntrap 'rm -rf \"$tmp\"' EXIT\ntar -czf \"$tmp/etc.tar.gz\" /etc\nsha256sum \"$tmp/etc.tar.gz\"\n",
    }

    stages := map[protocol.Stage]protocol.ProgressState{
        protocol.StageRequestNormalizer: protocol.StateCompleted,
        protocol.StageSearchCapabilities: protocol.StateCompleted,
        protocol.StageBashGenerator: protocol.StateCompleted,
        protocol.StageValidation: protocol.StateCompleted,
        protocol.StageBashOutput: protocol.StateCompleted,
    }

    for _, tc := range cases {
        tc := tc
        t.Run(tc.Name, func(t *testing.T) {
            script, ok := fixtures[tc.Name]
            if !ok { t.Fatalf("fixture ausente") }
            sum := sha256.Sum256([]byte(script))
            artifact := protocol.BashArtifact{
                Filename: tc.Name + ".sh",
                Content: script,
                SHA256: hex.EncodeToString(sum[:]),
            }
            if err := validateArtifact(context.Background(), tc, artifact, stages); err != nil {
                t.Fatal(err)
            }
        })
    }
}

# claude-second-brain-skill

Repository template per esportare il sistema di documentazione **"Second
Brain"** su altri progetti: una struttura `docs/` mantenuta sincronizzata col
codice tramite una skill di Claude Code e un git hook di pre-commit.

## Cosa contiene

```text
claude-second-brain-skill/
├── template/
│   ├── CLAUDE.md                          # blocco integrato nel CLAUDE.md della destinazione
│   ├── .claude/
│   │   ├── hooks/
│   │   │   └── pre-commit                 # blocca commit di codice senza aggiornamento docs
│   │   └── skills/
│   │       └── update-second-brain/
│   │           └── SKILL.md               # skill che aggiorna la documentazione
│   └── docs/
│       ├── adr/
│       │   └── template.md
│       ├── README.md
│       ├── architecture.md
│       ├── database.md
│       ├── glossary.md
│       ├── layout.md
│       ├── patterns.md
│       └── testing.md
├── init.ps1                               # script di iniezione nel progetto destinazione
└── README.md
```

## Come usarlo

Da questa repository, lancia `init.ps1` puntando alla cartella del progetto
in cui vuoi installare il second brain:

```powershell
# Installa nel progetto corrente (default)
.\init.ps1

# Installa in un altro progetto
.\init.ps1 ..\MioProgetto
```

Lo script:

1. crea `.claude/hooks/`, `.claude/skills/update-second-brain/` e `docs/adr/`
   nel progetto di destinazione;
2. copia il contenuto di `template/docs/` e `template/.claude/` senza
   sovrascrivere file gia' presenti nel progetto destinazione;
3. integra un blocco delimitato da marker (`<!-- BEGIN/END SECOND BRAIN
   SYSTEM -->`) nel `CLAUDE.md` della destinazione: se il file non esiste lo
   crea, se esiste lo aggiunge in coda senza toccare il contenuto scritto
   dall'utente, se il blocco e' gia' presente (re-run dello script) lo
   aggiorna sul posto in modo idempotente;
4. se la destinazione e' una repository Git, esegue
   `git config core.hooksPath .claude/hooks` per agganciare il pre-commit
   hook.

## Requisiti

- Windows con Git per Windows (gli hook girano tramite l'ambiente Bash/MSYS
  incluso in Git per Windows).
- PowerShell 5.1+ o PowerShell 7+.

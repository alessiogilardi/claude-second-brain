Agisci come un Senior DevOps Engineer su sistema operativo Windows. La repository emplate chiamata `claude-second-brain` progettata per esportare il sistema di documentazione "Second Brain" su altri progetti.

Esegui i seguenti punti in ordine sequenziale, creando i file e verificando il loro contenuto:

### 1. Scaffolding Strutturale (Windows)

Crea l'albero delle cartelle e i file di configurazione partendo da questa struttura esatta nella cartella corrente:

```text
claude-second-brain/
├── template/
│   ├── .claude/
│   │   ├── hooks/
│   │   │   └── pre-commit
│   │   └── skills/
│   │       └── update-second-brain/
│   │           └── SKILL.md
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
├── init.ps1
└── README.md

```

### 2. Checklist Operativa per Punti

* [ ] **Fase 1: Creazione File e Directory**
* Genera la struttura di cartelle completa all'interno di una sottocartella `template/`.
* Crea tutti i file `.md` vuoti e il file `init.ps1` nella radice.


* [ ] **Fase 2: Scrittura dello Script di Iniezione (`init.ps1`)**
* Scrivi lo script PowerShell `init.ps1` che accetta come parametro opzionale la cartella del progetto di destinazione (default: `.` ovvero la cartella corrente).
* Lo script deve:
1. Creare le cartelle `.claude/hooks/`, `.claude/skills/update-second-brain/` e `docs/adr/` nel progetto di destinazione.
2. Copiare ricorsivamente il contenuto di `template/docs/` e `template/.claude/` nella destinazione senza sovrascrivere i file esistenti dell'utente (usa `Copy-Item -Recurse -Force` o verifica l'esistenza).
3. Se nel progetto di destinazione esiste già un `CLAUDE.md`, rinominalo in `CLAUDE.md.bak`.
4. Eseguire il comando Git locale per agganciare gli hook nella nuova cartella: `git config core.hooksPath .claude/hooks`.
5. Mostrare messaggi chiari a terminale con `Write-Host` per confermare l'avvenuta configurazione.




* [ ] **Fase 3: Popolamento del Git Pre-Commit Hook**
* Scrivi il file `template/.claude/hooks/pre-commit`. *Nota: Git per Windows esegue gli hook tramite un ambiente Bash interno (MSYS), quindi questo file deve usare la sintassi Bash (`#!/bin/sh`).*
* L'hook deve contare i file stadiati (staged). Se ci sono modifiche al codice sorgente ma nessuna modifica nella cartella `docs/` o nel file `CLAUDE.md`, deve bloccarsi con `exit 1` e stampare a schermo un messaggio d'errore vistoso (`[SECOND BRAIN SYSTEM] COMMIT REJECTED`) spiegando a Claude di eseguire la skill `.claude/skills/update-second-brain` prima di riprovare.


* [ ] **Fase 4: Scrittura della Skill (`template/.claude/skills/update-second-brain/SKILL.md`)**
* Inserisci i metadati con il nome della skill e una `description` dettagliata ricca di trigger semantici per Claude Code (modifiche DB, refactoring, nuove decisioni architetturali).
* Includi la checklist di fine sessione (Controlla ADR, aggiorna schema DB, mappa i nuovi pattern, aggiorna le strategie di testing).
* Specifica che la skill lavora in "Scrittura diretta" per i file tecnici e in modalità "Proposta" per i nuovi file ADR.


* [ ] **Fase 5: Popolamento dei Template Markdown (`docs/`)**
* Scrivi un `docs/README.md` che funga da mappa di navigazione per gli agenti AI.
* Scrivi un `docs/adr/template.md` con la struttura standard (Titolo, Stato, Contesto, Decisione, Alternative, Conseguenze).
* Inserisci brevi descrizioni o placeholder esplicativi in `architecture.md`, `database.md`, `patterns.md`, `glossary.md`, `layout.md` e `testing.md` per guidare Claude durante la compilazione nei progetti reali.


* [ ] **Fase 6: Inizializzazione Git della Repository Template**
* Crea il file `README.md` nella radice della repo spiegando a te stesso come usare il comando in PowerShell (es. `.\init.ps1 ..\MioProgetto`).
* Esegui `git init`, aggiungi tutti i file stadiati ed effettua il primo commit: `git commit -m "feat: initial release of portable second brain template for windows"`.


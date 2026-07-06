<!-- BEGIN SECOND BRAIN SYSTEM (gestito da claude-second-brain-skill: non modificare a mano questo blocco, modifica template/CLAUDE.md e rilancia init.ps1) -->
# Second Brain

Questo progetto usa il sistema di documentazione "Second Brain": una serie di
file in `docs/` che descrivono lo stato reale di architettura, database,
pattern e testing, pensati per essere letti e mantenuti da agenti AI.

## Mappa della documentazione

Consulta sempre `docs/README.md` come punto di ingresso. In sintesi:

- `docs/architecture.md` — visione d'insieme dell'architettura
- `docs/database.md` — schema del database e relazioni
- `docs/patterns.md` — pattern di design e convenzioni ricorrenti nel codice
- `docs/glossary.md` — glossario dei termini di dominio
- `docs/layout.md` — struttura delle cartelle e responsabilita' dei moduli
- `docs/testing.md` — strategia e strumenti di testing
- `docs/adr/` — Architecture Decision Records (una decisione per file)

## Regola operativa

Ogni commit che modifica codice sorgente deve accompagnarsi a un
aggiornamento coerente in `docs/` o in questo file: un git hook in
`.claude/hooks/pre-commit` lo verifica automaticamente e rifiuta il commit
in caso contrario.

Quando modifichi schema DB, fai refactoring strutturale, prendi una nuova
decisione architetturale, introduci un nuovo pattern, o cambi strategia di
testing, esegui la skill `.claude/skills/update-second-brain` per allineare
la documentazione prima di chiudere la sessione.
<!-- END SECOND BRAIN SYSTEM -->

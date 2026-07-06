---
name: update-second-brain
description: >
  Aggiorna la documentazione "Second Brain" del progetto (docs/architecture.md,
  docs/database.md, docs/patterns.md, docs/glossary.md, docs/layout.md,
  docs/testing.md, docs/adr/) per mantenerla allineata al codice. Attivare
  questa skill quando: (1) sono state modificate tabelle, colonne, migrazioni
  o lo schema del database; (2) e' stato fatto un refactoring strutturale di
  moduli, servizi o package; (3) e' stata presa una nuova decisione
  architetturale (scelta di libreria, pattern, tecnologia, trade-off
  significativo); (4) e' stato introdotto un nuovo pattern di design o
  convenzione ricorrente nel codice; (5) e' cambiata la strategia di testing
  (nuovi tipi di test, nuovi tool, nuova policy di coverage); (6) il
  pre-commit hook ha rifiutato un commit con il messaggio
  "[SECOND BRAIN SYSTEM] COMMIT REJECTED"; (7) a fine sessione di lavoro,
  prima di chiudere o consegnare, per verificare che nulla sia rimasto
  disallineato.
---

# Update Second Brain

Questa skill mantiene sincronizzata la documentazione tecnica del progetto
(il "second brain") con lo stato reale del codice, cosi' che ogni agente AI
futuro (incluso te stesso in una sessione successiva) possa orientarsi senza
dover rileggere l'intera codebase.

## Modalita' operative

- **Scrittura diretta** per i file tecnici esistenti: `docs/architecture.md`,
  `docs/database.md`, `docs/patterns.md`, `docs/glossary.md`, `docs/layout.md`,
  `docs/testing.md`. Aggiorna queste pagine in place, senza chiedere conferma,
  perche' descrivono lo stato attuale del sistema e devono restare accurate.
- **Modalita' proposta** per i nuovi file in `docs/adr/`: una nuova decisione
  architetturale non va scritta silenziosamente. Prepara il contenuto usando
  `docs/adr/template.md` come base e presentalo all'utente per conferma prima
  di salvarlo definitivamente (numerazione progressiva, es. `0003-titolo.md`).

## Checklist di fine sessione

Prima di considerare concluso il lavoro (o prima di ritentare un commit
rifiutato dal pre-commit hook), verifica punto per punto:

- [ ] **ADR**: e' stata presa una decisione architetturale rilevante? Se si',
      proponi un nuovo file in `docs/adr/` basato su `docs/adr/template.md`.
- [ ] **Schema database**: sono cambiate tabelle, colonne, relazioni o
      migrazioni? Aggiorna `docs/database.md` di conseguenza.
- [ ] **Pattern**: e' stato introdotto o modificato un pattern architetturale
      o una convenzione ricorrente? Mappalo in `docs/patterns.md`.
- [ ] **Testing**: sono cambiati framework, tipi di test o policy di
      copertura? Aggiorna `docs/testing.md`.
- [ ] **Architettura generale**: la modifica cambia il layout dei componenti
      o dei flussi principali? Aggiorna `docs/architecture.md` e/o
      `docs/layout.md`.
- [ ] **Glossario**: sono stati introdotti nuovi termini di dominio? Aggiungili
      a `docs/glossary.md`.

Solo dopo aver completato la checklist, ristadia i file di documentazione
modificati insieme al codice: il pre-commit hook richiede che ogni commit con
modifiche al codice sorgente includa anche una modifica in `docs/` o in
`CLAUDE.md`.

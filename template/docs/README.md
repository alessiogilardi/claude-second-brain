# Second Brain — Mappa di navigazione

Questa cartella e' il "second brain" del progetto: la fonte di verita' sullo
stato reale di architettura, dati, pattern e testing. E' pensata per essere
letta e aggiornata da agenti AI (Claude Code) oltre che da sviluppatori umani.

## Come orientarsi

| File | Quando leggerlo |
|---|---|
| [`architecture.md`](./architecture.md) | Per capire i componenti principali del sistema e come comunicano tra loro. |
| [`database.md`](./database.md) | Prima di modificare schema, tabelle, migrazioni o relazioni. |
| [`patterns.md`](./patterns.md) | Prima di scrivere codice nuovo, per riusare le convenzioni gia' adottate. |
| [`glossary.md`](./glossary.md) | Quando incontri un termine di dominio non familiare. |
| [`layout.md`](./layout.md) | Per orientarsi nella struttura delle cartelle e capire dove va aggiunto codice nuovo. |
| [`testing.md`](./testing.md) | Prima di scrivere o modificare test. |
| [`adr/`](./adr/) | Per lo storico delle decisioni architetturali e il loro contesto/motivazione. |

## Come mantenerla aggiornata

Questa documentazione non e' statica: va aggiornata ad ogni cambiamento
rilevante tramite la skill `.claude/skills/update-second-brain`. Un git hook
(`.claude/hooks/pre-commit`) impedisce commit di codice sorgente che non
tocchino anche questa cartella o `CLAUDE.md`, proprio per evitare che la
documentazione si disallinei dal codice reale.

## Regola per gli agenti AI

Prima di iniziare un task non banale, leggi almeno `architecture.md` e
`layout.md`. Prima di modificare il database, leggi `database.md`. Prima di
concludere una sessione di lavoro, esegui la checklist della skill
`update-second-brain`.

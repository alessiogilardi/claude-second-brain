# Database

> Placeholder — da compilare durante l'onboarding del progetto reale.

## Motore e connessione

Indica il DBMS usato (es. PostgreSQL, SQLite, MongoDB) e dove si trova la
configurazione di connessione (senza includere credenziali).

## Schema principale

Elenca le tabelle/collezioni principali, i loro campi chiave e le relazioni
tra loro. Per schemi complessi, preferisci un elenco strutturato tabella per
tabella piuttosto che un unico diagramma monolitico.

```text
tabella_esempio
├── id (PK)
├── campo_x
└── fk_altra_tabella (FK -> altra_tabella.id)
```

## Migrazioni

Indica lo strumento di migrazione usato e la convenzione di naming/versioning
adottata.

---
*Istruzioni per Claude: aggiorna questo file ogni volta che cambiano tabelle,
colonne, indici, vincoli o relazioni. Non lasciare lo schema documentato
disallineato da quello reale.*

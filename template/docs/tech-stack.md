# Technology inventory

Everything {{PROJECT_NAME}} runs, why it is there, and where it is configured. Fill this in by reading
the manifests and the machines rather than from memory, and date it, so a reader knows how stale it is.

Written {{TODAY}}.

---

## Front doors

List every web property separately. Confusing them is the most common mistake on a project that has more
than one.

| Property | What it is | Stack | Lives in |
|---|---|---|---|
| | | | |

---

## Application

**Frontend** — framework, language, styling, component library, and the handful of libraries that a
newcomer would otherwise have to discover: dates, forms, tables, state, icons, i18n.

**Backend** — framework, runtime, ORM, database, cache, job scheduler, logging.

**Notable pins.** Any dependency held at an unusual version or source, with the reason. Someone will
otherwise "fix" it back and reintroduce the problem.

---

## Data and storage

Primary store, and how migrations are run. Anything that sounds like a database but is not — object
storage, a cache, a search index — named explicitly so nobody assumes wrongly.

---

## Diagrams

State the tool per context; there is rarely one answer.

| Where | Tool | Why |
|---|---|---|
| Architecture docs | | |
| Product documentation | | |
| Marketing or hero visuals | | |

Text-based diagram sources belong in the repo next to their rendered output, so they diff like code.

---

## Infrastructure

Machines and what each runs. Process management, edge and DNS, private networking, mail, payments,
backups and their restore drill, monitoring and where alerts land, integrations that are actually wired.

---

## Tooling

Language tooling, linters, formatters, test runners, browser automation, and any scripting language used
for operational scripts.

---

## Things worth a decision

Observations from taking the inventory — dependencies imported nowhere, two libraries doing one job, a
service paid for and unused. Note them here rather than fixing them mid-inventory; the owner decides
scope.

#  Cybersikkerhed Projekter

## Beskrivelse

Denne mappe indeholder projekter med fokus på cybersikkerhed, detection og Zero Trust.
## Security Architecture

``

---

## SecureInfraTool

Overvåger systemressourcer og sikkerhedshændelser.

**Features:**

* CPU, RAM og disk monitoring
* Failed login detection (Event ID 4625)
* Netværk overvågning
* Logging og alerts

---

## ZeroTrustTool

Implementerer en Zero Trust model.

**Features:**

* Risk-based authentication
* Context-aware security (tid & weekend)
* Adaptive access (Allow / MFA / Deny)

---

## AD Attack Detection Toolkit

Simulerer og detekterer angreb i Active Directory.

**Features:**

* Password spraying
* Failed login detection
* Admin privilege overvågning

---

## Automatisk Backup

Automatiserer backup og sikrer data.

---

## Server & Klient Overvågning

Overvåger endpoints og systemer i netværket.

---

## Formål

At demonstrere praktiske færdigheder indenfor:

* Detection & monitoring
* Active Directory security
* Zero Trust arkitektur

* ##  Security Architecture

```
        +----------------------+
        |   User / System      |
        +----------+-----------+
                   |
                   v
        +----------------------+
        |   ZeroTrustTool      |
        | (Access Control)     |
        +----------+-----------+
                   |
         +---------+---------+
         |                   |
         v                   v
+----------------+   +----------------------+
| SecureInfraTool|   | AD Detection Toolkit |
| Monitoring     |   | Attack Detection     |
+--------+-------+   +----------+-----------+
         |                      |
         +----------+-----------+
                    |
                    v
            +---------------+
            | Logs / Alerts |
            +---------------+
```



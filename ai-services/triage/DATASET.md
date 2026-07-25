# Triage Routing Dataset

Dataset for the SmartRide AI triage service — maps a free-text symptom / request
message to the medical **specialty** (hospital department) that should receive
the patient.

## Location

```
ai-services/triage/data/
├── hospital_routing_full.csv          # all rows (1,401)
├── hospital_routing_train.csv         # 1,121 rows
├── hospital_routing_val.csv           #   141 rows
├── hospital_routing_test.csv          #   141 rows
├── hospital_routing_true_holdout.csv  #    57 rows (hand-written, see below)
├── hospital_routing_label_map.json    # label name -> integer id
├── train_distilbert.py                # fine-tuning script
└── make_true_holdout.py               # generator for the honest holdout set
```

## Schema

Each CSV has exactly two columns:

| Column  | Type   | Description                                                        |
|---------|--------|--------------------------------------------------------------------|
| `text`  | string | Natural-language symptom / transport request (English).            |
| `label` | string | One of the 14 specialty classes below (Title_Case, see label map). |

Example rows (`text`, `label`):

```
"My aunt has severe joint pain from arthritis and can't reach the car today.", Orthopedics
"My father is due for a follow-up endoscopy appointment this week.",           Gastroenterology
"My aunt is a cancer patient and needs to go for radiotherapy.",               Oncology
```

## Label set (14 classes)

`hospital_routing_label_map.json` maps each label to an integer id (0–13):

```
Cardiology, ENT, Emergency_Trauma, Gastroenterology, General_Medicine,
Nephrology_Dialysis, Neurology, Obstetrics_Gynecology, Oncology, Orthopedics,
Pediatrics, Psychiatry_MentalHealth, Pulmonology, Urology
```

### Mapping to the service / database vocabulary

The dataset labels are richer than the Postgres `specialty` enum used by the
backend. The model's output is normalized to a canonical enum value before it
reaches hospital matching or the database. The mapping lives in **one place per
service** and MUST be kept in sync:

- `ai-services/triage/specialties.py` → `DATASET_LABEL_TO_ENUM`
- `backend/app/core/specialties.py` → `DATASET_LABEL_TO_ENUM`

| Dataset label            | Canonical enum value |
|--------------------------|----------------------|
| Cardiology               | cardiology           |
| ENT                      | ent                  |
| Emergency_Trauma         | general_emergency    |
| Gastroenterology         | gastroenterology     |
| General_Medicine         | general_emergency    |
| Nephrology_Dialysis      | nephrology           |
| Neurology                | neurology            |
| Obstetrics_Gynecology    | obstetrics           |
| Oncology                 | oncology             |
| Orthopedics              | orthopedics          |
| Pediatrics               | pediatrics           |
| Psychiatry_MentalHealth  | psychiatry           |
| Pulmonology              | pulmonology          |
| Urology                  | urology              |

`urology` was added to the enum in Alembic migration `0006_specialty_urology`.
`Emergency_Trauma` and `General_Medicine` both map to `general_emergency`
because the enum has no separate trauma/general department — this is a
deliberate, lossy collapse for routing safety.

## Splits

| Split        | Rows  | Source                                                        |
|--------------|-------|---------------------------------------------------------------|
| train        | 1,121 | Template generator                                            |
| val          | 141   | Template generator                                            |
| test         | 141   | Template generator (same distribution as train/val)           |
| true_holdout | 57    | Hand-written, independent of the generator templates          |

The **true holdout** is the honest number to report against the ≥92% accuracy
target. Because train/val/test are produced by the same templated generator, a
model can score highly on `test` by memorizing surface patterns; the hand-written
holdout measures whether it learned the underlying medical content. A large gap
between template-test and true-holdout metrics signals template overfitting —
see the warning printed by `train_distilbert.py`.

## Known biases & limitations

- **Templated phrasing.** Train/val/test are synthetic and share sentence
  templates, so real-world phrasing variety is under-represented. Expect the
  gap to shrink as real pilot data is added.
- **English only.** No Urdu / Roman-Urdu coverage yet, despite the Pakistan
  deployment context.
- **Specialty only.** There is no severity label. Severity is computed by the
  rule-based `compute_severity` / `detect_severity_override` path, not the model.
- **No PHI.** Rows are synthetic descriptions; they contain no real patient
  identifiers.
- **Collapsed classes.** `Emergency_Trauma` and `General_Medicine` are distinct
  in the dataset but both route to `general_emergency` downstream.

## Usage

Preprocessing, training, and evaluation:

```bash
cd ai-services/triage/data
pip install transformers datasets scikit-learn pandas torch
python train_distilbert.py
```

The script maps labels via `label_map.json`, fine-tunes `distilbert-base-uncased`
(macro-averaged F1, since every department matters equally), evaluates on both
the template test set and the true holdout, and saves the model +
tokenizer to `./distilbert-hospital-routing-final`.

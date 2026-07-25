"""
Fine-tune DistilBERT for symptom-text -> hospital/department routing.

Setup:
    pip install transformers datasets scikit-learn pandas torch --break-system-packages

Usage:
    python train_distilbert.py

Expects, in the same folder:
    hospital_routing_train.csv
    hospital_routing_val.csv
    hospital_routing_test.csv
    hospital_routing_label_map.json

Each CSV has two columns: text,label
label_map.json maps label name -> integer id.

Verified against transformers==5.14.1 (eval_strategy, processing_class are the
current param names -- older tutorials online use evaluation_strategy/tokenizer,
which will error on recent versions).
"""

import json
import numpy as np
import pandas as pd
from datasets import Dataset
from sklearn.metrics import accuracy_score, precision_recall_fscore_support
from transformers import (
    AutoTokenizer,
    AutoModelForSequenceClassification,
    TrainingArguments,
    Trainer,
    DataCollatorWithPadding,
)

MODEL_NAME = "distilbert-base-uncased"
MAX_LEN = 96
OUTPUT_DIR = "./distilbert-hospital-routing"
FINAL_MODEL_DIR = "./distilbert-hospital-routing-final"

# ---------------------------------------------------------------------------
# 1. Load data + label map
# ---------------------------------------------------------------------------
with open("hospital_routing_label_map.json") as f:
    label2id = json.load(f)
id2label = {v: k for k, v in label2id.items()}

def load_split(name):
    df = pd.read_csv(f"hospital_routing_{name}.csv")
    df["label"] = df["label"].map(label2id)
    if df["label"].isna().any():
        bad = df[df["label"].isna()]
        raise ValueError(f"Found labels in {name}.csv not present in label_map.json: {bad}")
    return Dataset.from_pandas(df[["text", "label"]], preserve_index=False)

train_ds = load_split("train")
val_ds = load_split("val")
test_ds = load_split("test")

# This one is optional -- a small, hand-written set that is NOT drawn from
# the same generator templates as train/val/test. See its module docstring
# (make_true_holdout.py) for why this number, not the template test-set
# number, is the honest one to report against a >92% accuracy target.
import os as _os
HAS_TRUE_HOLDOUT = _os.path.exists("hospital_routing_true_holdout.csv")
if HAS_TRUE_HOLDOUT:
    true_holdout_ds = load_split("true_holdout")

# ---------------------------------------------------------------------------
# 2. Tokenize
# ---------------------------------------------------------------------------
tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME)

def tokenize(batch):
    return tokenizer(batch["text"], truncation=True, max_length=MAX_LEN)

train_ds = train_ds.map(tokenize, batched=True)
val_ds = val_ds.map(tokenize, batched=True)
test_ds = test_ds.map(tokenize, batched=True)
if HAS_TRUE_HOLDOUT:
    true_holdout_ds = true_holdout_ds.map(tokenize, batched=True)

data_collator = DataCollatorWithPadding(tokenizer=tokenizer)

# ---------------------------------------------------------------------------
# 3. Model
# ---------------------------------------------------------------------------
model = AutoModelForSequenceClassification.from_pretrained(
    MODEL_NAME,
    num_labels=len(label2id),
    id2label=id2label,
    label2id=label2id,
)

# ---------------------------------------------------------------------------
# 4. Metrics -- macro-averaged, since every department matters equally here
#    regardless of how many examples it has (this is a safety-relevant
#    classifier, not a popularity contest between classes)
# ---------------------------------------------------------------------------
def compute_metrics(eval_pred):
    logits, labels = eval_pred
    preds = np.argmax(logits, axis=1)
    acc = accuracy_score(labels, preds)
    precision, recall, f1, _ = precision_recall_fscore_support(
        labels, preds, average="macro", zero_division=0
    )
    return {
        "accuracy": acc,
        "f1_macro": f1,
        "precision_macro": precision,
        "recall_macro": recall,
    }

# ---------------------------------------------------------------------------
# 5. Train
# ---------------------------------------------------------------------------
training_args = TrainingArguments(
    output_dir=OUTPUT_DIR,
    learning_rate=2e-5,
    per_device_train_batch_size=16,
    per_device_eval_batch_size=32,
    num_train_epochs=4,
    weight_decay=0.01,
    eval_strategy="epoch",
    save_strategy="epoch",
    load_best_model_at_end=True,
    metric_for_best_model="f1_macro",
    logging_steps=20,
    report_to="none",
)

trainer = Trainer(
    model=model,
    args=training_args,
    train_dataset=train_ds,
    eval_dataset=val_ds,
    processing_class=tokenizer,
    data_collator=data_collator,
    compute_metrics=compute_metrics,
)

if __name__ == "__main__":
    trainer.train()

    print("\n=== Template test set results (same generator as train/val) ===")
    test_results = trainer.evaluate(test_ds)
    for k, v in test_results.items():
        print(f"  {k}: {v}")

    if HAS_TRUE_HOLDOUT:
        print("\n=== TRUE holdout results (hand-written, independent of the generator) ===")
        print("This is the honest number to report against your >92% target.")
        true_results = trainer.evaluate(true_holdout_ds)
        for k, v in true_results.items():
            print(f"  {k}: {v}")
        if true_results.get("eval_f1_macro", 1.0) < test_results.get("eval_f1_macro", 0.0) - 0.1:
            print(
                "\n  Gap between template-test and true-holdout performance is large. "
                "That's a sign the model is leaning on template surface patterns rather "
                "than the underlying medical content -- expect this to shrink as you add "
                "real pilot data and more varied phrasing per class."
            )

    trainer.save_model(FINAL_MODEL_DIR)
    tokenizer.save_pretrained(FINAL_MODEL_DIR)
    print(f"\nModel + tokenizer saved to {FINAL_MODEL_DIR}")
    print("Load later with: AutoModelForSequenceClassification.from_pretrained('%s')" % FINAL_MODEL_DIR)

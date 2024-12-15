import os
import torch
from huggingface_hub import snapshot_download
from transformers import AutoTokenizer, AutoModelForTokenClassification, pipeline

API_KEY = "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"
MODEL_ID = "guidobenb/DarkBERT-finetuned-ner"

device = torch.device('cpu')

snapshot_download(repo_id=MODEL_ID)

tokenizer = AutoTokenizer.from_pretrained("guidobenb/DarkBERT-finetuned-ner")
model = AutoModelForTokenClassification.from_pretrained("guidobenb/DarkBERT-finetuned-ner")
model.to(device)

ner_pipeline = pipeline("ner", model=model, tokenizer=tokenizer)

while True:
    text = input("Please enter a sentence: ")
    outputs = model.generate(text)
    result = ner_pipeline(text)
    print(result[0]["generated_text"])
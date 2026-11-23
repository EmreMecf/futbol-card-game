#!/usr/bin/env python3
"""Generate *provisional* vision labels for all unreviewed characters.

Run from the project root:
  python -m pip install -r tool/characters/requirements-vision.txt
  python tool/characters/suggest_positions.py

Produces position_suggestions.csv for ALL 550 illustrations (approved labels
remain untouched in position_audit.csv). Never modifies the game's active
position pools. Classification is probabilistic; GK gloves are distinctive,
but a plain pose does not reliably distinguish DEF / MID / FWD.
"""
import csv
from pathlib import Path

from PIL import Image
import torch
from transformers import CLIPModel, CLIPProcessor

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/v21/characters"
AUDIT = ROOT / "tool/characters/position_audit.csv"
OUT = ROOT / "tool/characters/position_suggestions.csv"
MODEL = "openai/clip-vit-base-patch32"

PROMPTS = {
 "GK": [
  "A cartoon soccer goalkeeper catching the ball with thick padded goalkeeper gloves.",
  "Illustration of a football goalkeeper diving to make a save wearing goalkeeper gloves.",
  "A goalkeeper standing in front of the net with special padded keeper gloves."
 ],
 "DEF": [
  "A cartoon soccer defender performing a sliding tackle.",
  "A football defender with a strong defensive stance stopping an attacker.",
  "A soccer center back protecting the goal, blocking a shot."
 ],
 "MID": [
  "A cartoon football midfielder directing teammates and passing the ball.",
  "A soccer playmaker skillfully controlling the ball in midfield.",
  "An athletic midfield soccer player making a clever pass to a teammate."
 ],
 "FWD": [
  "A cartoon striker kicking the soccer ball toward goal and scoring.",
  "A football forward celebrating scoring a goal.",
  "An attacking soccer winger dribbling past an opponent."
 ],
}
ROLES = tuple(PROMPTS)

def main():
    torch.set_num_threads(min(torch.get_num_threads(), 4))
    processor = CLIPProcessor.from_pretrained(MODEL)
    model = CLIPModel.from_pretrained(MODEL).eval()
    prompts = [p for role in ROLES for p in PROMPTS[role]]
    text_in = processor(text=prompts, return_tensors="pt", padding=True, truncation=True)
    with torch.inference_mode():
        text_features = model.get_text_features(**text_in)
        text_features = text_features / text_features.norm(dim=-1, keepdim=True)
    with AUDIT.open(encoding="utf-8-sig", newline="") as f:
        audit = list(csv.DictReader(f))
    if len(audit) != 550:
        raise RuntimeError(f"Expected 550 audit rows, got {len(audit)}")

    result = []
    for start in range(0, 550, 16):
        chunk = audit[start:start+16]
        images = []
        for item in chunk:
            path = SOURCE / item['filename']
            if not path.is_file():
                raise RuntimeError(f'Missing original art: {path}')
            with Image.open(path) as img:
                rgba = img.convert('RGBA')
                bg = Image.new("RGBA", rgba.size, (28, 20, 46, 255))
                bg.alpha_composite(rgba)
                images.append(bg.convert('RGB'))
        inputs = processor(images=images, return_tensors='pt')
        with torch.inference_mode():
            feats = model.get_image_features(**inputs)
            feats = feats / feats.norm(dim=-1, keepdim=True)
            sims = feats @ text_features.T
            # Average prompts to mitigate a single wording dominating.
            role_scores = torch.stack([
                sims[:, i*3:(i+1)*3].mean(dim=-1)
                for i in range(4)
            ], dim=-1)
            probs = torch.softmax(role_scores * 45, dim=-1)
        for row, pred in zip(chunk, probs.tolist()):
            rank = sorted(range(4), key=lambda k: pred[k], reverse=True)
            top, second = rank[:2]
            role, confidence, margin = ROLES[top], pred[top], pred[top] - pred[second]
            # Strong guards: a top guess does not mean the artwork is certified.
            provisional = confidence >= 0.57 and margin >= 0.17
            if row['review_status'] == 'reviewed':
                suggestion = row['position']
                reason = 'human_reviewed'
            else:
                suggestion = role if provisional else ''
                reason = 'machine_candidate' if provisional else 'ambiguous_needs_visual_review'
            result.append({
                'filename': row['filename'], 'suggested_position': suggestion,
                'top_candidate': role, 'confidence': f'{confidence:.3f}',
                'margin': f'{margin:.3f}', 'review_status': row['review_status'],
                'reason': reason
            })
        print(f'Assessed {min(start+16,550)}/550', flush=True)
    with OUT.open('w', encoding='utf-8', newline='') as f:
        writer=csv.DictWriter(f, fieldnames=list(result[0]))
        writer.writeheader()
        writer.writerows(result)
    print('Saved provisional suggestions:', OUT)
    print('Pending manual review:', sum(r['review_status'] != 'reviewed' for r in result))
    print('WARNING: No AI suggestion is used by the application until human-reviewed.')

if __name__ == '__main__':
    main()

#!/bin/bash
# pia-review.sh <milestone> — codex (azure/gpt-6-luna) review по вехе
M="${1:-M0}"
cd /home/alice/dev/pia
OUT="reviews/$(date +%F-%H%M)-$M-review.md"
nohup codex exec --profile azure \
  -C /home/alice/dev/pia --skip-git-repo-check -s read-only \
  --output-last-message "$OUT" \
  "Ты строгий ревьюер. Проект PIA (ABAP-native coding agent; репо ~/dev/pia; docs/ — архитектура и решения, osg-probe/ — живая проба на OSG, src/ — код $ZPIA). Сделай ревью вехи $M: (1) что сделано и принято, (2) дефекты и риски с приоритетом P1/P2/P3 и указанием файлов/строк, (3) конкретные подсказки: что переиспользовать из ~/dev/pia/zllm-v2, что спросить у OSG-коллеги, что не учитывать. Отвечай по-русски, кратко, только по существу." \
  > "reviews/$(date +%F-%H%M)-$M-raw.log" 2>&1 &
echo "review $M started, pid $!, result -> $OUT"

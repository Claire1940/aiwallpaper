#!/bin/bash
# 用 Kie API (nano-banana-pro) 批量生成壁纸主题图片，替换 ShipAny 模板图片
set -euo pipefail

KIE_API_KEY="a7d921c105b20a425c21090f5619c953"
MODEL="nano-banana-pro"
BASE_URL="https://api.kie.ai/api/v1"
PROJECT_ROOT="/root/cpm/aiwallpaper"
BACKUP_DIR="${PROJECT_ROOT}/tmp/imgs-backup-$(date +%Y%m%d%H%M%S)"
CALLBACK_URL="https://www.aiwallpaper.best/api/ai/callback"
DELAY_SECONDS=15

mkdir -p "${BACKUP_DIR}/features" "${BACKUP_DIR}/bg" "${PROJECT_ROOT}/tmp/generated"

declare -a TASKS=(
  "public/imgs/features/1.png|A sleek text input interface for an AI wallpaper generator app, dark theme with purple accent, futuristic UI design showing a prompt box and generate button"
  "public/imgs/features/2.png|AI model selection dropdown menu in a dark themed app interface, showing multiple AI model options for image generation, clean modern UI"
  "public/imgs/features/3.png|High resolution wallpaper being displayed on a large desktop monitor, vibrant colors, crystal clear 4K quality showcase"
  "public/imgs/features/4.png|Instant download interface showing a beautiful wallpaper being saved, progress bar and download button, dark theme UI"
  "public/imgs/features/5.png|User typing a creative wallpaper description in a text prompt field, minimalist dark interface with glowing cursor"
  "public/imgs/features/6.png|AI model selection interface with model cards and preview thumbnails, dark purple theme, technology aesthetic"
  "public/imgs/features/7.png|AI wallpaper generation in progress, loading animation with preview of stunning wallpaper appearing, dark futuristic interface"
  "public/imgs/features/8.png|A collection of beautiful AI generated wallpapers in a gallery grid layout, cosmic nebula, nature landscape, abstract patterns"
  "public/imgs/features/9.png|AI wallpaper generator feature showcase, text to image conversion process visualization, dark gradient background"
  "public/imgs/features/10.png|Credits and pricing display in a dark themed app, showing credit balance and purchase options, clean fintech UI"
  "public/imgs/features/11.png|Multiple device mockup showing the same AI generated wallpaper on desktop monitor, laptop, tablet and smartphone"
  "public/imgs/features/12.png|Secure vault icon with lock and shield, representing privacy and data security in a dark purple themed interface"
  "public/imgs/features/13.png|Speed and performance dashboard showing fast AI generation times, sleek dark analytics interface with purple charts"
  "public/imgs/bg/tree.jpg|Stunning cosmic nebula with deep purple and blue swirling gases, thousands of distant stars, ultra HD space wallpaper background for website hero section, dramatic lighting"
)

SUCCESS_COUNT=0
FAIL_COUNT=0

echo "=== AI Wallpaper Image Generation ==="
echo "Model: ${MODEL}"
echo "Tasks: ${#TASKS[@]}"
echo "Backup: ${BACKUP_DIR}"
echo ""

for TASK in "${TASKS[@]}"; do
  IFS='|' read -r TARGET PROMPT <<< "$TASK"
  FILENAME=$(basename "$TARGET")

  echo "--- Generating: ${TARGET} ---"

  if [ -f "${PROJECT_ROOT}/${TARGET}" ]; then
    DIR=$(dirname "${TARGET}")
    mkdir -p "${BACKUP_DIR}/${DIR}"
    cp "${PROJECT_ROOT}/${TARGET}" "${BACKUP_DIR}/${TARGET}"
    echo "  Backed up original"
  fi

  RESPONSE=$(curl -s -X POST "${BASE_URL}/jobs/createTask" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${KIE_API_KEY}" \
    -d "$(jq -n --arg m "$MODEL" --arg p "$PROMPT" --arg cb "$CALLBACK_URL" \
      '{model: $m, input: {prompt: $p}, callBackUrl: $cb}')")

  CODE=$(echo "$RESPONSE" | jq -r '.code')
  if [ "$CODE" != "200" ]; then
    echo "  FAILED: $(echo "$RESPONSE" | jq -r '.msg')"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo "  Waiting ${DELAY_SECONDS}s before next request..."
    sleep "${DELAY_SECONDS}"
    continue
  fi

  TASK_ID=$(echo "$RESPONSE" | jq -r '.data.taskId')
  echo "  Task ID: ${TASK_ID}"

  SUCCESS=0
  for i in $(seq 1 24); do
    sleep 10
    STATUS_RESP=$(curl -s "${BASE_URL}/jobs/recordInfo?taskId=${TASK_ID}" \
      -H "Authorization: Bearer ${KIE_API_KEY}")
    STATE=$(echo "$STATUS_RESP" | jq -r '.data.state // empty')

    if [ "$STATE" = "success" ]; then
      SUCCESS=1
      break
    elif [ "$STATE" = "fail" ]; then
      echo "  FAILED: $(echo "$STATUS_RESP" | jq -r '.data.failMsg')"
      break
    fi
    echo "  Waiting... (${i}/24) state=${STATE}"
  done

  if [ "$SUCCESS" != "1" ]; then
    echo "  SKIPPED: generation did not complete"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    sleep "${DELAY_SECONDS}"
    continue
  fi

  IMAGE_URL=$(echo "$STATUS_RESP" | jq -r '.data.resultJson' | jq -r '.resultUrls[0]')
  if [ -z "$IMAGE_URL" ] || [ "$IMAGE_URL" = "null" ]; then
    echo "  FAILED: no image URL in result"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    sleep "${DELAY_SECONDS}"
    continue
  fi

  DEST="${PROJECT_ROOT}/${TARGET}"
  mkdir -p "$(dirname "${DEST}")"
  curl -sL -o "${DEST}" "$IMAGE_URL"
  FILE_SIZE=$(stat -c%s "${DEST}" 2>/dev/null || echo "0")
  echo "  Downloaded: ${FILE_SIZE} bytes → ${DEST}"
  SUCCESS_COUNT=$((SUCCESS_COUNT + 1))

  echo "  Waiting ${DELAY_SECONDS}s before next request..."
  sleep "${DELAY_SECONDS}"
done

echo ""
echo "=== Generation Complete ==="
echo "Success: ${SUCCESS_COUNT} / ${#TASKS[@]}"
echo "Failed: ${FAIL_COUNT}"
echo "Backup directory: ${BACKUP_DIR}"

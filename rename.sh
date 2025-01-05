#!/bin/bash
#
# rename_with_openai.sh
# This script:
#   1) Checks if the PDF already has text (OCR).
#   2) If no text, runs OCR (ocrmypdf).
#   3) Extracts text (pdftotext).
#   4) Uses OpenAI API to get a short filename.
#   5) Renames the resulting PDF accordingly.
#
# Usage: ./rename_with_openai.sh /path/to/file.pdf
#
# Requirements:
#   - ocrmypdf
#   - pdftotext
#   - jq
#   - curl
#   - OPENAI_API_KEY environment variable set export OPENAI_API_KEY=sk-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX


FILE="$1"
if [[ -z "$OPENAI_API_KEY" ]]; then
  echo "Error: OPENAI_API_KEY not set."
  exit 1
fi

if [[ -z "$FILE" || ! -f "$FILE" ]]; then
  echo "Usage: $0 /path/to/file.pdf"
  exit 1
fi

EXT="${FILE##*.}"
[[ "$EXT" != "pdf" ]] && { echo "Error: Not a PDF."; exit 1; }

command -v ocrmypdf >/dev/null 2>&1 || { echo "Error: ocrmypdf missing."; exit 1; }
command -v pdftotext >/dev/null 2>&1 || { echo "Error: pdftotext missing."; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "Error: jq missing."; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "Error: curl missing."; exit 1; }

DIR="$(dirname "$FILE")"
BASE="$(basename "$FILE" .pdf)"

TMPPDF="${DIR}/${BASE}_OCR_$(date +%s).pdf"
TXTTMP="/tmp/${BASE}_$(date +%s).txt"

##############################################################################
# 1) Check if PDF has text already
##############################################################################
echo "Checking if $FILE already contains searchable text..."
# We'll extract text from the original file first
pdftotext "$FILE" "$TXTTMP" 2>/dev/null

# If the resulting text file is very small or empty, we assume there's no OCR text
MIN_CHAR_COUNT=20  # Adjust to taste
CHAR_COUNT=$(wc -m < "$TXTTMP" | tr -d ' ')

if (( CHAR_COUNT < MIN_CHAR_COUNT )); then
  echo "No (or very little) text found. Performing OCR..."
  ocrmypdf --force-ocr "$FILE" "$TMPPDF" || { echo "Error: OCR failed."; rm -f "$TXTTMP"; exit 1; }
  OCR_SOURCE="$TMPPDF"
else
  echo "Text found, skipping OCR."
  OCR_SOURCE="$FILE"
fi

##############################################################################
# 2) Extract text from the OCR source
##############################################################################
echo "Extracting text from $OCR_SOURCE..."
pdftotext "$OCR_SOURCE" "$TXTTMP" || { echo "Error: pdftotext failed."; exit 1; }

##############################################################################
# 3) Ask OpenAI for a descriptive filename
##############################################################################
# Read up to 5000 characters
SNIPPET="$(head -c 5000 "$TXTTMP" | tr -d '\r')"

JSON_PAYLOAD=$(jq -n \
  --arg snippet "$SNIPPET" '
  {
    "model": "gpt-3.5-turbo",
    "messages": [
      {
        "role": "system",
        "content": "You are a helpful assistant that creates concise filenames for cleaning up scanned files. The file names should have short name stating company name and the type of scanned file. Does not need to include the date. And do not include any special characters or file type."
      },
      {
        "role": "user",
        "content": ("Based on this PDF text:\n" + $snippet + "\nReturn a short filename with no special chars.")
      }
    ],
    "max_tokens": 20,
    "temperature": 0.3
  }'
)

echo "Asking OpenAI..."
RESPONSE=$(curl -s https://api.openai.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -d "$JSON_PAYLOAD")

AI_TITLE=$(echo "$RESPONSE" | jq -r '.choices[0].message.content' 2>/dev/null | tr -dc '[:alnum:] _-')
if [[ -z "$AI_TITLE" || "$AI_TITLE" == "null" ]]; then
  AI_TITLE="untitled_${BASE}"
fi

##############################################################################
# 4) Rename the resulting file
##############################################################################
NEWPDF="${DIR}/${AI_TITLE}.pdf"

if [[ "$OCR_SOURCE" == "$TMPPDF" ]]; then
  mv "$TMPPDF" "$NEWPDF"
else
  # If we didn’t run OCR, just rename the original
  mv "$FILE" "$NEWPDF"
fi

rm -f "$TXTTMP"
echo "Renamed to: $NEWPDF"
exit 0

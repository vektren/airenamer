#!/bin/bash
#
# rename_with_openai_for_hazel.sh
# 
# This script is designed to be used with Hazel. It checks if a PDF contains text,
# performs OCR if necessary, and renames the file using OpenAI's API for descriptive names.
#
# Requirements:
# - ocrmypdf
# - pdftotext
# - jq
# - curl
#
# Add this script to Hazel with the condition:
# "If Name contains SCAN, then Run Shell Script"
#
# NOTE: Insert your OpenAI API key below.

###############################################################################
# CONFIGURATION
###############################################################################

# Insert your OpenAI API key here
OPENAI_API_KEY="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"

# Minimum character count to consider a PDF "already has text"
MIN_CHAR_COUNT=20

# Maximum characters sent to OpenAI for processing
MAX_SNIPPET_LENGTH=5000

# PATH configuration
PATH="/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin:$PATH"

###############################################################################
# SCRIPT
###############################################################################

FILE="$1"

# Check if a file was passed
if [[ -z "$FILE" || ! -f "$FILE" ]]; then
  echo "Hazel script error: File not found."
  exit 1
fi

# Bail if not a PDF
EXT="${FILE##*.}"
if [[ "$EXT" != "pdf" ]]; then
  echo "Not a PDF. Exiting."
  exit 0
fi

# Confirm required tools are installed
command -v pdftotext >/dev/null 2>&1 || { echo "Error: pdftotext not installed."; exit 1; }
command -v ocrmypdf  >/dev/null 2>&1 || { echo "Error: ocrmypdf not installed."; exit 1; }
command -v jq        >/dev/null 2>&1 || { echo "Error: jq not installed."; exit 1; }
command -v curl      >/dev/null 2>&1 || { echo "Error: curl not installed."; exit 1; }

# Directory and base name
DIR="$(dirname "$FILE")"
BASE="$(basename "$FILE" .pdf)"

# Temporary file names
TMPPDF="${DIR}/${BASE}_OCR_$(date +%s).pdf"
TXTTMP="/tmp/${BASE}_$(date +%s).txt"

###############################################################################
# STEP 1: Check if the PDF already has text
###############################################################################
echo "Checking for existing PDF text..."
pdftotext "$FILE" "$TXTTMP" 2>/dev/null

CHAR_COUNT=$(wc -m < "$TXTTMP" | tr -d ' ')
if (( CHAR_COUNT < MIN_CHAR_COUNT )); then
  echo "No or minimal text found. Performing OCR..."
  ocrmypdf --force-ocr "$FILE" "$TMPPDF" || { echo "Error: OCR failed."; rm -f "$TXTTMP"; exit 1; }
  OCR_SOURCE="$TMPPDF"
else
  echo "Text found; skipping OCR."
  OCR_SOURCE="$FILE"
fi

###############################################################################
# STEP 2: Extract text from the PDF for OpenAI processing
###############################################################################
echo "Extracting text from $OCR_SOURCE..."
pdftotext "$OCR_SOURCE" "$TXTTMP" || { echo "Error: pdftotext failed."; exit 1; }

# Read up to MAX_SNIPPET_LENGTH characters
SNIPPET="$(head -c $MAX_SNIPPET_LENGTH "$TXTTMP" | tr -d '\r')"

###############################################################################
# STEP 3: Ask OpenAI for a descriptive filename
###############################################################################
echo "Asking OpenAI for a filename..."
JSON_PAYLOAD=$(jq -n \
  --arg snippet "$SNIPPET" '
  {
    "model": "gpt-3.5-turbo",
    "messages": [
      {
        "role": "system",
        "content": "You are a helpful assistant that creates concise filenames for cleaning up scanned files. The file names should have a short name stating the company name and the type of scanned file. Does not need to include the date. And do not include any special characters or file type."
      },
      {
        "role": "user",
        "content": ("Based on this PDF text:\n" + $snippet + "\nReturn a short filename.")
      }
    ],
    "max_tokens": 20,
    "temperature": 0.3
  }'
)

RESPONSE=$(curl -s https://api.openai.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -d "$JSON_PAYLOAD")

AI_TITLE=$(echo "$RESPONSE" | jq -r '.choices[0].message.content' 2>/dev/null | tr -dc '[:alnum:] _-')

# Fallback title if empty or null
if [[ -z "$AI_TITLE" || "$AI_TITLE" == "null" ]]; then
  AI_TITLE="untitled_${BASE}"
fi

###############################################################################
# STEP 4: Rename the file
###############################################################################
# Remove "SCAN" from the filename to prevent Hazel from looping
FINAL_TITLE=$(echo "$AI_TITLE" | sed 's/SCAN//g')

NEWPDF="${DIR}/${FINAL_TITLE}.pdf"

if [[ "$OCR_SOURCE" == "$TMPPDF" ]]; then
  mv "$TMPPDF" "$NEWPDF"
else
  mv "$FILE" "$NEWPDF"
fi

rm -f "$TXTTMP"
# Remove the original file
rm -f "$FILE"
echo "Hazel rename complete: $NEWPDF"
exit 0

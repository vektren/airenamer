# PDF Rename Script with OCR and OpenAI Integration

This script is designed to work to automate the processing of scanned PDF files. It performs OCR (if necessary), extracts meaningful text, and uses OpenAI to generate a concise and descriptive filename. The original file is then renamed and deleted to keep your folder clean and organized.

---

## Features

- **OCR Support:** Uses `ocrmypdf` to add OCR to PDFs that don't already contain text.
- **Filename Generation:** Sends text extracted from the PDF to OpenAI's GPT-3.5-Turbo API to generate a short, meaningful filename.
- **Loop Prevention:** Ensures script does not reprocess renamed files.
- **Clean-Up:** Deletes the original file after processing.

---

## Requirements

- **Tools:**
  - `ocrmypdf` (for OCR processing)
  - `pdftotext` (for text extraction)
  - `jq` (for JSON handling)
  - `curl` (for OpenAI API calls)

- **OpenAI API Key:** You must have an OpenAI API key

---

## Installation

1. Install the required tools:
   ```bash
   # On macOS with Homebrew
   brew install ocrmypdf poppler jq curl
   ```

2. Edit the script and replace the placeholder `OPENAI_API_KEY` with your actual OpenAI API key.

3. Save the script (e.g., `rename_with_openai.sh`) in a location accessible to Hazel.

4. Make the script executable:
   ```bash
   chmod +x /path/to/rename_with_openai_for_hazel.sh
   ```

---

## Hazel Configuration

1. **Create a New Hazel Rule:**
   - **If:**
     - Name contains `SCAN`
   - **Do:**
     - Run shell script: Select the `rename_with_openai.sh` script.

2. **Optional Conditions:**
   - You can customize the rule further, such as only matching specific file types.

---

## OpenAI Prompt

The script uses the following prompt to generate filenames:

```
You are a helpful assistant that creates concise filenames for cleaning up scanned files. The file names should have a short name stating the company name and the type of scanned file. Does not need to include the date. And don't include any special characters or file type.
```

---

## Script Behavior

1. Hazel detects a new file matching the rule (e.g., `SCAN20250105223553.pdf`).
2. The script checks if the file contains text:
   - If not, it performs OCR using `ocrmypdf`.
   - If text is already present, it skips OCR.
3. The script extracts text and sends it to OpenAI for a filename suggestion.
4. The file is renamed based on the OpenAI response and the original file is deleted.

---

## Debugging

- If the script does not work as expected:
  1. Ensure all tools (`ocrmypdf`, `pdftotext`, `jq`, `curl`) are installed and in your PATH.
  2. Manually run the script in the terminal:
     ```bash
     /path/to/rename_with_openai.sh /path/to/testfile.pdf
     ```
  3. Check Hazel's logs for errors.

---

## Example

### Input:
`SCAN20250105223553.pdf`

### Output:
`CompanyName_Invoice.pdf`

---

## Notes

- This script removes the original file after processing. Ensure your Hazel configuration aligns with this behavior.
- The OpenAI API key is stored directly in the script. If this is a concern, consider setting it as an environment variable instead.

---

## License

This script is provided "as-is" without warranty. Use it at your own risk.

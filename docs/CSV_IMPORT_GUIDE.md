# CSV Import Guide for Meditations

## Overview

The CSV import feature allows administrators to batch create meditations by uploading a CSV file. This is particularly useful for importing meditation collections from various authors or sources.

## Accessing the Feature

1. Navigate to the Admin Dashboard at `/admin`
2. Click on "Import Meditations (CSV)" in the Meditations Management section
3. Or go directly to `/admin/meditations/import`

## CSV File Format

Your CSV file must include the following columns:

### Required Columns

- **mystery_name** - The exact name of the mystery (e.g., "The Annunciation")
  - Must match an existing mystery in the database exactly
- **content** - The meditation text/content

### Optional Columns

- **title** - A title for the meditation (optional)
- **author** - The author of the meditation (e.g., "Bishop Fulton J. Sheen")
- **source** - The source of the meditation (e.g., "The Fifteen Mysteries of the Rosary")

## Available Mystery Names

The following mystery names are available (must match exactly):

**Joyful Mysteries:**
- The Annunciation
- The Visitation
- The Nativity
- The Presentation
- The Finding in the Temple

**Sorrowful Mysteries:**
- The Agony in the Garden
- The Scourging at the Pillar
- The Crowning with Thorns
- The Carrying of the Cross
- The Crucifixion

**Glorious Mysteries:**
- The Resurrection
- The Ascension
- The Descent of the Holy Spirit
- The Assumption
- The Coronation

## Sample CSV File

A sample CSV file is provided at `priv/repo/sample_meditations.csv` with three example meditations from Bishop Fulton J. Sheen.

### Example Format

```csv
mystery_name,title,content,author,source
The Annunciation,,"In the Annunciation, the birth of the Son of God...",Bishop Fulton J. Sheen,The Fifteen Mysteries of the Rosary
The Visitation,,"The first miracle worked by our Lord...",Bishop Fulton J. Sheen,The Fifteen Mysteries of the Rosary
```

## Using the Import Feature

1. Prepare your CSV file following the format above
2. Navigate to `/admin/meditations/import`
3. Click "Click to upload CSV file" or drag and drop your CSV file
4. Review the file details shown
5. Click "Import Meditations" to begin the import
6. The system will display:
   - Success messages for meditations that were created
   - Error messages for any meditations that failed validation

## Validation Rules

The system will validate each meditation against the following rules:

- `content` is required and cannot be empty
- `mystery_name` must exactly match an existing mystery in the database
- If the mystery_name doesn't match, you'll see an error message listing the mystery name that wasn't found

## Error Handling

If a meditation fails validation, the error message will include:
- The mystery name that the meditation was intended for
- The specific validation errors (e.g., missing content, mystery not found)

Successfully imported meditations will not be affected by validation errors in other rows.

## Tips for Multi-Line Content

- Meditation content often contains multiple paragraphs
- To include line breaks in your CSV, enclose the entire content field in double quotes (`"`)
- Example:
  ```csv
  mystery_name,content
  The Annunciation,"Paragraph one.

  Paragraph two with a line break above."
  ```

## Notes

- The CSV file must use comma (`,`) as the delimiter
- Text fields with commas or line breaks should be enclosed in double quotes
- To include a quote character within quoted text, double it: `"He said ""Hello"""`
- The first row must be the header row with column names
- Only one CSV file can be uploaded at a time
- You can import multiple meditations for the same mystery (e.g., different authors or perspectives)

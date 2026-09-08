# Compatibility

Social Science Paste currently focuses on text and rich-text clipboard workflows.

## v1.0.0

The stable release supports general text and rich-text clipboard cleaning with independently selectable preservation of:

- Bold
- Italic
- Hyperlinks

It uses copy-time clipboard processing and leaves the destination application's normal paste command untouched.

## v1.0.1-beta

The beta adds compatibility improvements for text copied from Microsoft Word / Office. It is available for users who regularly work with Word and want to help test these workflows.

## Current text-focused scope

The following are currently left untouched:

- Images
- Files
- PDF objects
- Structured tables / spreadsheet ranges

This is deliberate: the current release focuses on reliable text cleaning without damaging structured or non-text content.

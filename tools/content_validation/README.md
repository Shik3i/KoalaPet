# Content Validation

Install the pinned dependency in an isolated environment:

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r tools/content_validation/requirements.txt
.venv/bin/python tools/content_validation/validate_content.py
```

The command validates every manifest and declared entry point in the bundled base pack and neutral example packs. It checks JSON Schema, safe contained paths, duplicate IDs, namespace ownership, localization keys, cross-reference types, and placeholder/runtime asset paths. Errors include files and JSON paths.

# Security and Mod Safety

Initial mod loading treats every pack as untrusted data.

- Normalize paths, reject absolute paths, traversal (`..`), symlink escapes, and roots outside the pack.
- Allowlist JSON and safe media extensions; reject scripts, libraries, executables, and nested executable containers.
- Apply configurable per-file, total-size, file-count, image-dimension, audio-duration, and JSON-depth limits before expensive processing.
- Validate schemas, dependencies, content API ranges, duplicates, explicit overrides, and all cross-references.
- Resolve load order deterministically and report file plus JSON path for errors.
- Keep save writes separate from pack directories and never permit pack data to select arbitrary output paths.
- Preserve missing-content data and require explicit migrations; no silent save overwrite.
- Record source, author/owner, and intended license metadata; metadata is not proof of rights.
- Do not log secrets or arbitrary private filesystem paths in user-facing mod diagnostics.

Later archive import must defend against decompression bombs and extraction traversal. Executable mod support requires a separate threat model and accepted ADR; it is not part of the current architecture.

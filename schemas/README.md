# Draft Content Schemas

JSON Schema 2020-12 contracts for experimental content API `0.1`. They are implemented for Milestone 2 but are not a long-term stability promise. Instances point to their schema with a repository-relative `$schema` path.

Milestone 2 changes: optional manifest `enabled`; exact/`*`/`>=`/`^` pack-version requirements; recursive feature-gate conditions; namespaced feature/reward IDs. No executable payload support was added.

Validate bundled and example packs with:

```sh
python3 tools/content_validation/validate_content.py
```

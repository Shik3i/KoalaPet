# Branding and Product Identity

KoalaPet is a temporary codename. `game/config/product_identity.json` is the provisional single source for user-facing title and future package/store identity. Until build tooling generates engine/export metadata, `game/project.godot` mirrors its display name; changes must update both in one commit and treat the JSON file as authoritative.

Domain names remain neutral (`pet`, `species`, `form`, `evolution`, `habitat`) and never embed the brand. Final name, application identifier, icon, store metadata, and legal attribution remain open. When chosen, update the identity file, add deterministic generation/validation for engine and packaging metadata, and remove the temporary mirror rule.

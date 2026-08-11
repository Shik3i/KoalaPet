# Open Questions

Each item requires product-owner acceptance or spike evidence. Do not treat defaults as final.

| Area | Question | Needed evidence or decision |
|---|---|---|
| Brand | What is the final product name, visual identity, application ID, and store metadata? | Naming and trademark review; centralized brand config design. |
| Care | Are relaxed and classic care profiles both offered, and what differs? | Product decision and pacing prototypes. |
| Lifecycle | How do death, retirement, rebirth, and legacy inheritance work? | Emotional goals, failure/recovery design, save implications. |
| Time | What is the real-time evolution cadence? | Play-session expectations and offline simulations. |
| Combat | What exact automatic/semi-automatic interaction is fun and accessible? | Small prototypes, not speculation. |
| Evolution | How much condition information is hidden, hinted, or fully revealed? | Discovery vs. intentional pursuit user testing. |
| Habitat | Free placement or invisible-grid placement? | Input, collision, save stability, and small-window usability prototype. |
| Content | What are final first-MVP counts for families, forms, moves, items, encounters, dungeons, and themes? | Production-cost and replayability estimates after vertical slice. |
| Windows | Should a status-indicator icon be baseline, and which recovery/actions should it expose? | Prepared generated-icon/menu harness; verify visibility, callbacks, restore, and cleanup on Windows, then obtain product acceptance. |
| Windows | How should taskbar edge, auto-hide, multi-monitor, mixed DPI, and lost-window recovery behave? | Real hardware/VM spike matrix. |
| Windows | Must Minimal be absent from the taskbar and Alt+Tab, or merely unobtrusive? | Godot has no dedicated high-level control identified; test shell behavior and decide whether a narrow native bridge is justified. |
| Windows | Which Minimal interaction strategy preserves both input safety and visual effects? | Compare complete passthrough, polygonal hit region, and timed interaction on Windows; polygonal passthrough may clip drawing outside the region. |
| Windows | Is one reconfigured native window sufficient for all three modes? | Provisional harness choice; measure flicker, focus, clipping, resource lifetime, and transition stress on Windows. |
| Performance | Which renderer and active/idle update rates meet the overlay budget? | Measure Compatibility against another supported Windows renderer and record CPU/GPU/memory before selecting values. |
| Platforms | When, if ever, should Linux and macOS support begin? | Windows architecture findings and platform demand. |
| Licensing | What open-source code license and asset/content licenses apply? | Product-owner/legal choice. No `LICENSE` until chosen. |

## Resolved during Prompt 0

- Development engine pin: Godot `4.7.1.stable.official.a13da4feb`, verified locally and by headless project import. Windows overlay behavior remains unverified and belongs to Prompt 1.

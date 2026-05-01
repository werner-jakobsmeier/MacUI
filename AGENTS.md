# MacUI — AI Agent Instructions

> **Before writing or modifying ANY code in this repository, read `.github/AI_DEVELOPMENT_GUIDELINES.md`.**

This is a World of Warcraft addon for API version **12.0.5 (Midnight)**. The guidelines document is the single source of truth for all coding standards, API compatibility rules, and architectural patterns.

Key constraints:
- Zero external dependencies (no Ace3, no LibDataBroker)
- All APIs must use the modern `C_` namespace with table return handling
- All globals must be upvalued at file scope
- Class modules must early-return for non-matching player classes
- Every frame that can be moved must register in `addonTable.MovableFrames`
- **Zero-Waste Engineering:** Do NOT add unused upvalues or variables 'just in case'.
- **Redundancy Sweep:** Always perform a final pass to remove orphaned code and unused locals before finishing a task.

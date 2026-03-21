# DingDong — Claude Code Context

## Project
Smart doorbell system. ESP32-S3 firmware (C++) + Flutter mobile app + Firebase Cloud Functions.

## Source of Truth
Read docs/PRD.md FULLY before writing any code. Every decision is in there.

## Current Phase
Check git log for latest commit message to understand current progress.
Always read docs/PRD.md Section 10 for the full phase breakdown.

## Critical Rules
1. Never touch google-services.json
2. Never commit .env or any secrets
3. Run flutter analyze after every Flutter change — must be 0 errors
4. Run idf.py build after every firmware change — must be 0 errors
5. All firmware files use .cpp extension (C++), not .c
6. Design system: hunter green #355E3B + amber #F59E0B, light mode, no blue anywhere
7. GPIO pins are finalized in PRD Section 15.2 — do not change them

## Repo Structure
See PRD Section 11 for full structure.

## Firmware Build Setup (Windows)
Before running any idf.py commands, run from repo root:
. .\esp-idf-init.ps1

Only needed for Phase 4+ firmware sessions. Not needed for Flutter or Cloud Function sessions.

## UI Fixes Needed (Session 7)
- Logo: reduce to 3 waves each side (currently 4), make bell slightly taller/fatter
- Login screen: increase spacing between logo and wordmark, slight overlap currently  
- Signup screen: logo can be slightly larger
- Events empty state: improve error state, add proper Lottie empty state animation
- General: app feels plain, consider adding device status dashboard card on home screen
- Consider tagline on login: "Your eyes at the door" under the DingDong wordmark


## Firebase Project
Project ID: dingdong-596c2
Region: us-central1
Android package: com.dingdong.app
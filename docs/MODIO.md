# Eventual mod.io release

Stable mod ID: **cargo_distribution_1**. Working title: **Cargo Distribution**.
Development version: **0.1.4-prototype**. First public version is reserved for a
validated implementation; do not publish this diagnostic build as a working mod.

## Draft listing (use only after acceptance)

Title: Cargo Distribution

Summary: Control how much cargo each stop receives, with percentages based on the
load aboard on arrival and optional filters for each type of goods.

Description draft: Add unloading rules to a line's stops. Keep Automatic — all goods,
or choose exactly which cargo types a stop can receive and give each its own percentage.
Custom stops unload only. For two equal deliveries, unload 50% at the first town and
100% of the remainder at the second. Stops without rules retain the game's usual
behavior. Cargo that cannot be accepted remains aboard. Disable the rules and restore
native settings before removing the mod from a save.

Category/tag: Script Mod. Initial platform: Windows.
Author/creator: **USER SELECTION REQUIRED**. Contributor credits: **REVIEW REQUIRED**.
Reuse license: **USER SELECTION REQUIRED**. Do not imply a license was chosen.

## Required release work

1. Pass the native feasibility gate and full acceptance matrix. Record tested build
   and mod version, results and observed limitations.
2. Finish end-user GUI and documentation; replace the diagnostic line-name workflow.
3. Resolve creator/license fields. Produce original cover art and real screenshots
   of 100→50→0 and 60→30→0 deliveries; do not fabricate proof images. Cover and gameplay
   screenshots have not been created while the gate is pending.
4. Build only owned content. No game archives, executables, proprietary GUI source,
   save files, local test tools or development paths belong in the release ZIP.
5. Put the owned source mod in the game's staging area using the native workflow.
   Run the staging validator and save the full report (including PC/console flags).
   Fix all PC critical errors and review other findings. Record untested platforms.
6. Use the installed native publisher's cooking/packaging workflow, then install the
   resulting package from a clean copy and rerun smoke/acceptance checks.
7. Only after the user explicitly requests account submission/public release, use
   the native mod.io publishing flow. Do not trigger publish as a validation shortcut.

The installed API defines `ModPublishHelper.validate(modId)` as validation-only;
`publish(modId, publishSettings)` validates, cooks and uploads. Its settings include
changeLog, updateMetadata, setPublic, isSavegame, issuesConfirmed and additionalMetadata.
Online examples may have a different signature; use installed build definitions.

Official references:
- [Publishing API](https://wiki.transportfever3.com/script-doc/api/type/modhub.html#Modhub.ModPublishHelper.publish)
- [Transport Fever 3 mod.io community](https://mod.io/g/transportfever3)

Keep the mod ID stable across compatible updates. Increase semantic versions and
native revisions appropriately, and introduce explicit saved-schema migrations when
changing persistent data. A future schema currently fails closed rather than being
silently reset. Keep migration fixtures and test old saves before releasing updates.

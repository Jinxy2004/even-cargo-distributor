# Compatibility

- Target: Transport Fever 3, Windows; installed definitions inspected from build 40408.
- Native runtime validation: pending. Other platforms: untested.
- Mod ID is cargo_distribution_1; saved schema is 2; semantic version 0.1.1-prototype.
- Version 0.1.1 defers arrival commands to a regular update to avoid a native engine
  assertion observed in 0.1.0. Exact native unloading remains unverified.
- Mods that modify the same line stops may conflict with temporary native targets.
- Cst line-name prefix avoids automatic renaming by the installed Auto Line Namer.
- No engine patching or executable modifications.
- This prototype conservatively suspends on route changes and cannot automatically
  relocate saved settings after a changed route. Use the reset procedure beforehand.
- Ordinary lines remain inactive unless explicitly named Cst CD PROBE.

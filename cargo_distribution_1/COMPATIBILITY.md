# Compatibility

- Target: Transport Fever 3, Windows; installed definitions inspected from build 40408.
- Native runtime validation: pending. Other platforms: untested.
- Mod ID is cargo_distribution_1; saved schema is 2; semantic version 0.1.4-prototype.
- Version 0.1.2 runs commands in serial postUpdate. Native arrival callbacks cannot
  open nested transactions (0.1.0 crash), and parallel update forbids callbacks
  (0.1.1 error). Exact native unloading remains unverified.
- Version 0.1.3 translates retained units using allCaps, correcting 0.1.2's use of
  only the compartments currently configured for that cargo. Retest before release.
- Native 0.1.3 delivered 8 of 16 meat at town one. Version 0.1.4 protects event state
  from stale parallel-update writes. Concurrent/mixed-cargo acceptance remains pending.
- Mods that modify the same line stops may conflict with temporary native targets.
- Cst line-name prefix avoids automatic renaming by the installed Auto Line Namer.
- No engine patching or executable modifications.
- This prototype conservatively suspends on route changes and cannot automatically
  relocate saved settings after a changed route. Use the reset procedure beforehand.
- Ordinary lines remain inactive unless explicitly named Cst CD PROBE.

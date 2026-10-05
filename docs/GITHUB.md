# GitHub preparation

The workspace is initialized as a Git repository on branch `main`. There is no
remote and no commit yet. `.gitignore` excludes the local Lua test runtime, generated
ZIPs, saved games, temporary files and the unused sandbox-created Git backup.
`.gitattributes` defines text line endings.

Before the first public push:

1. Choose creator credit and license. Do not publish the placeholder metadata as final.
2. Review native-test status and describe this accurately as a prototype while gated.
3. Review `git status` and the files to include. Source, tools, tests and documentation
   are intended for version control; game installation files and saves are not.
4. Make the initial commit under your chosen Git identity.
5. Create or choose your GitHub repository and set its URL as `origin`, then push `main`.

Repository creation and upload have not been performed. The mod.io release and
GitHub publication are separate actions. The user can choose a private GitHub
repository while development and native tests continue.

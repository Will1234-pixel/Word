# OpenPLC Playground tooling

- `generate.test.ts`: builds `playground/PLC-Playground` with OpenPLC Editor's **own**
  ladder functions (`renderPlaceholderElements` and `addNewElement`, the ones the GUI uses when
  you drop an element on a rung) and its own `.ld` serializer. So the files are exactly what
  the editor would save. To regenerate the project:
  1. Clone <https://github.com/Autonomy-Logic/openplc-editor> (it was built against 4.3.1).
  2. Run `npm ci --ignore-scripts && npm run setup:strucpp`.
  3. Copy this file to `src/__playground__/`.
  4. Run `PLAYGROUND_OUT=/path/to/PLC-Playground npx jest --config jest.config.json src/__playground__/generate.test.ts`.
- Compile check: `openplc-cli compile <project>` (the editor's headless CLI; see its
  `docs/CLI.md`). This builds the same simulator firmware as the Play button.
- `playground-logic.st` / `.test`: the Structured Text that the editor generated from the
  ladder (copied from the build output), with 25 behaviour checks for `plctest`.

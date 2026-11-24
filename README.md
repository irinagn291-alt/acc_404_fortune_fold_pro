# Fortune Fold

Fortune Fold (acc_404) is a native, offline paper-folding puzzle for iPhone and iPad. Open [FortuneFold.xcodeproj](FortuneFold.xcodeproj), select the shared **FortuneFold** scheme and run it on an iOS 17 or later destination. The factory handoff copy is in [StoreCopy.json](StoreCopy.json).

The campaign contains 16 sheets in Letters, Lanterns, Rooftops and Palace. Drag a cut edge to fold it, or tap it and use a physical left or right arrow. Press the seal when the marks align. The tiger walks until it reaches the gate or the next interruption. Further folds can let it cross from that point. Undo restores the previous fold, layer order and tiger position. The album keeps the best print and adds a gold impression at par.

The app saves one current sheet and the album to its sandbox. The first installation starts at the Whiskers envelope. The development locale is en-GB, with en-US, ar, zh-Hans and zh-Hant also included. The sheet itself keeps its physical orientation in right-to-left layouts.

## Build inputs

- [FoldApp.swift](FortuneFold/FoldApp.swift) contains the entry point, desk, album, player controls, sound and saving.
- [Paper.swift](FortuneFold/Paper.swift) contains the rules, state, Undo, records and hint search.
- [SheetView.swift](FortuneFold/SheetView.swift) contains the paper, illustrations, folding gestures and tiger presentation.

[Campaign.json](FortuneFold/Resources/Campaign.json), the five localisations, the app icon and the four sound files are bundled resources. The [compiler source list](../../artifacts/genesis/local.fortune-fold.acc404/motion-review/qa/compiled-sources.txt) and [app bundle inventory](../../artifacts/genesis/local.fortune-fold.acc404/motion-review/qa/app-bundle.txt) show the actual inputs and payload. The QA directory contains author solutions and test scripts.

## Local QA

Set `FF_EVIDENCE_ROOT` to an evidence directory outside the project and `FF_RAW_ROOT` to a temporary directory for raw captures. Run `bash QA/verify-rules.sh` to check the brook and all author solutions against the product rules. For UI testing, run the entire [foreground script](QA/simulator-qa.sh) under the factory simulator pool with the iPhone or iPad template and the argument `phone` or `pad`. The [motion review](../../artifacts/genesis/local.fortune-fold.acc404/motion-review/REPORT.md) links the accepted tests and selected media.

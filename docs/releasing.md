# Releasing

1. Update `pixi.toml`, `conda.recipe/recipe.yaml`, the dated changelog entry,
   and compatibility notes for `X.Y.Z`. Keep Mojo and ShuhaFFT exact and equal
   across Pixi and the recipe's build, host, and run requirements.
2. Run `pixi lock --check`, `pixi run --locked check`, and
   `pixi run --locked package` on a clean tree.
3. Create an annotated tag for the exact tested commit with
   `git tag -a vX.Y.Z -m "Nami vX.Y.Z"`.
4. Wait for the tag workflow to validate the release contract, run checks and
   installed-package tests on all supported native platforms, and create the
   GitHub source release.
5. Run the `mojo-channel` repository's build workflow with repository `nami`,
   ref `vX.Y.Z`, and publishing enabled. Verify all three channel subdirectories
   resolve and install the exact emitted archive.
6. Publish benchmark results only with the checked-in methodology.

The tag workflow rejects lightweight tags, commits not already in `origin/main`,
and any mismatch among the tag, package versions, exact dependency pins, and
dated changelog entry. Channel publication remains a separate reviewed workflow
so source repositories do not receive cross-repository write credentials.

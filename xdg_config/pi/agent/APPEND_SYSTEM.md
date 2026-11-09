## Codemode

The `codemode` tool lets the model write a JavaScript script that calls pi's other tools and runs non-LLM models, such as classifiers and image models.

- Prefer `codemode` than `bash` when executing code.

## Use classifier models

`classifier` is pi's model type. System One decision models such as TypeSafe Jev are classifiers:
call them from codemode with `models.getModelOfType("classifier", ...)` and
`models.classify(model, { state, questions })`.

## Use image models

Image models also run only through codemode: call `models.generateImages(model, { input })`,
then show each image block in `result.output` with `image()`.

# Categorization evaluation

These synthetic memos cover all supported categories and a mixed memo where professional work is the dominant topic. They are classification inputs, not transcription examples. Each `.category` file gives the expected single category label.

Run only this suite with `make evals STAGE=categorize`; it processes the inputs sequentially through the CLI evaluation batch, reusing one loaded Qwen model with fresh contexts and samplers. Compare each generated JSON manifest to its paired expected category and review the choice against the memo content. Model output can vary, so a structural pass does not replace semantic review.

# Categorization evaluation

These synthetic memos cover all supported categories and a mixed memo where professional work is the dominant topic. They are classification inputs, not transcription examples. Each `.category` file gives the expected single category label.

Run only this suite with `bash scripts/run-evals.sh --categorize`; it calls the actual local-model `cl categorize` command once per input, sequentially. Compare each generated JSON manifest to its paired expected category and review the choice against the memo content. Model output can vary, so a structural pass does not replace semantic review.

# Comparison findings · 2026-11-05

This is an error-location review, not a new verified reference or semantic quality pass. Prior owner decisions and the active transcription baseline are unchanged. The other four recordings remain outside active transcription evals.

For corrected Dutch, the preserved Large-v2 transcript has WER 3.66% (44/1,203); newly generated Large-v3 has WER 2.99% (36/1,203). Both outputs use the same corrected audio SHA-256. These compare Large-v2/CoreML with quantized Large-v3/whisper.cpp, not an isolated model-version experiment. Full word alignments are in `scores/`.

The earlier checklist missed differences. For example, Large-v2 changes the opening “onderzoeksstation” to “onderzoekstation”. The new selector finds this near the start without any prewritten passage definition. It also selects number/compound spelling changes, which contribute to WER but may preserve meaning.

Large-v3 fixes Large-v2’s “Vanmorgen” → “Voor morgen”, correctly recognizes “Keiko haalde” and “metingen beïnvloedt”, and does not append the Korean sign-off. However, it introduces an unsupported six-word machine-room phrase after “Later kwam”, changes “iets gegeten” to “niets gegeten” (reversing the statement), and changes “wij vergelijken” to “daar zijn” (losing the comparison action). It shares the “tijdelijk” → “duidelijk” error with Large-v2, which loses the temporary nature of the information gap. Its closing “ook al” → “maar dan” also changes the relationship between the clauses. Names and terms still acquire spelling errors. The generated Large-v3 text and full aligned edits were read against the verified reference; listening verification of new discrepancies remains with the owner.

Every generated passage must contain at least one text difference in one or both model excerpts. Selection starts from the full alignments, includes insertions at the final word boundary, and checks that every global edit is covered by a passage. No verification is inferred from two models agreeing. Audio times come from Large-v3 segment estimates with context padding, so listening boundaries remain approximate.

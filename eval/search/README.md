# Semantic-search evaluation fixture

This corpus is synthetic and contains no user data. The opt-in real-model test uses the
same topics to check multilingual retrieval with the pinned E5 model:

```bash
CAPTAINS_LOG_SEARCH_INTEGRATION=1 swift run run-tests
```

`queries.json` records the intended first result for each query. Keep individual outcomes
visible when tuning chunking or changing models; do not replace them with only one average
score.

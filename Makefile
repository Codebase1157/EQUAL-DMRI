.PHONY: help install test audit strict results splits tables train evaluate check clean

help:
	@echo "make install   install the package and dev extras"
	@echo "make test      run the test suite (83 tests)"
	@echo "make audit     run the build gate"
	@echo "make strict    run the build gate in submission mode (placeholders fail)"
	@echo "make results   rebuild the labelled result store"
	@echo "make splits    write subject-level split manifests"
	@echo "make tables    regenerate every table from the store"
	@echo "make check     test + audit, the full gate"

install:
	pip install -e ".[dev]"

test:
	python -m pytest tests/ -q

audit:
	python audit/audit.py

strict:
	python audit/audit.py --strict

results:
	python scripts/init_results.py --summary

splits:
	python scripts/make_splits.py

tables:
	python scripts/build_tables.py --out docs/TABLES.md

train:
	python scripts/train.py --steps 50

evaluate:
	python scripts/evaluate.py --fields 8 --cases 40

# The audit found that final_check.sh ignored failures inside pipes, so a failed
# audit could not stop the build. These recipes fail on the first failing step.
check:
	@set -e; \
	python -m pytest tests/ -q; \
	python audit/audit.py

clean:
	find . -name __pycache__ -type d -exec rm -rf {} + 2>/dev/null || true
	rm -rf .pytest_cache results/checkpoints

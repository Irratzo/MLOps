# Makefile

.PHONY: help
help:
	@echo "Commands:"
	@echo "install            : installs requirements."
	@echo "install-dev        : installs development requirements."
	@echo "install-test       : installs test requirements."
	@echo "venv               : set up the virtual environment for development"
	@echo "assets             : load and prepare assets."
	@echo "app                : launches FastAPI app with uvicorn worker"
	@echo "app-prod           : launches FastAPI app with uvicorn workers managed by guincorn"
	@echo "test               : runs all tests."
	@echo "test-non-training  : runs tests that don't involve training."
	@echo "style              : runs style formatting."
	@echo "clean              : cleans all unecessary files."
	@echo "docs               : serve generated documentation."

# Installation
.PHONY: install
install:
	python -m pip install -e .

.PHONY: install-dev
install-dev:
	python -m pip install -e ".[dev]"
	pre-commit install

.PHONY: install-test
install-test:
	python -m pip install -e ".[test]"

venv:
	python3 -m venv ${name}
	source ${name}/bin/activate && \
	python -m pip install --upgrade pip setuptools wheel && \
	make install-dev
	@echo "Run 'source ${name}/bin/activate'"

# Pull data
.PHONY: assets
assets:
	dvc pull
	tagifai fix-artifact-metadata

# Applications
.PHONY: app
app:
	uvicorn app.api:app --host 0.0.0.0 --port 5000 --reload --reload-dir tagifai --reload-dir app

.PHONY: app-prod
app-prod:
	gunicorn -c config/gunicorn.py -k uvicorn.workers.UvicornWorker app.api:app

.PHONY: mlflow
mlflow:
	mlflow server -h 0.0.0.0 -p 5000 --backend-store-uri experiments/

.PHONY: streamlit
streamlit:
	streamlit run streamlit/app.py



# Tests
.PHONY: great-expectations
great-expectations:
	great_expectations checkpoint run projects
	great_expectations checkpoint run tags

.PHONY: test
test: great-expectations
	pytest --cov tagifai --cov app --cov-report html

.PHONY: test-non-training
test-non-training: great-expectations
	pytest -m "not training"

# Styling
.PHONY: style
style:
	black .
	flake8
	isort .

# Cleaning
.PHONY: clean
clean:
	tagifai clean-experiments --experiments-to-keep "best"
	find . -type f -name "*.DS_Store" -ls -delete
	find . | grep -E "(__pycache__|\.pyc|\.pyo)" | xargs rm -rf
	find . | grep -E ".pytest_cache" | xargs rm -rf
	find . | grep -E ".ipynb_checkpoints" | xargs rm -rf
	rm -f .coverage

# Documentation
.PHONY: docs
docs:
	python -m mkdocs serve

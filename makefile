# ==========================================
# Collections MIS Project Makefile
# ==========================================

# Variables
PYTHON = python
DOCKER = docker-compose

# Default target when just typing 'make'
.PHONY: help
help:
	@echo "🏦 Collections MIS Project Commands:"
	@echo "-----------------------------------"
	@echo "make setup    - Install Python dependencies"
	@echo "make generate - Run the Python data generator (v7)"
	@echo "make db-up    - Spin up the PostgreSQL & pgAdmin Docker containers"
	@echo "make db-down  - Spin down the Docker containers"
	@echo "make etl      - Run the ETL pipeline to load data into the database"
	@echo "make clean    - Remove generated CSV files and Python cache"
	@echo "make full-run - Run the entire pipeline (generate -> db-up -> etl)"

# 1. Environment Setup
.PHONY: setup
setup:
	@echo "📦 Installing requirements..."
	pip install -r requirements.txt

# 2. Data Generation
.PHONY: generate
generate:
	@echo "🎲 Generating synthetic banking data..."
	$(PYTHON) 01_data_sources/data_generator_v7.py
	@echo "✅ Data generation complete. Check scotiabank_refined/ folder."

# 3. Database Management
.PHONY: db-up
db-up:
	@echo "🐳 Starting database containers..."
	$(DOCKER) up -d
	@echo "✅ Database is running on localhost:5432. pgAdmin is on localhost:5050."

.PHONY: db-down
db-down:
	@echo "🛑 Stopping database containers..."
	$(DOCKER) down

# 4. ETL Pipeline
.PHONY: etl
etl:
	@echo "🔄 Running ETL pipeline..."
	$(PYTHON) 03_etl/load_data.py
	@echo "✅ Data successfully loaded into PostgreSQL."

# 5. Cleanup utility
.PHONY: clean
clean:
	@echo "🧹 Cleaning up generated files..."
	rm -rf 01_data_sources/scotiabank_refined/*.csv
	find . -type d -name "__pycache__" -exec rm -rf {} +
	@echo "✅ Cleanup complete."

# 6. The "One-Click" Demo
.PHONY: full-run
full-run: generate db-up etl
	@echo "🚀 Full pipeline executed successfully!"
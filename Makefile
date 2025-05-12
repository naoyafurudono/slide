# Makefile for marp presentation builds

SRCDIR := source
OUTDIR := out
MD_FILES := $(wildcard $(SRCDIR)/*.md)
PDF_FILES := $(patsubst $(SRCDIR)/%.md,$(OUTDIR)/%.pdf,$(MD_FILES))
MARPCMD := marp
MARPOPTS := --pdf --allow-local-files

all: $(OUTDIR) $(PDF_FILES) ## Build PDFs for all markdown files (one-time build)

$(OUTDIR):
	mkdir -p $(OUTDIR)

$(OUTDIR)/%.pdf: $(SRCDIR)/%.md $(OUTDIR) ## Build PDF for specific chapter (e.g., make 1.pdf)
	$(MARPCMD) $< -o $@ $(MARPOPTS)

build-%: $(OUTDIR) ## Build PDF for specific chapter (e.g., make build-1)
	$(MARPCMD) $(SRCDIR)/$*.md -o $(OUTDIR)/$*.pdf $(MARPOPTS)

watch-%: $(OUTDIR) ## Watch specific chapter and rebuild on changes (e.g., make watch-1)
	$(MARPCMD) $(SRCDIR)/$*.md -o $(OUTDIR)/$*.pdf $(MARPOPTS) --watch

watch: $(OUTDIR) ## Watch all markdown files and rebuild on changes
	$(MARPCMD) $(SRCDIR) -o $(OUTDIR) $(MARPOPTS) --watch

clean: ## Remove all generated PDFs
	rm -rf $(OUTDIR)

list: ## Show all available chapters
	@echo "Available chapters:"
	@for file in $(MD_FILES); do \
		basename=$$(basename "$${file}" .md); \
		echo " - $${basename}"; \
	done

help: ## Show this help message with all available commands
	@echo "Available commands:"
	@grep -E '^[a-zA-Z0-9_%-]+:.*## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*## "}; {printf "  make %-15s %s\n", $$1, $$2}'

.PHONY: all build-% watch watch-% clean list help $(OUTDIR)

.PHONY: help view view-h hyprland app test lint fmt install pack tag
.DEFAULT_GOAL := help

help: ## list targets
	@awk 'BEGIN{FS=":.*##"} /^[a-z][a-zA-Z0-9_-]+:.*##/ {printf "  make %-10s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

view: ## preview widget (planar)
	@if command -v nix >/dev/null 2>&1 && [ -f flake.nix ]; then \
	  nix run .#view; \
	else \
	  plasmoidviewer -a package -f planar; \
	fi

view-h: ## preview widget (horizontal)
	@if command -v nix >/dev/null 2>&1 && [ -f flake.nix ]; then \
	  nix run .#view -- horizontal; \
	else \
	  plasmoidviewer -a package -f horizontal; \
	fi

install: ## install test copy to local Plasma session
	@./test_install.sh

pack: ## build .plasmoid archive
	@if command -v nix >/dev/null 2>&1 && [ -f flake.nix ]; then \
	  nix run .#pack; \
	else \
	  ver=$$(grep -oE '"Version":[[:space:]]*"[^"]+"' package/metadata.json | head -1 | sed -E 's/.*"([^"]+)"$$/\1/'); \
	  name=$$(basename "$$PWD"); \
	  out="$$PWD/$$name-$$ver.plasmoid"; \
	  rm -f "$$out"; \
	  (cd package && zip -r "$$out" . -x '*.swp' '*~' 'icon-emblem.png'); \
	  echo "wrote $$out"; \
	fi

tag: ## open a release PR (bump version); merging it tags + publishes
	@./tag.sh

app: ## run the standalone window + tray app (any desktop)
	nix run path:.#nixdatifier

hyprland: ## run the Quickshell popup, pill and tray
	nix run path:.#hyprland

test: ## isolated QML interactions and shell-helper checks
	./tests/run.sh

lint: ## static checks: ruff, shellcheck, qmllint, qmlformat, unused code
	./scripts/lint.sh

fmt: ## format QML and Python in place
	find package hyprland shell.qml standalone tests -name '*.qml' | xargs qmlformat -i
	ruff format .

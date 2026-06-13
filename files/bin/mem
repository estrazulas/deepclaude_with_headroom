#!/usr/bin/env bash
# Helper script for /mem command
# Lista e busca nas memórias persistentes do projeto

MEMORY_DIR="$HOME/.claude/projects/-home-estrazulas/memory"

if [ $# -eq 0 ]; then
  echo "=== MEMÓRIAS SALVAS ==="
  echo ""
  for f in "$MEMORY_DIR"/*.md; do
    [ "$(basename "$f")" = "MEMORY.md" ] && continue
    name=$(basename "$f" .md)
    desc=$(sed -n '/^description:/ { s/description: //; p; q; }' "$f")
    echo "  📄 $name"
    echo "     → $desc"
    echo ""
  done
  echo "Use /mem <termo> para ver o conteúdo completo"
else
  query="$*"
  FILE=$(grep -il "$query" "$MEMORY_DIR/"*.md 2>/dev/null | grep -v MEMORY.md | head -1)
  if [ -n "$FILE" ]; then
    NAME=$(basename "$FILE" .md)
    DESC=$(sed -n '/^description:/ { s/description: //; p; q; }' "$FILE")
    echo "=== $NAME ==="
    echo "→ $DESC"
    echo "──────────────────────────────────────"
    sed '1,/^---$/d' "$FILE" | sed '1,/^---$/d'
  else
    echo "Nenhuma memória encontrada para: $query"
  fi
fi

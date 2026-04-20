#!/bin/bash
# Regenera os slash commands em .claude/commands/ a partir de squads/
# Gera dois tipos de comandos:
#   1. /squad-name           → Chief orquestra, todos os agentes carregados
#   2. /squad-name--agente   → Agente direto com contexto do squad
#
# Uso: bash scripts/regenerate-commands.sh

cd "$(dirname "$0")/.."

rm -f .claude/commands/*.md
mkdir -p .claude/commands

count_individual=0
count_squad=0

# Helper: append squad context (config, data, checklists, workflows, tasks)
append_squad_context() {
  local squad_dir="$1"

  if [ -f "$squad_dir/squad.yaml" ]; then
    echo "## Squad Definition"
    echo '```yaml'
    cat "$squad_dir/squad.yaml"
    echo '```'
    echo ""
  fi

  # Support both config/config.yaml and config.yaml at root
  local config_file=""
  if [ -f "$squad_dir/config/config.yaml" ]; then
    config_file="$squad_dir/config/config.yaml"
  elif [ -f "$squad_dir/config.yaml" ]; then
    config_file="$squad_dir/config.yaml"
  fi
  if [ -n "$config_file" ]; then
    echo "## Squad Configuration"
    echo '```yaml'
    cat "$config_file"
    echo '```'
    echo ""
  fi

  if [ -d "$squad_dir/data" ]; then
    for data_file in "$squad_dir"data/*.yaml; do
      if [ -f "$data_file" ]; then
        echo "## Data: $(basename "$data_file")"
        echo '```yaml'
        cat "$data_file"
        echo '```'
        echo ""
      fi
    done
  fi

  if [ -d "$squad_dir/checklists" ]; then
    for checklist_file in "$squad_dir"checklists/*.md; do
      if [ -f "$checklist_file" ]; then
        echo "## Checklist: $(basename "$checklist_file")"
        cat "$checklist_file"
        echo ""
      fi
    done
  fi

  if [ -d "$squad_dir/workflows" ]; then
    for wf_file in "$squad_dir"workflows/*.yaml; do
      if [ -f "$wf_file" ]; then
        echo "## Workflow: $(basename "$wf_file")"
        echo '```yaml'
        cat "$wf_file"
        echo '```'
        echo ""
      fi
    done
  fi

  if [ -d "$squad_dir/tasks" ]; then
    for task_file in "$squad_dir"tasks/*.md; do
      if [ -f "$task_file" ]; then
        echo "## Task: $(basename "$task_file")"
        cat "$task_file"
        echo ""
      fi
    done
  fi
}

for squad_dir in squads/*/; do
  squad_name=$(basename "$squad_dir")

  if [ "$squad_name" = "_example" ] || [ ! -d "$squad_dir/agents" ]; then
    continue
  fi

  # ─── 1. SQUAD COMMAND (chief + all agents) ───
  cmd_file=".claude/commands/${squad_name}.md"
  {
    echo '$ARGUMENTS'
    echo ""
    echo "---"
    echo ""
    echo "# SQUAD: $squad_name"
    echo ""
    echo "You are the Chief/Orchestrator of this squad. Analyze the user request and decide which agent(s) to activate. You may use one agent or combine multiple agents for complex requests. Always state which agent(s) you are activating and why."
    echo ""

    append_squad_context "$squad_dir"

    echo "# === AGENTS ==="
    echo ""

    # Chief/chair first
    for agent_file in "$squad_dir"agents/*chief*.md "$squad_dir"agents/*chair*.md; do
      if [ -f "$agent_file" ]; then
        agent_name=$(basename "$agent_file" .md)
        echo "## AGENT: $agent_name (ORCHESTRATOR)"
        echo ""
        cat "$agent_file"
        echo ""
        echo "---"
        echo ""
      fi
    done

    # Then all other agents
    for agent_file in "$squad_dir"agents/*.md; do
      agent_name=$(basename "$agent_file" .md)
      case "$agent_name" in *chief*|*chair*) continue ;; esac
      echo "## AGENT: $agent_name"
      echo ""
      cat "$agent_file"
      echo ""
      echo "---"
      echo ""
    done

  } > "$cmd_file"
  count_squad=$((count_squad + 1))

  # ─── 2. INDIVIDUAL AGENT COMMANDS ───
  for agent_file in "$squad_dir"agents/*.md; do
    agent_name=$(basename "$agent_file" .md)
    cmd_file=".claude/commands/${squad_name}--${agent_name}.md"

    {
      echo '$ARGUMENTS'
      echo ""
      echo "---"
      echo ""
      echo "# === SQUAD CONTEXT ==="
      echo ""

      append_squad_context "$squad_dir"

      echo "# === ACTIVE AGENT ==="
      echo ""
      cat "$agent_file"

    } > "$cmd_file"

    count_individual=$((count_individual + 1))
  done
done

echo "Regenerated $count_squad squad commands + $count_individual individual agent commands in .claude/commands/"

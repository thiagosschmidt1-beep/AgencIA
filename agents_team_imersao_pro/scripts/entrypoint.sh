#!/usr/bin/env bash
# PID-1 inside the Fly Machine. Boots supercronic which then schedules the
# campaign runner. See docs/specs/flyio-cron-campaign-runner.md §3.4.

set -euo pipefail

CLAUDE_CRED="/home/runner/.claude/.credentials.json"

if [[ ! -f "${CLAUDE_CRED}" ]]; then
  cat <<'EOF' >&2
WARN: Claude Code OAuth credentials are NOT seeded.
The cron will fail until you log in via the EasyPanel console:

  > claude        # follow the OAuth flow; close after success

EOF
fi

# Configura o MCP do Meta Ads automaticamente usando a env var META_ADS_MCP_TOKEN.
# Sem isso, o token se perde ao reiniciar o container.
if [[ -n "${META_ADS_MCP_TOKEN:-}" ]]; then
  claude mcp add --transport http meta-ads \
    'https://meta-ads-mcp-xi.vercel.app/mcp' \
    --header "Authorization: Bearer ${META_ADS_MCP_TOKEN}" \
    2>/dev/null || true
  echo "INFO: meta-ads MCP configured." >&2
else
  echo "WARN: META_ADS_MCP_TOKEN not set — meta-ads MCP will not be available." >&2
fi

# -passthrough-logs forwards each job's stdout/stderr to our stdout (captured
# by container logs). supercronic does not overlap a job with itself by default.
exec supercronic -passthrough-logs /app/crontab

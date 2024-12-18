// /middleware.ts
import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";

// Types for script configuration
type ScriptTemplate = {
  path: string; // Path in GitHub repo
  packages: string[]; // Required nix packages
  description?: string; // Optional description for root page
};

// Script registry
const scripts: Record<string, ScriptTemplate> = {
  "protect-branches": {
    path: "protect-branches.sh",
    packages: ["gh", "parallel", "jq"],
    description: "Protect main/master branches in all public repositories",
  },
};

// Error response helper
const errorResponse = (message: string, status: number = 404) => {
  return new Response(message, {
    status,
    headers: {
      "Content-Type": "text/plain",
      "Cache-Control": "no-cache",
    },
  });
};

// Root page helper
const rootPageResponse = () => {
  const scriptList = Object.entries(scripts)
    .map(
      ([name, config]) => `${name}: ${config.description || "No description"}`
    )
    .join("\n");

  return new Response(
    `Available scripts:\n\n${scriptList}\n\nUsage: bash <(curl -L https://scripts.aloshy.ai/SCRIPT_NAME)`,
    {
      headers: {
        "Content-Type": "text/plain",
        "Cache-Control": "public, max-age=3600",
      },
    }
  );
};

export const config = {
  matcher: "/:script*",
};

export default async function middleware(req: NextRequest) {
  // Get script name from URL
  const scriptName = req.nextUrl.pathname.slice(1).toLowerCase();

  // Handle root path
  if (!scriptName) {
    return rootPageResponse();
  }

  // Validate script name
  if (scriptName.includes("/") || scriptName.includes(".")) {
    return errorResponse("Invalid script name", 400);
  }

  // Check if script exists
  const scriptConfig = scripts[scriptName];
  if (!scriptConfig) {
    return errorResponse(
      `Script '${scriptName}' not found.\n\nAvailable scripts:\n${Object.keys(
        scripts
      ).join("\n")}`
    );
  }

  // Validate script configuration
  if (!scriptConfig.packages?.length || !scriptConfig.path) {
    return errorResponse("Invalid script configuration", 500);
  }

  // Generate nix-shell wrapper
  const nixWrapper = `#!/usr/bin/env bash

# Error handling
set -euo pipefail
trap 'echo "❌ Error: Command failed at line $LINENO"' ERR

# Check for nix-shell
if ! command -v nix-shell >/dev/null 2>&1; then
    echo "❌ nix-shell not found!"
    echo "Please install Nix first:"
    echo "Linux/Mac: curl -L https://nixos.org/nix/install | sh"
    echo "More info: https://nixos.org/download.html"
    exit 1
fi

# Check internet connectivity
if ! curl -s --head https://raw.githubusercontent.com >/dev/null; then
    echo "❌ No internet connection or GitHub is unreachable"
    exit 1
fi

# If not in nix-shell, restart in nix-shell
if [[ -z "\${IN_NIX_SHELL:-}" ]]; then
    echo "🔄 Starting nix-shell with required packages..."
    exec nix-shell -p ${scriptConfig.packages.join(
      " "
    )} --run "bash <(curl -L https://raw.githubusercontent.com/aloshy-ai/scripts/main/${
    scriptConfig.path
  })"
fi

set -euo pipefail`;

  // Return script with appropriate headers
  return new Response(nixWrapper, {
    headers: {
      "Content-Type": "text/x-shellscript",
      "Cache-Control": "no-cache",
      "X-Content-Type-Options": "nosniff",
      "X-Frame-Options": "DENY",
      "X-Script-Name": scriptName,
    },
  });
}

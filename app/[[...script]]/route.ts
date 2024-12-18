import { NextResponse } from 'next/server';
import scripts from '../../scripts/index.json';

export async function GET(
  request: Request,
  { params }: { params: Promise<{ script: string }> }
) {
  const script = (await params).script;
  
  // Check if the script exists in our index
  if (!scripts.includes(script)) {
    return NextResponse.json(
      { error: `Script not found: '${script}' | See https://nixhub.aloshy.ai/index for available scripts` },
      { status: 404 }
    );
  }

  const command = `nix-shell -p gh parallel jq --run "bash <(curl -L https://raw.githubusercontent.com/aloshy-ai/nixhub/refs/heads/main/scripts/${script})"\n`;

  return new Response(command, {
    status: 200,
    headers: {
      "Content-Type": "text/x-shellscript",
      "Cache-Control": "no-cache",
    },
  });
}
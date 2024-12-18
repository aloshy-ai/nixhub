export async function GET(
    request: Request,
    { params }: { params: Promise<{ script: string }> }
  ) {

    const script = (await params).script

    if (!script) {
      return new Response(`Script cannot be blank`, {
        status: 404,
      })
    }

    const command = `nix-shell -p gh parallel jq --run "bash <(curl -L https://raw.githubusercontent.com/aloshy-ai/nixhub/refs/heads/main/scripts/${script}.sh)"\n`

    return new Response(command, {
      status: 200,
      headers: {
        "Content-Type": "text/x-shellscript",
        "Cache-Control": "no-cache",
      },
    })
  }
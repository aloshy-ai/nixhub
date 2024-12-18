export const config = {
  runtime: "edge",
};

export default async function handler(request: Request) {
  try {
    const script = new URL(request.url).pathname;
    if (!script) {
      return new Response("No script specified", {
        status: 400,
        headers: { "Content-Type": "text/plain" },
      });
    }

    return new Response(`Requested script: ${script}`, {
      status: 200,
      headers: { "Content-Type": "text/plain" },
    });
  } catch (e: any) {
    console.error(`${e.message}`);
    return new Response(`Failed to process request`, {
      status: 500,
      headers: { "Content-Type": "text/plain" },
    });
  }
}
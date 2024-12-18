import { NextRequest, NextResponse } from 'next/server'

export const runtime = 'edge'

export async function GET(request: NextRequest) {
  try {
    const script = request.nextUrl.pathname;
    if (!script) {
      return NextResponse.json(
        { error: "No script specified" },
        { status: 400 }
      );
    }

    return new NextResponse(`Requested script: ${script}`, {
      status: 200,
      headers: {
        "Content-Type": "text/plain",
        "Cache-Control": "no-store"
      },
    });
  } catch (error) {
    // Proper type for error
    const e = error as Error;
    console.error(`Error processing request: ${e.message}`);
    
    return NextResponse.json(
      { error: "Failed to process request" },
      { status: 500 }
    );
  }
}
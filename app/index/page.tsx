'use client';

export default function Error({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  return (
    <div className="min-h-screen bg-black text-white flex flex-col items-center justify-center p-8">
      <div className="text-center">
        <h2 className="text-2xl font-bold mb-4">Something went wrong!</h2>
        <p className="mb-4 text-gray-400">{error.message}</p>
        <button
          onClick={reset}
          className="bg-white text-black px-4 py-2 rounded-md hover:bg-gray-200 transition-colors"
        >
          Try again
        </button>
      </div>
    </div>
  );
}
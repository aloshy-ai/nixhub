'use client';

import { Copy } from 'lucide-react';
import { useState } from 'react';

export function CopyButton({ command }: { command: string }) {
  const [copied, setCopied] = useState(false);

  const copyToClipboard = async () => {
    try {
      await navigator.clipboard.writeText(command);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000); // Reset after 2 seconds
    } catch (err) {
      console.error('Failed to copy:', err);
    }
  };

  return (
    <button
      onClick={copyToClipboard}
      className={`absolute top-2 right-2 p-2 hover:bg-gray-800 rounded-md transition-colors ${
        copied ? 'text-green-400' : ''
      }`}
      aria-label="Copy to clipboard"
    >
      <Copy className="w-4 h-4" />
    </button>
  );
} 
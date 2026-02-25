import "./globals.css";

export const metadata = {
  title: "Lumio",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <head>
        <title>Lumio</title>
      </head>
      <body className="min-h-screen bg-white text-gray-900">{children}</body>
    </html>
  );
}

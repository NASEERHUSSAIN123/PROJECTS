import "./globals.css";

export const metadata = {
  title: "Calendly Clone",
  description: "Book meetings easily",
};

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      {/* ✅ Removed ${geistSans.variable} and ${geistMono.variable} */}
      <body className="antialiased"> 
        {children}
      </body>
    </html>
  );
}
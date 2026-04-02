import Link from "next/link";

export default function Home() {
  return (
    <div className="min-h-screen flex flex-col items-center justify-center bg-gray-100 p-10">
      <h1 className="text-4xl font-extrabold mb-6 text-gray-800">Calendly Clone</h1>

      <div className="flex gap-4">
        <Link
          href="/register"
          className="text-white bg-blue-600 hover:bg-blue-700 px-6 py-3 rounded-md transition"
        >
          Register
        </Link>

        <Link
          href="/login"
          className="text-white bg-green-600 hover:bg-green-700 px-6 py-3 rounded-md transition"
        >
          Login
        </Link>
      </div>
    </div>
  );
}
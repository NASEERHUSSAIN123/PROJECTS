"use client";

import { useState, useEffect } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";

export default function Dashboard() {
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [loggedInUser, setLoggedInUser] = useState(null);
  const router = useRouter();

  useEffect(() => {
    // 1. Get the current logged-in user from storage
    const currentSessionUser = localStorage.getItem("username");
    setLoggedInUser(currentSessionUser);

    // 2. Fetch all users from the API
    const fetchUsers = async () => {
      try {
        const res = await fetch("/api/users");
        if (!res.ok) throw new Error("Failed to fetch users");
        const data = await res.json();

        // 3. Filter out yourself so you only see other people to book with
        const others = Array.isArray(data) 
          ? data.filter(u => u.username !== currentSessionUser) 
          : [];
        
        setUsers(others);
      } catch (err) {
        console.error("Dashboard fetch error:", err);
      } finally {
        setLoading(false);
      }
    };

    fetchUsers();
  }, []);

  const handleLogout = () => {
    localStorage.removeItem("username");
    router.push("/login");
  };

  if (loading) return <div className="p-10 flex justify-center">Loading users...</div>;

  return (
    <div className="min-h-screen bg-gray-50 p-8">
      <div className="max-w-4xl mx-auto">
        <div className="flex justify-between items-center mb-8">
          <div>
            <h1 className="text-3xl font-bold text-gray-900">Book a Meeting</h1>
            <p className="text-gray-500">Welcome back, <span className="font-semibold text-blue-600">{loggedInUser}</span></p>
          </div>
          
          <div className="flex gap-4">
            <button 
              onClick={() => router.push(`/${loggedInUser}/bookings`)}
              className="bg-white border px-4 py-2 rounded-lg text-sm font-medium hover:bg-gray-50"
            >
              My Dashboard
            </button>
            <button 
              onClick={handleLogout}
              className="bg-red-50 text-red-600 px-4 py-2 rounded-lg text-sm font-medium hover:bg-red-100"
            >
              Logout
            </button>
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {users.length === 0 ? (
            <p className="col-span-full text-center text-gray-500 py-20 bg-white rounded-2xl border-2 border-dashed">
              No other users found on the platform yet.
            </p>
          ) : (
            users.map((user) => (
              <div key={user.id} className="bg-white p-6 rounded-2xl shadow-sm border border-gray-100 hover:shadow-md transition-shadow">
                <div className="w-12 h-12 bg-blue-100 rounded-full flex items-center justify-center text-blue-600 font-bold text-xl mb-4">
                  {user.username[0].toUpperCase()}
                </div>
                <h3 className="text-lg font-bold text-gray-800">{user.username}</h3>
                <p className="text-sm text-gray-500 mb-4">Available for bookings</p>
                
                <Link
                  href={`/${user.username}`}
                  className="block w-full text-center bg-blue-600 text-white py-2 rounded-lg font-medium hover:bg-blue-700 transition"
                >
                  Book Now
                </Link>
              </div>
            ))
          )}
        </div>
      </div>
    </div>
  );
}
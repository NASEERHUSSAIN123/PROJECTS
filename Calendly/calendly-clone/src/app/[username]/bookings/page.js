"use client";
import { useEffect, useState } from "react";
import { useParams, useRouter } from "next/navigation";

export default function UserBookings() {
  const { username } = useParams(); // The user in the URL (e.g., /naseer/bookings)
  const router = useRouter();
  const [bookings, setBookings] = useState([]);
  const [isAuthorized, setIsAuthorized] = useState(false);

  useEffect(() => {
    const loggedInUser = localStorage.getItem("username");

    // ✅ CHECK 1: If no one is logged in, send to login page
    if (!loggedInUser) {
      router.push("/login");
      return;
    }

    // ✅ CHECK 2: If the wrong user is logged in, redirect to THEIR dashboard
    if (loggedInUser !== username) {
      alert("Access Denied: You can only view your own bookings.");
      router.push(`/${loggedInUser}/bookings`);
      return;
    }

    setIsAuthorized(true);
  }, [username, router]);

  useEffect(() => {
    // Only fetch if authorized AND we have a valid username
    if (!isAuthorized || !username) return;

    fetch(`/api/bookings/${username}`)
      .then((res) => {
        if (!res.ok) throw new Error("Failed to load");
        return res.json();
      })
      .then((data) => setBookings(Array.isArray(data) ? data : []))
      .catch(err => console.error(err));
  }, [isAuthorized, username]);

  if (!isAuthorized) return <div className="p-10 text-center">Checking permissions...</div>;

  // ✅ Logout Logic
  const handleLogout = () => {
    localStorage.removeItem("username"); // Clear the session
    router.push("/login"); // Send back to login page
  };

  return (
    <div className="min-h-screen bg-gray-50 p-8">
      <div className="max-w-2xl mx-auto">
        <div className="flex justify-between items-center mb-8">
          <h1 className="text-3xl font-bold text-gray-900">Your Bookings</h1>
          
          {/* ✅ The Logout Button */}
          <button 
            onClick={handleLogout}
            className="bg-red-50 text-red-600 px-4 py-2 rounded-lg font-medium hover:bg-red-100 transition border border-red-200"
          >
            Logout
          </button>
        </div>

        <div className="space-y-4">
          {bookings.length === 0 ? (
            <div className="text-center py-10 bg-white rounded-xl border border-dashed border-gray-300">
              <p className="text-gray-500">No bookings scheduled yet.</p>
            </div>
          ) : (
            bookings.map((b) => (
              <div key={b.id} className="bg-white p-6 rounded-xl shadow-sm border border-gray-100 flex justify-between items-center">
                <div>
                  <p className="text-sm font-semibold text-blue-600 uppercase tracking-wide">Guest: {b.guestName}</p>
                  <p className="text-xl font-bold text-gray-800 mt-1">
                    {new Date(b.startTime).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                  </p>
                  <p className="text-sm text-gray-500">
                    {new Date(b.startTime).toLocaleDateString(undefined, { weekday: 'long', month: 'long', day: 'numeric' })}
                  </p>
                </div>
                
                <button 
                  onClick={() => {
                    const invite = `Meeting with ${username}\nTime: ${new Date(b.startTime).toLocaleString()}\nGuest: ${b.guestName}`;
                    navigator.clipboard.writeText(invite);
                    alert("Invite copied!");
                  }}
                  className="text-gray-400 hover:text-blue-600 transition"
                >
                  🔗 Copy Invite
                </button>
              </div>
            ))
          )}
        </div>

        <div className="mt-8 text-center">
          <button 
            onClick={() => router.push(`/${username}`)}
            className="text-gray-500 hover:text-gray-800 text-sm"
          >
            ← View My Public Booking Page
          </button>
        </div>
      </div>
    </div>
  );
}
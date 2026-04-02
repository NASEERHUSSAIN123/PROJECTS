"use client";

import { useState, useEffect } from "react";
import { useParams, useRouter } from "next/navigation";

export default function BookingPage() {
  const params = useParams();
  const router = useRouter();
  const username = params.username;

  // --- State Management ---
  const [selectedTime, setSelectedTime] = useState("");
  const [selectedDate, setSelectedDate] = useState(new Date());
  const [user, setUser] = useState(null);
  const [bookedSlots, setBookedSlots] = useState([]);
  const [loading, setLoading] = useState(false);
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");

  const times = ["09:00 AM", "10:00 AM", "11:00 AM", "12:00 PM", "02:00 PM", "03:00 PM"];

  // --- 1. Define loadBookings at the top level (Fixes ReferenceError) ---
  const loadBookings = async () => {
    if (!username) return;
    try {
      const res = await fetch(`/api/bookings/${username}`);
      if (!res.ok) throw new Error("Failed to fetch bookings");
      const data = await res.json();
      setBookedSlots(Array.isArray(data) ? data : []);
    } catch (err) {
      console.error("Booking fetch error:", err);
    }
  };

  // --- 2. Combined Data Fetching ---
  useEffect(() => {
    if (!username) return;

    // Fetch Host User Profile
    fetch(`/api/user/${username}`)
      .then((res) => res.json())
      .then((data) => {
        // Handle both single object and array responses
        const userData = Array.isArray(data) ? data[0] : data;
        if (userData && userData.id) {
          setUser(userData);
        }
      })
      .catch((err) => console.error("User load error:", err));

    loadBookings();
  }, [username]);

  // --- 3. Logic: Check if slot is in the Past or already Taken ---
  const isSlotDisabled = (timeString) => {
  const [t, mod] = timeString.split(" ");
  let [h] = t.split(":").map(Number);
  if (mod === "PM" && h !== 12) h += 12;
  if (mod === "AM" && h === 12) h = 0;

  const slotDate = new Date(selectedDate);
  slotDate.setHours(h, 0, 0, 0);

  // 1. Past time check (already implemented)
  if (slotDate < new Date()) return true;

  // 2. Global Check: If ANY guest has booked this host for this hour
  return bookedSlots.some((b) => {
    const bStart = new Date(b.startTime);
    
    // We compare Year, Month, Day, and Hour
    return (
      bStart.getFullYear() === slotDate.getFullYear() &&
      bStart.getMonth() === slotDate.getMonth() &&
      bStart.getDate() === slotDate.getDate() &&
      bStart.getHours() === slotDate.getHours()
    );
  });
};

  // --- 4. Booking Submission ---
  const book = async () => {
    if (!user?.id) {
      alert("Host data still loading. Please wait a moment.");
      return;
    }

    if (!selectedTime || !name || !email) {
      alert("Please fill all fields and select a time.");
      return;
    }

    setLoading(true);

    // Calculate Start/End times
    const [t, mod] = selectedTime.split(" ");
    let [h] = t.split(":").map(Number);
    if (mod === "PM" && h !== 12) h += 12;
    if (mod === "AM" && h === 12) h = 0;

    const start = new Date(selectedDate);
    start.setHours(h, 0, 0, 0);
    const end = new Date(start);
    end.setHours(start.getHours() + 1);

    try {
      const res = await fetch("/api/book", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          userId: user.id,
          name,
          email,
          startTime: start.toISOString(),
          endTime: end.toISOString(),
        }),
      });

      if (!res.ok) {
        const errorData = await res.json();
        throw new Error(errorData.error || "Booking failed");
      }

      // Success Redirect
      router.push(`/${username}/bookings`);
    } catch (err) {
      alert(err.message);
      loadBookings(); // Refresh UI to gray out the slot if it was just taken
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-100 p-4">
      <div className="bg-white shadow-lg rounded-2xl p-8 w-full max-w-md">
        <h1 className="text-2xl font-bold text-center mb-1">{username}</h1>
        {/* Optional Logout Button at the bottom or corner */}
<div className="fixed bottom-4 right-4">
  <button 
    onClick={() => {
      localStorage.removeItem("username");
      window.location.href = "/login";
    }}
    className="bg-white text-gray-600 shadow-lg px-4 py-2 rounded-full text-sm font-medium hover:bg-gray-50 border border-gray-200"
  >
    Logout of Dashboard
  </button>
</div>
        <div className="flex justify-center mb-4">
          <button
            onClick={() => {
              navigator.clipboard.writeText(window.location.href);
              alert("Link copied!");
            }}
            className="text-blue-600 text-xs bg-blue-50 px-3 py-1 rounded-full hover:bg-blue-100"
          >
            🔗 Copy booking link
          </button>
        </div>

        <div className="bg-gray-50 p-2 rounded text-center mb-4">
          <p className="text-[10px] text-gray-400 uppercase tracking-widest">Your Timezone</p>
          <p className="text-xs text-gray-600 font-medium">
            {Intl.DateTimeFormat().resolvedOptions().timeZone}
          </p>
        </div>

        <div className="space-y-3">
          <input
            placeholder="Your Name"
            className="border p-3 w-full rounded-lg"
            value={name}
            onChange={(e) => setName(e.target.value)}
          />

          <input
            placeholder="Your Email"
            className="border p-3 w-full rounded-lg"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
          />

          <input
            type="date"
            className="border p-3 w-full rounded-lg"
            // ✅ Prevent selecting past dates in calendar
            min={new Date().toISOString().split("T")[0]}
            value={selectedDate.toLocaleDateString('en-CA')} 
            onChange={(e) => setSelectedDate(new Date(e.target.value))}
          />
        </div>

        <div className="grid grid-cols-2 gap-2 my-6">
          {times.map((time) => {
            const disabled = isSlotDisabled(time);
            const isSelected = selectedTime === time;
            
            return (
              <button
                key={time}
                disabled={disabled}
                onClick={() => setSelectedTime(time)}
                className={`p-3 rounded-lg border text-sm font-medium transition ${
                  disabled
                    ? "bg-gray-100 text-gray-400 cursor-not-allowed border-gray-200"
                    : isSelected
                    ? "bg-blue-600 text-white border-blue-600 shadow-md"
                    : "bg-white hover:border-blue-500 text-gray-700"
                }`}
              >
                {time}
              </button>
            );
          })}
        </div>

        <button
          onClick={book}
          disabled={loading || !user?.id}
          className={`w-full p-4 rounded-xl font-bold text-white transition shadow-lg ${
            loading || !user?.id 
              ? "bg-gray-400 cursor-not-allowed" 
              : "bg-blue-600 hover:bg-blue-700 active:scale-95"
          }`}
        >
          {!user?.id ? "Loading Host..." : loading ? "Confirming..." : "Confirm Booking"}
        </button>
      </div>
    </div>
  );
}
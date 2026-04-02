export async function POST(req) {
  try {
    const body = await req.json();
    console.log("Incoming Booking Request:", body); // ✅ Check your terminal for this!

    const { userId, name, email, startTime, endTime } = body;

    // 1. Check if all data exists
    if (!userId || !name || !startTime) {
      return new Response(JSON.stringify({ error: "Missing required fields" }), { status: 400 });
    }

    const start = new Date(startTime);
    const end = new Date(endTime);

    // 2. Conflict Check (Overlap)
    const conflict = await prisma.booking.findFirst({
      where: {
        userId: userId,
        startTime: start,
      },
    });

    if (conflict) {
      return new Response(JSON.stringify({ error: "Slot already taken" }), { status: 409 });
    }

    // 3. Create
    const booking = await prisma.booking.create({
      data: {
        guestName: name,
        guestEmail: email,
        startTime: start,
        endTime: end,
        user: { connect: { id: userId } }
      }
    });

    return new Response(JSON.stringify(booking), { status: 201 });

  } catch (error) {
    // ✅ This log will tell you exactly why the 500 is happening
    console.error("POST /api/book ERROR:", error); 
    return new Response(JSON.stringify({ error: "Server Error", details: error.message }), { status: 500 });
  }
}
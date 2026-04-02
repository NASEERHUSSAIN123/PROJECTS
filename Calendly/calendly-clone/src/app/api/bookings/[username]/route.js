import { prisma } from "../../../../lib/db";

// src/app/api/bookings/[username]/route.js

export async function GET(req, context) {  
  // FIX: In Next.js 15/16, params is a Promise. You MUST await it.
  const params = await context.params; 
  const username = params.username;

  if (!username) {
    return new Response(JSON.stringify({ error: "Username is missing" }), { 
      status: 400,
      headers: { "Content-Type": "application/json" }
    });
  }

  try {
    const user = await prisma.user.findUnique({
      where: { username: username },
      include: { bookings: true }
    });

    if (!user) {
      return new Response(JSON.stringify({ error: "User not found" }), { status: 404 });
    }

    return new Response(JSON.stringify(user.bookings), { 
      status: 200,
      headers: { "Content-Type": "application/json" }
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: "Database error" }), { status: 500 });
  }
}
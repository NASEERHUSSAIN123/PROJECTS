import { prisma } from "../../../lib/db";

export async function GET() {
  try {
    const users = await prisma.user.findMany({
      select: { username: true, id: true } // Don't send passwords!
    });
    return new Response(JSON.stringify(users), { status: 200 });
  } catch (error) {
    return new Response(JSON.stringify({ error: "Failed to fetch users" }), { status: 500 });
  }
}
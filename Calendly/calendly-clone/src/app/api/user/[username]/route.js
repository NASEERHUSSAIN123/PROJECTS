import { prisma } from "../../../../lib/db";

export async function GET(req, context) {
  try {
    // Next.js 15+ requirement: await params
    const { username } = await context.params;

    const user = await prisma.user.findUnique({
      where: { username },
      select: {
        id: true,
        username: true,
        // add any other fields you need for the profile
      }
    });

    if (!user) {
      return new Response(JSON.stringify({ error: "User not found" }), { status: 404 });
    }

    return new Response(JSON.stringify(user), { status: 200 });
  } catch (error) {
    return new Response(JSON.stringify({ error: "Server error" }), { status: 500 });
  }
}
import { prisma } from "../../../lib/db";

export async function POST(req) {
  const { id } = await req.json();

  await prisma.booking.delete({
    where: { id },
  });

  return Response.json({ success: true });
}
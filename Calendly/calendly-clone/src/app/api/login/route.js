import { prisma } from "../../../lib/db";

import bcrypt from "bcryptjs";
import { signToken } from "../../../lib/auth";

export async function POST(req) {
  const body = await req.json();
  const user = await prisma.user.findUnique({ where: { email: body.email } });
  if (!user) return new Response("Invalid credentials", { status: 401 });

  const valid = await bcrypt.compare(body.password, user.password);
  if (!valid) return new Response("Invalid credentials", { status: 401 });

  const token = signToken(user);

  return new Response(JSON.stringify({ token, username: user.username }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
}
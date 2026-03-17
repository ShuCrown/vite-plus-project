import { Hono } from "hono";
import { cors } from "hono/cors";

export interface Env {
  DB: D1Database;
  ENVIRONMENT?: string;
}

const app = new Hono<{ Bindings: Env }>();

app.use(
  "*",
  cors({
    origin: "*",
    allowMethods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allowHeaders: ["Content-Type", "Authorization"],
  }),
);

app.get("/api/health", (c) => {
  return c.json({
    ok: true,
    timestamp: new Date().toISOString(),
    environment: c.env.ENVIRONMENT || "unknown",
  });
});

app.get("/api/users", async (c) => {
  try {
    const { results } = await c.env.DB.prepare(
      "SELECT * FROM users ORDER BY created_at DESC",
    ).all();
    return c.json({
      success: true,
      data: results,
      count: results?.length || 0,
    });
  } catch (error) {
    return c.json(
      {
        success: false,
        error: error instanceof Error ? error.message : "Database error",
      },
      500,
    );
  }
});

app.post("/api/users", async (c) => {
  try {
    const body = await c.req.json();
    const { name, email } = body;

    if (!name || !email) {
      return c.json(
        {
          success: false,
          error: "name and email are required",
        },
        400,
      );
    }

    const result = await c.env.DB.prepare(
      "INSERT INTO users (name, email) VALUES (?, ?) RETURNING *",
    )
      .bind(name, email)
      .first();

    return c.json(
      {
        success: true,
        data: result,
      },
      201,
    );
  } catch (error) {
    return c.json(
      {
        success: false,
        error: error instanceof Error ? error.message : "Database error",
      },
      500,
    );
  }
});

app.get("/api/users/:id", async (c) => {
  try {
    const id = c.req.param("id");
    const result = await c.env.DB.prepare("SELECT * FROM users WHERE id = ?").bind(id).first();

    if (!result) {
      return c.json(
        {
          success: false,
          error: "User not found",
        },
        404,
      );
    }

    return c.json({
      success: true,
      data: result,
    });
  } catch (error) {
    return c.json(
      {
        success: false,
        error: error instanceof Error ? error.message : "Database error",
      },
      500,
    );
  }
});

export default app;

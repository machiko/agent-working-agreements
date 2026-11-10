export function dbConfig(env = process.env) {
  return { host: env.DB_HOST ?? 'localhost', port: Number(env.DB_PORT ?? 5432) };
}

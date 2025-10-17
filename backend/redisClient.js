const { createClient } = require("redis");
require("dotenv").config();

const REDIS_URL = process.env.REDIS_URL;

const client = createClient({ url: REDIS_URL });

client.on("error", (err) => console.error("Redis Client Error", err));

async function connectRedis() {
  if (!client.isOpen) {
    await client.connect();
    console.log("Connected to Redis");
  }
}

module.exports = { client, connectRedis };

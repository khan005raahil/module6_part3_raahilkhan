
const express = require("express");
const { MongoClient } = require("mongodb");

const app = express();
const port = Number(process.env.PORT) || 3000;

const mongoUri = process.env.MONGO_URI || "mongodb://mongo:27017/bank_app";

app.get("/api/transactions", async (req, res) => {
  try {
    const client = new MongoClient(mongoUri);
    await client.connect();

    const db = client.db();
    const users = await db.collection("users").find({}).toArray();

    await client.close();

    res.json({
      message: "Pixel River Financial Bank Services - Transactions Report",
      users: users
    });
  } catch (error) {
    res.status(500).json({
      error: "Unable to retrieve transactions",
      details: error.message
    });
  }
});

app.listen(port, "0.0.0.0", () => {
  console.log(`Transactions service running on port ${port}`);
});
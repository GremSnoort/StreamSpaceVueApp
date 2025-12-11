const express = require("express");
const jsonServer = require("json-server");

const server = express();
const router = jsonServer.router("db.json");
const middlewares = jsonServer.defaults();

const mediaRouter = require("./media.js");

server.use((req, res, next) => {
  res.header("Access-Control-Allow-Origin", "http://localhost:5173");
  res.header("Access-Control-Allow-Credentials", "true");
  res.header("Access-Control-Allow-Methods", "GET,POST,PUT,PATCH,DELETE,OPTIONS");
  res.header("Access-Control-Allow-Headers", "Content-Type, Authorization");

  if (req.method === "OPTIONS") return res.sendStatus(200);
  next();
});

server.use(express.json());
server.use(express.urlencoded({ extended: true }));

server.use(middlewares);

// Custom routes BEFORE json-server
server.use("/media", mediaRouter);

// Static video files
server.use("/videos", express.static("uploads/videos"));
server.use("/previews", express.static("uploads/previews"));

// json-server routes
server.use(router);

server.listen(3001, () => {
  console.log("Mock API running on http://localhost:3001");
});

import express from 'express';
import cors from 'cors';

const app = express();
const port = 3000;

app.use(cors({
  origin: "*",
  methods: ["GET","POST","PUT","PATCH","DELETE","OPTIONS"],
  allowedHeaders: ["Content-Type","Authorization"],
  credentials: false
}));

app.use(express.json());

// Fallback: ensure CORS headers are always present even if a proxy strips them.
app.use((req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,PUT,PATCH,DELETE,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type,Authorization');
  // Do not set Access-Control-Allow-Credentials here since credentials is false
  if (req.method === 'OPTIONS') {
    // Respond to preflight requests immediately
    return res.sendStatus(204);
  }
  next();
});

app.get('/', (req, res) => {
  res.send('Hello World!');
});

app.post('/api/sum', (req, res) => {
    if (!req.body) {
        return res.status(400).json({ error: 'No data provided' });
    } else {
        const { a, b } = req.body;
        if (typeof a !== 'number' || typeof b !== 'number') {
            return res.status(400).json({ error: 'Invalid input, please provide two numbers' });
        }

        const result = a + b;
        console.log(`Sum of ${a} and ${b} is ${result}`);
        res.json({ result });
    }
});

app.listen(port, () => {
  console.log('Listening on port', port);
});

export default app;
import express from 'express';
import cors from 'cors';

const app = express();
const port = 3000;

app.use(cors({
  origin: true,
  methods: ["GET","POST","PUT","PATCH","DELETE","OPTIONS"],
  allowedHeaders: ["Content-Type","Authorization"],
  credentials: true
}));

app.options("*", cors({
  origin: true,
  methods: ["GET","POST","PUT","PATCH","DELETE","OPTIONS"],
  allowedHeaders: ["Content-Type","Authorization"],
  credentials: true
}));

app.use(express.json());

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

module.exports = app;
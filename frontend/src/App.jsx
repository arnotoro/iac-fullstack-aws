import {useState} from 'react';
import "./App.css";


function App() {
  const [a, setA] = useState("");
  const [b, setB] = useState("");
  const [result, setResult] = useState(null);
  const [error, setError] = useState(null);
  const apiUrl = import.meta.env.VITE_API_URL || 'http://localhost:3000';

  const calculate = async () => {
    setError(null);
    setResult(null);

    if (a === "" || b === "") {
      setError("please enter two numbers");
      return;
    }

    try {
      const response = await fetch(`${apiUrl}/api/sum`, {
        method: 'POST',
        mode: 'cors',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          a: Number(a),
          b: Number(b)
        })
      });

      if (!response.ok) {
        const err = await response.json();
        throw new Error(err.error || 'error calculating sum');
      }

      const data = await response.json();
      setResult(data.result);
    } catch (err) {
      setError(err.message || 'failed to connect to backend');
    }
  };

  return (
    <div style={{
        display: "flex",
        justifyContent: "center",
        alignItems: "center",
        flexDirection: "column",
        height: "100vh"
      }}>
      <h1>Simple fullstack calculator app</h1>
      <div >
        <input
          className='input-field'
          type="number"
          placeholder="Enter first number"
          value={a}
          onChange={(e) => setA(e.target.value)}
        />

        <input
          className='input-field'
          type="number"
          placeholder="Enter second number"
          value={b}
          onChange={(e) => setB(e.target.value)}
        />
 
      <button onClick={calculate}>Submit</button>

      {error && <p>{error}</p>}
      {result !== null && (
        <p>result from backend: {result}</p>
      )}
      </div>
    </div>
  )
};

export default App;
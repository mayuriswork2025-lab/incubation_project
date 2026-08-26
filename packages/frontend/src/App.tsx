import { useEffect, useState } from "react";
import StartupsTable from "./StartupsTable";

const apiUrl = import.meta.env.VITE_API_URL ?? "http://localhost:3001";

export default function App() {
  const [message, setMessage] = useState("Loading...");

  useEffect(() => {
    fetch(`${apiUrl}/api/hello`)
      .then((res) => res.json())
      .then((data) => setMessage(data.message))
      .catch(() => setMessage("Could not reach the backend."));
  }, []);

  return (
    <main style={{ fontFamily: "sans-serif", padding: "2rem" }}>
      <h1>Startup Incubator</h1>
      <p>Backend says: {message}</p>
      <h2>Startups</h2>
      <StartupsTable />
    </main>
  );
}

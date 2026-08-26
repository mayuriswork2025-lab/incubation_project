import { useEffect, useState } from "react";

const apiUrl = import.meta.env.VITE_API_URL ?? "http://localhost:3001";

interface Startup {
  startupId: number;
  startupName: string;
  domain: string | null;
  description: string | null;
  registrationDate: string | null;
  registrationStatus: string | null;
  currentStage: string | null;
  registeredBy: string | null;
}

export default function StartupsTable() {
  const [startups, setStartups] = useState<Startup[]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    fetch(`${apiUrl}/api/startups`)
      .then((res) => res.json())
      .then((data) => setStartups(data))
      .catch(() => setError("Could not load startups."));
  }, []);

  if (error) return <p>{error}</p>;

  return (
    <table style={{ borderCollapse: "collapse", width: "100%" }}>
      <thead>
        <tr>
          <th style={cellStyle}>ID</th>
          <th style={cellStyle}>Name</th>
          <th style={cellStyle}>Domain</th>
          <th style={cellStyle}>Description</th>
          <th style={cellStyle}>Registration Date</th>
          <th style={cellStyle}>Status</th>
          <th style={cellStyle}>Stage</th>
        </tr>
      </thead>
      <tbody>
        {startups.map((s) => (
          <tr key={s.startupId}>
            <td style={cellStyle}>{s.startupId}</td>
            <td style={cellStyle}>{s.startupName}</td>
            <td style={cellStyle}>{s.domain}</td>
            <td style={cellStyle}>{s.description}</td>
            <td style={cellStyle}>{s.registrationDate}</td>
            <td style={cellStyle}>{s.registrationStatus}</td>
            <td style={cellStyle}>{s.currentStage}</td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}

const cellStyle: React.CSSProperties = {
  border: "1px solid #ccc",
  padding: "0.5rem",
  textAlign: "left",
};

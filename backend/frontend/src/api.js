const API_BASE = 'http://localhost:5001/api';

export async function getDefaultProfiles() {
  const res = await fetch(`${API_BASE}/default-profiles`);
  return res.json();
}

export async function getProfiles() {
  const res = await fetch(`${API_BASE}/profiles`);
  return res.json();
}

export async function createProfile(profile) {
  const res = await fetch(`${API_BASE}/profiles`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(profile),
  });
  return res.json();
}

export async function updateProfile(id, profile) {
  const res = await fetch(`${API_BASE}/profiles/${id}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(profile),
  });
  return res.json();
}

export async function deleteProfile(id) {
  await fetch(`${API_BASE}/profiles/${id}`, { method: 'DELETE' });
}

export async function generateXML(id) {
  const res = await fetch(`${API_BASE}/generate-xml/${id}`);
  return res.text();
} 
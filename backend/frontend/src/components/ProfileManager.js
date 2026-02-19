import React, { useEffect, useState } from 'react';
import { Box, Typography, Button, List, ListItem, ListItemText, IconButton, Divider, Snackbar, Alert } from '@mui/material';
import DeleteIcon from '@mui/icons-material/Delete';
import { getProfiles, createProfile, deleteProfile } from '../api';

export default function ProfileManager({ config, setConfig, defaultProfiles, selectedProfile, setSelectedProfile }) {
  const [profiles, setProfiles] = useState([]);
  const [message, setMessage] = useState('');
  const [error, setError] = useState('');

  const loadProfiles = () => {
    getProfiles().then(setProfiles);
  };

  useEffect(() => {
    loadProfiles();
  }, []);

  const handleLoadProfile = (profile) => {
    setConfig(profile.config);
    setSelectedProfile(profile);
    setMessage(`Loaded profile: ${profile.name}`);
  };

  const handleLoadDefault = (profile) => {
    setConfig(profile.config);
    setSelectedProfile(null);
    setMessage(`Loaded default: ${profile.name}`);
  };

  const handleSaveProfile = async () => {
    try {
      await createProfile({ name: `Profile ${Date.now()}`, description: '', config });
      setMessage('Profile saved!');
      loadProfiles();
    } catch (e) {
      setError('Failed to save profile');
    }
  };

  const handleDeleteProfile = async (id) => {
    try {
      await deleteProfile(id);
      setMessage('Profile deleted');
      loadProfiles();
    } catch (e) {
      setError('Failed to delete profile');
    }
  };

  return (
    <Box sx={{ maxWidth: 800, mx: 'auto' }}>
      <Typography variant="h6" gutterBottom>Profile Manager</Typography>
      <Button variant="contained" color="primary" onClick={handleSaveProfile} sx={{ mb: 2 }}>
        Save Current as New Profile
      </Button>
      <Divider sx={{ my: 2 }} />
      <Typography variant="subtitle1">Default Profiles</Typography>
      <List>
        {defaultProfiles.map((profile, idx) => (
          <ListItem key={idx} secondaryAction={
            <Button onClick={() => handleLoadDefault(profile)}>Load</Button>
          }>
            <ListItemText primary={profile.name} secondary={profile.description} />
          </ListItem>
        ))}
      </List>
      <Divider sx={{ my: 2 }} />
      <Typography variant="subtitle1">Saved Profiles</Typography>
      <List>
        {profiles.map((profile) => (
          <ListItem key={profile.id} secondaryAction={
            <IconButton edge="end" onClick={() => handleDeleteProfile(profile.id)}><DeleteIcon /></IconButton>
          }>
            <ListItemText
              primary={profile.name}
              secondary={profile.description}
              onClick={() => handleLoadProfile(profile)}
              style={{ cursor: 'pointer' }}
            />
          </ListItem>
        ))}
      </List>
      <Snackbar open={!!message} autoHideDuration={3000} onClose={() => setMessage('')}>
        <Alert onClose={() => setMessage('')} severity="success">{message}</Alert>
      </Snackbar>
      <Snackbar open={!!error} autoHideDuration={3000} onClose={() => setError('')}>
        <Alert onClose={() => setError('')} severity="error">{error}</Alert>
      </Snackbar>
    </Box>
  );
} 
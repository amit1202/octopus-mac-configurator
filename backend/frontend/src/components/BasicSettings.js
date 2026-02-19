import React from 'react';
import { Box, TextField, Switch, FormControlLabel, Typography } from '@mui/material';

export default function BasicSettings({ config, setConfig }) {
  const handleChange = (e) => {
    setConfig({ ...config, [e.target.name]: e.target.value });
  };
  const handleSwitch = (e) => {
    setConfig({ ...config, [e.target.name]: e.target.checked });
  };
  return (
    <Box sx={{ maxWidth: 600, mx: 'auto' }}>
      <Typography variant="h6" gutterBottom>Basic Settings</Typography>
      <TextField
        label="Server"
        name="server"
        value={config.server || ''}
        onChange={handleChange}
        fullWidth
        margin="normal"
      />
      <TextField
        label="Domain"
        name="domain"
        value={config.domain || ''}
        onChange={handleChange}
        fullWidth
        margin="normal"
      />
      <TextField
        label="Service"
        name="service"
        value={config.service || ''}
        onChange={handleChange}
        fullWidth
        margin="normal"
      />
      <TextField
        label="Certificate"
        name="certificate"
        value={config.certificate || ''}
        onChange={handleChange}
        fullWidth
        margin="normal"
        multiline
        minRows={3}
      />
      <FormControlLabel
        control={<Switch checked={!!config.sudo} onChange={handleSwitch} name="sudo" />}
        label="Sudo Required"
      />
    </Box>
  );
} 
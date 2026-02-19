import React from 'react';
import { Box, TextField, Switch, FormControlLabel, Typography } from '@mui/material';

export default function AdvancedSettings({ config, setConfig }) {
  const handleChange = (e) => {
    setConfig({ ...config, [e.target.name]: e.target.value });
  };
  const handleSwitch = (e) => {
    setConfig({ ...config, [e.target.name]: e.target.checked });
  };
  return (
    <Box sx={{ maxWidth: 600, mx: 'auto' }}>
      <Typography variant="h6" gutterBottom>Advanced Settings</Typography>
      <TextField
        label="Logging Level"
        name="logging"
        value={config.logging || ''}
        onChange={handleChange}
        fullWidth
        margin="normal"
      />
      <TextField
        label="Max Audit File Size"
        name="maxAuditFileSize"
        type="number"
        value={config.maxAuditFileSize || ''}
        onChange={handleChange}
        fullWidth
        margin="normal"
      />
      <TextField
        label="Max Log File Size"
        name="maxLogFileSize"
        type="number"
        value={config.maxLogFileSize || ''}
        onChange={handleChange}
        fullWidth
        margin="normal"
      />
      <TextField
        label="FileVault Login"
        name="filevaultlogin"
        value={config.filevaultlogin || ''}
        onChange={handleChange}
        fullWidth
        margin="normal"
      />
      <FormControlLabel
        control={<Switch checked={!!config.customUnlockScreen} onChange={handleSwitch} name="customUnlockScreen" />}
        label="Custom Unlock Screen"
      />
    </Box>
  );
} 
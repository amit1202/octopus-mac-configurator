import React from 'react';
import { Box, Switch, FormControlLabel, Typography, TextField, Button, List, ListItem, IconButton } from '@mui/material';
import DeleteIcon from '@mui/icons-material/Delete';

export default function AuthenticationSettings({ config, setConfig }) {
  const methods = config.authenticationMethods || [];
  const [newMethod, setNewMethod] = React.useState('');

  const handleSwitch = (e) => {
    setConfig({ ...config, [e.target.name]: e.target.checked });
  };
  const handleAddMethod = () => {
    if (newMethod.trim()) {
      setConfig({ ...config, authenticationMethods: [...methods, { method: newMethod }] });
      setNewMethod('');
    }
  };
  const handleRemoveMethod = (idx) => {
    setConfig({ ...config, authenticationMethods: methods.filter((_, i) => i !== idx) });
  };
  return (
    <Box sx={{ maxWidth: 600, mx: 'auto' }}>
      <Typography variant="h6" gutterBottom>Authentication Settings</Typography>
      <FormControlLabel
        control={<Switch checked={!!config.mfa} onChange={handleSwitch} name="mfa" />}
        label="Enable MFA"
      />
      <FormControlLabel
        control={<Switch checked={!!config.passwordfree} onChange={handleSwitch} name="passwordfree" />}
        label="Password Free"
      />
      <Typography variant="subtitle1" sx={{ mt: 2 }}>Authentication Methods</Typography>
      <List>
        {methods.map((m, idx) => (
          <ListItem key={idx} secondaryAction={
            <IconButton edge="end" onClick={() => handleRemoveMethod(idx)}><DeleteIcon /></IconButton>
          }>
            {m.method}
          </ListItem>
        ))}
      </List>
      <Box sx={{ display: 'flex', gap: 1 }}>
        <TextField
          label="New Method"
          value={newMethod}
          onChange={e => setNewMethod(e.target.value)}
          size="small"
        />
        <Button variant="contained" onClick={handleAddMethod}>Add</Button>
      </Box>
    </Box>
  );
} 
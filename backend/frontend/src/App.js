import React, { useState, useEffect } from 'react';
import AppBar from '@mui/material/AppBar';
import Box from '@mui/material/Box';
import Tabs from '@mui/material/Tabs';
import Tab from '@mui/material/Tab';
import Toolbar from '@mui/material/Toolbar';
import Typography from '@mui/material/Typography';
import BasicSettings from './components/BasicSettings';
import AuthenticationSettings from './components/AuthenticationSettings';
import AdvancedSettings from './components/AdvancedSettings';
import XMLPreview from './components/XMLPreview';
import ProfileManager from './components/ProfileManager';
import { getDefaultProfiles } from './api';

function a11yProps(index) {
  return {
    id: `octopus-tab-${index}`,
    'aria-controls': `octopus-tabpanel-${index}`,
  };
}

function TabPanel(props) {
  const { children, value, index, ...other } = props;
  return (
    <div
      role="tabpanel"
      hidden={value !== index}
      id={`octopus-tabpanel-${index}`}
      aria-labelledby={`octopus-tab-${index}`}
      {...other}
    >
      {value === index && <Box sx={{ p: 3 }}>{children}</Box>}
    </div>
  );
}

export default function App() {
  const [tab, setTab] = useState(0);
  const [config, setConfig] = useState({});
  const [defaultProfiles, setDefaultProfiles] = useState([]);
  const [selectedProfile, setSelectedProfile] = useState(null);

  useEffect(() => {
    getDefaultProfiles().then(setDefaultProfiles);
  }, []);

  const handleTabChange = (event, newValue) => {
    setTab(newValue);
  };

  return (
    <Box sx={{ flexGrow: 1, bgcolor: '#f5f5f5', minHeight: '100vh' }}>
      <AppBar position="static" color="primary">
        <Toolbar>
          <Typography variant="h6" component="div" sx={{ flexGrow: 1 }}>
            🐙 Octopus Configurator
          </Typography>
        </Toolbar>
      </AppBar>
      <Box sx={{ width: '100%', bgcolor: 'background.paper' }}>
        <Tabs value={tab} onChange={handleTabChange} centered>
          <Tab label="Basic" {...a11yProps(0)} />
          <Tab label="Authentication" {...a11yProps(1)} />
          <Tab label="Advanced" {...a11yProps(2)} />
          <Tab label="XML Preview" {...a11yProps(3)} />
          <Tab label="Profile Manager" {...a11yProps(4)} />
        </Tabs>
        <TabPanel value={tab} index={0}>
          <BasicSettings config={config} setConfig={setConfig} />
        </TabPanel>
        <TabPanel value={tab} index={1}>
          <AuthenticationSettings config={config} setConfig={setConfig} />
        </TabPanel>
        <TabPanel value={tab} index={2}>
          <AdvancedSettings config={config} setConfig={setConfig} />
        </TabPanel>
        <TabPanel value={tab} index={3}>
          <XMLPreview config={config} />
        </TabPanel>
        <TabPanel value={tab} index={4}>
          <ProfileManager
            config={config}
            setConfig={setConfig}
            defaultProfiles={defaultProfiles}
            selectedProfile={selectedProfile}
            setSelectedProfile={setSelectedProfile}
          />
        </TabPanel>
      </Box>
    </Box>
  );
}

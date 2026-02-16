const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const app = express();
const port = 3000;

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const dir = './public/uploads/profiles';
    if (!fs.existsSync(dir)){ fs.mkdirSync(dir, { recursive: true }); }
    cb(null, dir);
  },
  filename: (req, file, cb) => {
    cb(null, Date.now() + '-' + Math.random().toString(36).substring(7) + path.extname(file.originalname));
  }
});

const upload = multer({ 
  storage: storage,
  limits: { fileSize: 5 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    const allowedTypes = /jpeg|jpg|png|gif/;
    if (allowedTypes.test(path.extname(file.originalname).toLowerCase()) && allowedTypes.test(file.mimetype)) {
      return cb(null, true);
    }
    cb(new Error('Only images allowed!'));
  }
});

let users = {};
let sessions = {};
let gameStates = {};

// Rebirth options (sorted by amount) - up to 1 Ocqag (1e138)
const REBIRTH_OPTIONS = [
  { amount: 1, baseCost: 1e2 },
  { amount: 5, baseCost: 5e2 },
  { amount: 10, baseCost: 2e3 },
  { amount: 25, baseCost: 1e4 },
  { amount: 50, baseCost: 5e4 },
  { amount: 100, baseCost: 2e5 },
  { amount: 250, baseCost: 1e6 },
  { amount: 500, baseCost: 5e6 },
  { amount: 1000, baseCost: 2e7 },
  { amount: 2500, baseCost: 1e8 },
  { amount: 5000, baseCost: 5e8 },
  { amount: 10000, baseCost: 2e9 },
  { amount: 25000, baseCost: 1e10 },
  { amount: 50000, baseCost: 5e10 },
  { amount: 100000, baseCost: 2e11 },
  { amount: 250000, baseCost: 1e12 },
  { amount: 500000, baseCost: 5e12 },
  { amount: 1000000, baseCost: 2e13 },
  { amount: 2500000, baseCost: 1e14 },
  { amount: 5000000, baseCost: 5e14 },
  { amount: 10000000, baseCost: 2e15 },
  { amount: 25000000, baseCost: 1e16 },
  { amount: 50000000, baseCost: 5e16 },
  { amount: 100000000, baseCost: 2e17 },
  { amount: 250000000, baseCost: 1e18 },
  { amount: 500000000, baseCost: 5e18 },
  { amount: 1e9, baseCost: 2e19 },
  { amount: 2.5e9, baseCost: 1e20 },
  { amount: 5e9, baseCost: 5e20 },
  { amount: 1e10, baseCost: 2e21 },
  { amount: 2.5e10, baseCost: 1e22 },
  { amount: 5e10, baseCost: 5e22 },
  { amount: 1e11, baseCost: 2e23 },
  { amount: 2.5e11, baseCost: 1e24 },
  { amount: 5e11, baseCost: 5e24 },
  { amount: 1e12, baseCost: 2e25 },
  { amount: 2.5e12, baseCost: 1e26 },
  { amount: 5e12, baseCost: 5e26 },
  { amount: 1e13, baseCost: 2e27 },
  { amount: 2.5e13, baseCost: 1e28 },
  { amount: 5e13, baseCost: 5e28 },
  { amount: 1e14, baseCost: 2e29 },
  { amount: 2.5e14, baseCost: 1e30 },
  { amount: 5e14, baseCost: 5e30 },
  { amount: 1e15, baseCost: 2e31 },
  { amount: 2.5e15, baseCost: 1e32 },
  { amount: 5e15, baseCost: 5e32 },
  { amount: 1e16, baseCost: 2e33 },
  { amount: 2.5e16, baseCost: 1e34 },
  { amount: 5e16, baseCost: 5e34 },
  { amount: 1e17, baseCost: 2e35 },
  { amount: 2.5e17, baseCost: 1e36 },
  { amount: 5e17, baseCost: 5e36 },
  { amount: 1e18, baseCost: 2e37 },
  { amount: 2.5e18, baseCost: 1e38 },
  { amount: 5e18, baseCost: 5e38 },
  { amount: 1e19, baseCost: 2e39 },
  { amount: 2.5e19, baseCost: 1e40 },
  { amount: 5e19, baseCost: 5e40 },
  { amount: 1e20, baseCost: 2e41 },
  { amount: 2.5e20, baseCost: 1e42 },
  { amount: 5e20, baseCost: 5e42 },
  { amount: 1e21, baseCost: 2e43 },
  { amount: 2.5e21, baseCost: 1e44 },
  { amount: 5e21, baseCost: 5e44 },
  { amount: 1e22, baseCost: 2e45 },
  { amount: 2.5e22, baseCost: 1e46 },
  { amount: 5e22, baseCost: 5e46 },
  { amount: 1e23, baseCost: 2e47 },
  { amount: 2.5e23, baseCost: 1e48 },
  { amount: 5e23, baseCost: 5e48 },
  { amount: 1e24, baseCost: 2e49 },
  { amount: 2.5e24, baseCost: 1e50 },
  { amount: 5e24, baseCost: 5e50 },
  { amount: 1e25, baseCost: 2e51 },
  { amount: 2.5e25, baseCost: 1e52 },
  { amount: 5e25, baseCost: 5e52 },
  { amount: 1e26, baseCost: 2e53 },
  { amount: 2.5e26, baseCost: 1e54 },
  { amount: 5e26, baseCost: 5e54 },
  { amount: 1e27, baseCost: 2e55 },
  { amount: 2.5e27, baseCost: 1e56 },
  { amount: 5e27, baseCost: 5e56 },
  { amount: 1e28, baseCost: 2e57 },
  { amount: 2.5e28, baseCost: 1e58 },
  { amount: 5e28, baseCost: 5e58 },
  { amount: 1e29, baseCost: 2e59 },
  { amount: 2.5e29, baseCost: 1e60 },
  { amount: 5e29, baseCost: 5e60 },
  { amount: 1e30, baseCost: 2e61 },
  { amount: 2.5e30, baseCost: 1e62 },
  { amount: 5e30, baseCost: 5e62 },
  { amount: 1e31, baseCost: 2e63 },
  { amount: 2.5e31, baseCost: 1e64 },
  { amount: 5e31, baseCost: 5e64 },
  { amount: 1e32, baseCost: 2e65 },
  { amount: 2.5e32, baseCost: 1e66 },
  { amount: 5e32, baseCost: 5e66 },
  { amount: 1e33, baseCost: 2e67 },
  { amount: 2.5e33, baseCost: 1e68 },
  { amount: 5e33, baseCost: 5e68 },
  { amount: 1e34, baseCost: 2e69 },
  { amount: 2.5e34, baseCost: 1e70 },
  { amount: 5e34, baseCost: 5e70 },
  { amount: 1e35, baseCost: 2e71 },
  { amount: 2.5e35, baseCost: 1e72 },
  { amount: 5e35, baseCost: 5e72 },
  { amount: 1e36, baseCost: 2e73 },
  { amount: 2.5e36, baseCost: 1e74 },
  { amount: 5e36, baseCost: 5e74 },
  { amount: 1e37, baseCost: 2e75 },
  { amount: 2.5e37, baseCost: 1e76 },
  { amount: 5e37, baseCost: 5e76 },
  { amount: 1e38, baseCost: 2e77 },
  { amount: 2.5e38, baseCost: 1e78 },
  { amount: 5e38, baseCost: 5e78 },
  { amount: 1e39, baseCost: 2e79 },
  { amount: 2.5e39, baseCost: 1e80 },
  { amount: 5e39, baseCost: 5e80 },
  { amount: 1e40, baseCost: 2e81 },
  { amount: 2.5e40, baseCost: 1e82 },
  { amount: 5e40, baseCost: 5e82 },
  { amount: 1e41, baseCost: 2e83 },
  { amount: 2.5e41, baseCost: 1e84 },
  { amount: 5e41, baseCost: 5e84 },
  { amount: 1e42, baseCost: 2e85 },
  { amount: 2.5e42, baseCost: 1e86 },
  { amount: 5e42, baseCost: 5e86 },
  { amount: 1e43, baseCost: 2e87 },
  { amount: 2.5e43, baseCost: 1e88 },
  { amount: 5e43, baseCost: 5e88 },
  { amount: 1e44, baseCost: 2e89 },
  { amount: 2.5e44, baseCost: 1e90 },
  { amount: 5e44, baseCost: 5e90 },
  { amount: 1e45, baseCost: 2e91 },
  { amount: 2.5e45, baseCost: 1e92 },
  { amount: 5e45, baseCost: 5e92 },
  { amount: 1e46, baseCost: 2e93 },
  { amount: 2.5e46, baseCost: 1e94 },
  { amount: 5e46, baseCost: 5e94 },
  { amount: 1e47, baseCost: 2e95 },
  { amount: 2.5e47, baseCost: 1e96 },
  { amount: 5e47, baseCost: 5e96 },
  { amount: 1e48, baseCost: 2e97 },
  { amount: 2.5e48, baseCost: 1e98 },
  { amount: 5e48, baseCost: 5e98 },
  { amount: 1e49, baseCost: 2e99 },
  { amount: 2.5e49, baseCost: 1e100 },
  { amount: 5e49, baseCost: 5e100 },
  { amount: 1e50, baseCost: 2e101 },
  { amount: 2.5e50, baseCost: 1e102 },
  { amount: 5e50, baseCost: 5e102 },
  { amount: 1e51, baseCost: 2e103 },
  { amount: 2.5e51, baseCost: 1e104 },
  { amount: 5e51, baseCost: 5e104 },
  { amount: 1e52, baseCost: 2e105 },
  { amount: 2.5e52, baseCost: 1e106 },
  { amount: 5e52, baseCost: 5e106 },
  { amount: 1e53, baseCost: 2e107 },
  { amount: 2.5e53, baseCost: 1e108 },
  { amount: 5e53, baseCost: 5e108 },
  { amount: 1e54, baseCost: 2e109 },
  { amount: 2.5e54, baseCost: 1e110 },
  { amount: 5e54, baseCost: 5e110 },
  { amount: 1e55, baseCost: 2e111 },
  { amount: 2.5e55, baseCost: 1e112 },
  { amount: 5e55, baseCost: 5e112 },
  { amount: 1e56, baseCost: 2e113 },
  { amount: 2.5e56, baseCost: 1e114 },
  { amount: 5e56, baseCost: 5e114 },
  { amount: 1e57, baseCost: 2e115 },
  { amount: 2.5e57, baseCost: 1e116 },
  { amount: 5e57, baseCost: 5e116 },
  { amount: 1e58, baseCost: 2e117 },
  { amount: 2.5e58, baseCost: 1e118 },
  { amount: 5e58, baseCost: 5e118 },
  { amount: 1e59, baseCost: 2e119 },
  { amount: 2.5e59, baseCost: 1e120 },
  { amount: 5e59, baseCost: 5e120 },
  { amount: 1e60, baseCost: 2e121 },
  { amount: 2.5e60, baseCost: 1e122 },
  { amount: 5e60, baseCost: 5e122 },
  { amount: 1e61, baseCost: 2e123 },
  { amount: 2.5e61, baseCost: 1e124 },
  { amount: 5e61, baseCost: 5e124 },
  { amount: 1e62, baseCost: 2e125 },
  { amount: 2.5e62, baseCost: 1e126 },
  { amount: 5e62, baseCost: 5e126 },
  { amount: 1e63, baseCost: 2e127 },
  { amount: 2.5e63, baseCost: 1e128 },
  { amount: 5e63, baseCost: 5e128 },
  { amount: 1e64, baseCost: 2e129 },
  { amount: 2.5e64, baseCost: 1e130 },
  { amount: 5e64, baseCost: 5e130 },
  { amount: 1e65, baseCost: 2e131 },
  { amount: 2.5e65, baseCost: 1e132 },
  { amount: 5e65, baseCost: 5e132 },
  { amount: 1e66, baseCost: 2e133 },
  { amount: 2.5e66, baseCost: 1e134 },
  { amount: 5e66, baseCost: 5e134 },
  { amount: 1e67, baseCost: 2e135 },
  { amount: 2.5e67, baseCost: 1e136 },
  { amount: 5e67, baseCost: 5e136 },
  { amount: 1e68, baseCost: 2e137 },
  { amount: 1e69, baseCost: 1e138 }
];

app.use(express.json());
app.use(express.static('public'));

function generateUserId() {
  return 'USR' + Date.now() + Math.random().toString(36).substring(2, 9).toUpperCase();
}

function generateToken() {
  return Math.random().toString(36).substring(2) + Date.now().toString(36);
}

app.post('/api/register', (req, res) => {
  const { name, password, confirmPassword } = req.body;
  
  if (!name || !password || !confirmPassword) {
    return res.json({ success: false, message: 'All fields required!' });
  }
  if (password !== confirmPassword) {
    return res.json({ success: false, message: 'Passwords do not match!' });
  }
  if (password.length < 6) {
    return res.json({ success: false, message: 'Password must be at least 6 characters!' });
  }
  
  const nameExists = Object.values(users).some(u => u.name.toLowerCase() === name.toLowerCase());
  if (nameExists) {
    return res.json({ success: false, message: 'Name already taken!' });
  }
  
  const userId = generateUserId();
  users[userId] = {
    id: userId,
    name: name,
    password: password,
    profileImage: null,
    createdAt: new Date().toISOString()
  };
  
  gameStates[userId] = {
    clicks: 0,
    clickPower: 1,
    autoClickerDelay: 1000,
    totalRebirth: 0,
    rebirthMultiplier: 1.0,
    upgrades: {
      clickPower: { level: 0, cost: 10 },
      autoClicker: { count: 0, cost: 50, cps: 0 },
      autoClickerSpeed: { level: 0, cost: 1000 }
    }
  };
  
  res.json({ success: true, userId: userId, message: 'Registration successful! Please upload profile image.' });
});

app.post('/api/upload-profile/:userId', upload.single('profileImage'), (req, res) => {
  const userId = req.params.userId;
  if (!users[userId]) {
    return res.json({ success: false, message: 'User not found!' });
  }
  if (!req.file) {
    return res.json({ success: false, message: 'No image uploaded!' });
  }
  users[userId].profileImage = '/uploads/profiles/' + req.file.filename;
  res.json({ success: true, message: 'Profile image uploaded!', imageUrl: users[userId].profileImage });
});

app.post('/api/login', (req, res) => {
  const { name, password } = req.body;
  if (!name || !password) {
    return res.json({ success: false, message: 'Name and password required!' });
  }
  
  const user = Object.values(users).find(u => u.name.toLowerCase() === name.toLowerCase());
  if (!user) {
    return res.json({ success: false, message: 'User not found!' });
  }
  if (user.password !== password) {
    return res.json({ success: false, message: 'Wrong password!' });
  }
  if (!user.profileImage) {
    return res.json({ success: false, message: 'Please upload profile image first!', needsProfileImage: true, userId: user.id });
  }
  
  const token = generateToken();
  sessions[token] = { userId: user.id, createdAt: new Date().toISOString() };
  
  res.json({ 
    success: true, 
    token: token,
    user: { id: user.id, name: user.name, profileImage: user.profileImage }
  });
});

app.get('/api/user', (req, res) => {
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (!token || !sessions[token]) {
    return res.json({ success: false, message: 'Not authenticated!' });
  }
  const userId = sessions[token].userId;
  const user = users[userId];
  if (!user) {
    return res.json({ success: false, message: 'User not found!' });
  }
  res.json({ success: true, user: { id: user.id, name: user.name, profileImage: user.profileImage } });
});

app.get('/api/state', (req, res) => {
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (!token || !sessions[token]) {
    return res.json({ success: false, message: 'Not authenticated!' });
  }
  const userId = sessions[token].userId;
  const state = gameStates[userId];
  if (!state) {
    return res.json({ success: false, message: 'Game state not found!' });
  }
  res.json(state);
});

app.post('/api/click', (req, res) => {
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (!token || !sessions[token]) {
    return res.json({ success: false, message: 'Not authenticated!' });
  }
  const userId = sessions[token].userId;
  const state = gameStates[userId];
  
  const actualPower = state.clickPower * state.rebirthMultiplier;
  state.clicks += actualPower;
  res.json({ clicks: state.clicks, clickPower: actualPower });
});

app.post('/api/upgrade/:type', (req, res) => {
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (!token || !sessions[token]) {
    return res.json({ success: false, message: 'Not authenticated!' });
  }
  const userId = sessions[token].userId;
  const state = gameStates[userId];
  const type = req.params.type;
  const amount = req.body.amount || 1;
  
  if (type === 'clickPower') {
    if (amount === 'max') {
      let totalBought = 0;
      while (state.clicks >= state.upgrades.clickPower.cost) {
        state.clicks -= state.upgrades.clickPower.cost;
        state.upgrades.clickPower.level++;
        state.clickPower += 1;
        state.upgrades.clickPower.cost = Math.floor(state.upgrades.clickPower.cost * 1.5);
        totalBought++;
      }
      res.json({ success: true, gameState: state, bought: totalBought });
    } else {
      if (state.clicks >= state.upgrades.clickPower.cost) {
        state.clicks -= state.upgrades.clickPower.cost;
        state.upgrades.clickPower.level++;
        state.clickPower += 1;
        state.upgrades.clickPower.cost = Math.floor(state.upgrades.clickPower.cost * 1.5);
        res.json({ success: true, gameState: state, bought: 1 });
      } else {
        res.json({ success: false, message: 'Not enough clicks!' });
      }
    }
  } else if (type === 'autoClicker') {
    if (state.totalRebirth < 2) {
      return res.json({ success: false, message: 'Unlock at Rebirth 2!' });
    }
    if (amount === 'max') {
      let totalBought = 0;
      while (state.clicks >= state.upgrades.autoClicker.cost) {
        state.clicks -= state.upgrades.autoClicker.cost;
        state.upgrades.autoClicker.count++;
        
        // Scaling: +10/s until 100, then +50/s
        if (state.upgrades.autoClicker.cps < 100) {
          state.upgrades.autoClicker.cps += 10;
        } else {
          state.upgrades.autoClicker.cps += 50;
        }
        
        state.upgrades.autoClicker.cost = Math.floor(state.upgrades.autoClicker.cost * 1.5);
        totalBought++;
      }
      res.json({ success: true, gameState: state, bought: totalBought });
    } else {
      if (state.clicks >= state.upgrades.autoClicker.cost) {
        state.clicks -= state.upgrades.autoClicker.cost;
        state.upgrades.autoClicker.count++;
        
        // Scaling: +10/s until 100, then +50/s
        if (state.upgrades.autoClicker.cps < 100) {
          state.upgrades.autoClicker.cps += 10;
        } else {
          state.upgrades.autoClicker.cps += 50;
        }
        
        state.upgrades.autoClicker.cost = Math.floor(state.upgrades.autoClicker.cost * 1.5);
        res.json({ success: true, gameState: state, bought: 1 });
      } else {
        res.json({ success: false, message: 'Not enough clicks!' });
      }
    }
  } else if (type === 'autoClickerSpeed') {
    if (state.totalRebirth < 10) {
      return res.json({ success: false, message: 'Unlock at Rebirth 10!' });
    }
    if (amount === 'max') {
      let totalBought = 0;
      while (state.clicks >= state.upgrades.autoClickerSpeed.cost && state.upgrades.autoClickerSpeed.level < 9) {
        state.clicks -= state.upgrades.autoClickerSpeed.cost;
        state.upgrades.autoClickerSpeed.level++;
        state.autoClickerDelay = 1000 - (state.upgrades.autoClickerSpeed.level * 100);
        const costs = [1000, 10000, 50000, 150000, 500000, 1000000, 2500000, 5000000, 10000000];
        state.upgrades.autoClickerSpeed.cost = costs[state.upgrades.autoClickerSpeed.level] || 99999999;
        totalBought++;
      }
      res.json({ success: true, gameState: state, bought: totalBought });
    } else {
      if (state.upgrades.autoClickerSpeed.level >= 9) {
        return res.json({ success: false, message: 'Max speed reached!' });
      }
      if (state.clicks >= state.upgrades.autoClickerSpeed.cost) {
        state.clicks -= state.upgrades.autoClickerSpeed.cost;
        state.upgrades.autoClickerSpeed.level++;
        state.autoClickerDelay = 1000 - (state.upgrades.autoClickerSpeed.level * 100);
        const costs = [1000, 10000, 50000, 150000, 500000, 1000000, 2500000, 5000000, 10000000];
        state.upgrades.autoClickerSpeed.cost = costs[state.upgrades.autoClickerSpeed.level] || 99999999;
        res.json({ success: true, gameState: state, bought: 1 });
      } else {
        res.json({ success: false, message: 'Not enough clicks!' });
      }
    }
  }
});

app.get('/api/rebirth-options', (req, res) => {
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (!token || !sessions[token]) {
    return res.json({ success: false, message: 'Not authenticated!' });
  }
  const userId = sessions[token].userId;
  const state = gameStates[userId];
  
  const options = REBIRTH_OPTIONS.map(opt => {
    const actualCost = opt.baseCost + (state.totalRebirth * 100);
    return {
      amount: opt.amount,
      cost: actualCost,
      available: state.clicks >= actualCost
    };
  });
  
  res.json({ success: true, options, currentRebirth: state.totalRebirth, currentMultiplier: state.rebirthMultiplier });
});

app.post('/api/rebirth', (req, res) => {
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (!token || !sessions[token]) {
    return res.json({ success: false, message: 'Not authenticated!' });
  }
  const userId = sessions[token].userId;
  const state = gameStates[userId];
  const { amount } = req.body;
  
  const option = REBIRTH_OPTIONS.find(o => o.amount === amount);
  if (!option) {
    return res.json({ success: false, message: 'Invalid rebirth amount!' });
  }
  
  const actualCost = option.baseCost + (state.totalRebirth * 100);
  if (state.clicks < actualCost) {
    return res.json({ success: false, message: 'Not enough clicks!' });
  }
  
  // REBIRTH!
  state.totalRebirth += amount;
  state.rebirthMultiplier = 1.0 + (state.totalRebirth * 0.1);
  state.clicks = 0;
  state.clickPower = 1;
  state.upgrades.clickPower = { level: 0, cost: 10 };
  state.upgrades.autoClicker = { count: 0, cost: 50, cps: 0 };
  state.upgrades.autoClickerSpeed = { level: 0, cost: 1000 };
  state.autoClickerDelay = 1000;
  
  res.json({ success: true, gameState: state, message: `Rebirth +${amount} successful! Multiplier: ${state.rebirthMultiplier.toFixed(1)}x` });
});

app.get('/api/leaderboard/:type', (req, res) => {
  const type = req.params.type;
  const page = parseInt(req.query.page) || 1;
  const perPage = 10;
  
  if (type === 'clicks') {
    const leaderboard = Object.keys(gameStates).map(userId => {
      const user = users[userId];
      const state = gameStates[userId];
      return {
        id: user.id,
        name: user.name,
        profileImage: user.profileImage,
        clicks: state.clicks,
        rebirth: state.totalRebirth
      };
    }).sort((a, b) => b.clicks - a.clicks);
    
    const start = (page - 1) * perPage;
    const end = start + perPage;
    res.json({
      success: true,
      data: leaderboard.slice(start, end),
      page, totalPages: Math.ceil(leaderboard.length / perPage),
      total: leaderboard.length
    });
  } else if (type === 'donate') {
    res.json({ success: true, data: [], message: 'Coming soon!' });
  }
});

setInterval(() => {
  Object.keys(gameStates).forEach(userId => {
    const state = gameStates[userId];
    if (state.upgrades.autoClicker.count > 0) {
      const cps = state.upgrades.autoClicker.cps * state.rebirthMultiplier;
      state.clicks += cps * (state.autoClickerDelay / 1000);
    }
  });
}, 1000);

app.listen(port, '0.0.0.0', () => {
  console.log(`🎮 Clicker game running at http://localhost:${port}`);
});

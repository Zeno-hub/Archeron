const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs-extra');

const app = express();
const port = 3000;

app.use(express.json()); 
app.use(express.urlencoded({ extended:true }));

const USERS_DIR = path.join(__dirname, "users");

// Ensure users dir
fs.ensureDirSync(USERS_DIR);

// ================= UPLOAD =================
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const username = req.params.name;
    const dir = path.join(USERS_DIR, username, "profile");
    fs.ensureDirSync(dir);
    cb(null, dir);
  },
  filename: (req, file, cb) => {
    cb(null, "avatar" + path.extname(file.originalname));
  }
});

const upload = multer({ storage });

// ================= HELPERS =================
function userDir(name){
  return path.join(USERS_DIR, name);
}

function infoPath(name){
  return path.join(userDir(name),"info.json");
}

function statePath(name){
  return path.join(userDir(name),"state.json");
}

function generateUserId() {
  return 'USR' + Date.now() + Math.random().toString(36).substring(2, 9).toUpperCase();
}

// ================= REGISTER =================
app.post('/api/register', async (req,res)=>{
  let { name, password, confirmPassword } = req.body;

if(name) name = name.replace(/[^a-zA-Z0-9_-]/g,"");

  if(!name || !password || !confirmPassword)
    return res.json({success:false,message:"All fields required"});

  if(password !== confirmPassword)
    return res.json({success:false,message:"Password mismatch"});

  const dir = userDir(name);

  if(await fs.pathExists(dir))
    return res.json({success:false,message:"User exists"});

  await fs.ensureDir(dir);

  const info = {
    id: generateUserId(),
    name,
    password,
    createdAt: new Date().toISOString()
  };

  const state = {
    clicks: 0,
    clickPower: 1,
    autoClickerDelay: 1000,
    upgrades: {
      clickPower: { level: 0, cost: 10, multiplier: 1 },
      autoClicker: { count: 0, cost: 50, cps: 0 },
      autoClickerSpeed: { level: 0, cost: 1000, delay: 1000 }
    }
  };

  await fs.writeJson(infoPath(name), info);
  await fs.writeJson(statePath(name), state);

  res.json({success:true,userId:info.id});
});

// ================= UPLOAD AVATAR =================
app.post('/api/upload-profile/:name', upload.single('profileImage'), async (req,res)=>{
  const name = req.params.name;
  const dir = userDir(name);

  if(!await fs.pathExists(dir))
    return res.json({success:false,message:"User not found"});

  res.json({
    success:true,
    imageUrl:`/users/${name}/profile/avatar.png`
  });
});

// ================= LOGIN =================
app.post('/api/login', async (req,res)=>{
  let { name, password } = req.body;

if(name) name = name.replace(/[^a-zA-Z0-9_-]/g,"");

  const dir = userDir(name);
  if(!await fs.pathExists(dir))
    return res.json({success:false,message:"User not found"});

  const info = await fs.readJson(infoPath(name));

  if(info.password !== password)
    return res.json({success:false,message:"Wrong password"});

  const state = await fs.readJson(statePath(name));

  res.json({
    success:true,
    user:{
      id:info.id,
      name:info.name,
      profileImage:`/users/${name}/profile/avatar.png`
    },
    gameState:state
  });
});

// ================= SAVE STATE =================
app.post('/api/save', async (req,res)=>{
  let { name, state } = req.body;

if(name) name = name.replace(/[^a-zA-Z0-9_-]/g,"");
  const dir = userDir(name);
  if(!await fs.pathExists(dir))
    return res.json({success:false});

  await fs.writeJson(statePath(name), state);

  res.json({success:true});
});

// ================= LEADERBOARD =================
app.get('/api/leaderboard', async (req,res)=>{
  const users = await fs.readdir(USERS_DIR);

  const list = [];

  for(const name of users){
    try{
      const info = await fs.readJson(infoPath(name));
      const state = await fs.readJson(statePath(name));

      list.push({
        id:info.id,
        name:info.name,
        clicks:state.clicks
      });
    }catch{}
  }

  list.sort((a,b)=>b.clicks-a.clicks);

  res.json({success:true,data:list});
});

// ================= STATIC USERS =================
app.use('/users', express.static(USERS_DIR));
app.use(express.static('public'));

// ================= START =================
app.listen(port, ()=>{
  console.log(`Server running http://localhost:${port}`);
});
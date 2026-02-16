let currentUser = null;

// DOM AUTH ELEMENTS
const authUser = document.getElementById("authUser");
const authPass = document.getElementById("authPass");
const avatarUpload = document.getElementById("avatarUpload");

const profileImg = document.getElementById("profileImg");
const profilePreview = document.getElementById("profilePreview");
const profileName = document.getElementById("profileName");
const profileID = document.getElementById("profileID");


// ================= REGISTER API =================
async function register(){
  const name = authUser.value.trim();
  const password = authPass.value.trim();

  if(!name || !password){
    alert("Isi username & password");
    return;
  }

  const res = await fetch("/api/register",{
    method:"POST",
    headers:{ "Content-Type":"application/json" },
    body: JSON.stringify({
      name,
      password,
      confirmPassword: password
    })
  });

  const data = await res.json();

  if(!data.success){
    alert(data.message);
    return;
  }

  alert("Register berhasil");

  currentUser = name;
  avatarUpload.click();
}

// ================= LOGIN API =================
async function login(){
  const name = authUser.value.trim();
  const password = authPass.value.trim();

  if(!name || !password){
    alert("Isi username & password");
    return;
  }

  const res = await fetch("/api/login",{
    method:"POST",
    headers:{ "Content-Type":"application/json" },
    body: JSON.stringify({ name, password })
  });

  const data = await res.json();

  if(!data.success){
    alert(data.message);
    return;
  }

  currentUser = name;

  profileImg.src = data.user.profileImage;
  profilePreview.src = data.user.profileImage;
  profileName.textContent = data.user.name;
  profileID.textContent = "ID: " + data.user.id;

  gameState = data.gameState || gameState;

if(!gameState.petInventory){
  gameState.petInventory = [];
}

  document.getElementById("authScreen").style.display="none";

  updateUI();
  updateUpgradeUI();
  restartAutoClicker();
  updatePetInventory();
}

function saveGame(){
  if(!currentUser) return;

  fetch("/api/save",{
    method:"POST",
    headers:{ "Content-Type":"application/json" },
    body: JSON.stringify({
      name: currentUser,
      state: gameState
    })
  });
}

// AUTO LOGIN LAST USER
const lastUser = localStorage.getItem("lastUser");
if(lastUser){
  currentUser = lastUser;
}

// load accounts
function getAccounts(){
  return JSON.parse(localStorage.getItem("accounts") || "{}");
}

function saveAccounts(acc){
  localStorage.setItem("accounts", JSON.stringify(acc));
}

// random ID
function generateID(){
  return Math.random().toString(36).substring(2,10).toUpperCase();
}

// IMAGE UPLOAD
avatarUpload.onchange = e=>{
  const file = e.target.files[0];
  if(!file) return;

  const reader = new FileReader();
  reader.onload = ()=>{
    const acc = getAccounts();
    acc[currentUser].avatar = reader.result;
    saveAccounts(acc);
    startUserSession();
  };
  reader.readAsDataURL(file);
};

// START SESSION
function startUserSession(){
  const acc = getAccounts()[currentUser];

  document.getElementById("authScreen").style.display="none";

  const avatar = acc.avatar || "default-avatar.png";
profileImg.src = avatar;
profilePreview.src = avatar;
  profileName.textContent = currentUser;
  profileID.textContent = "ID: "+acc.id;
  
localStorage.setItem("lastUser", currentUser);

  // load save per akun
  if(acc.save && typeof acc.save === "object"){
  gameState = acc.save;
}

if(!gameState.petInventory){
  gameState.petInventory = [];
}
  
  syncAutoClickerDelay();
  updateAutoClickerCPS();
  restartAutoClicker();
  
  gameState.RebirthMultiplier =
    1 + gameState.rebirthPoints * 0.1;

  updateUI();
  updateUpgradeUI();
  updatePetInventory();
}

function syncAutoClickerDelay(){
  const lvl = gameState.upgrades.speedEnhancer.level || 0;
  gameState.autoClickerDelay = Math.max(100, 1000 - (lvl * 100));
}

// Game State (saved to localStorage)
let gameState = {
    clicks: 0,
    clickPower: 1,
    totalRebirth: 0,
    RebirthMultiplier: 1.0,
    autoClickerDelay: 1000,
    totalRebirthCount: 0, 
    rebirthPoints: 0,     
    clickSoundEnabled: true,
    rebirthLevels: {},   // simpan level tiap reward
    petInventory: [],
    upgrades: {
        clickPower: { level: 0, cost: 10, costMultiplier: 1.15 },
        autoClicker: { count: 0, cost: 100, costMultiplier: 1.25, cps: 0 },
        speedEnhancer: { level: 0, cost: 1000, costs: [1000, 10000, 50000, 175000, 500000, 1000000, 2500000, 5000000, 10000000, 25000000] }
    }
};

// ================= GACHA SYSTEM =================

// ===== DATA =====
const gachaEggs = [
  {
    name: "Common Egg",
    cost: 1000,
    pets: [
      { name: "Pet A1", rarity: 1, stats:{attack:100,defense:50,speed:20}},
      { name: "Pet A2", rarity: 2, stats:{attack:90,defense:45,speed:18}},
      { name: "Pet A3", rarity: 3, stats:{attack:80,defense:40,speed:16}},
      { name: "Pet A4", rarity: 4, stats:{attack:70,defense:35,speed:14}},
      { name: "Pet A5", rarity: 5, stats:{attack:60,defense:30,speed:12}},
      { name: "Pet A6", rarity: 6, stats:{attack:50,defense:25,speed:10}},
      { name: "Pet A7", rarity: 7, stats:{attack:40,defense:20,speed:8}},
      { name: "Pet A8", rarity: 8, stats:{attack:30,defense:15,speed:6}},
      { name: "Pet A9", rarity: 9, stats:{attack:20,defense:10,speed:4}}
    ]
  },
  {
    name: "Rare Egg",
    cost: 5000,
    pets: [
      { name: "Pet B1", rarity:1, stats:{attack:120,defense:60,speed:25}},
      { name: "Pet B2", rarity:2, stats:{attack:110,defense:55,speed:23}},
      { name: "Pet B3", rarity:3, stats:{attack:100,defense:50,speed:21}},
      { name: "Pet B4", rarity:4, stats:{attack:90,defense:45,speed:19}},
      { name: "Pet B5", rarity:5, stats:{attack:80,defense:40,speed:17}},
      { name: "Pet B6", rarity:6, stats:{attack:70,defense:35,speed:15}},
      { name: "Pet B7", rarity:7, stats:{attack:60,defense:30,speed:13}},
      { name: "Pet B8", rarity:8, stats:{attack:50,defense:25,speed:11}},
      { name: "Pet B9", rarity:9, stats:{attack:40,defense:20,speed:9}}
    ]
  },
  {
    name: "Epic Egg",
    cost: 25000,
    pets: [
      { name:"Pet C1",rarity:1,stats:{attack:150,defense:75,speed:30}},
      { name:"Pet C2",rarity:2,stats:{attack:140,defense:70,speed:28}},
      { name:"Pet C3",rarity:3,stats:{attack:130,defense:65,speed:26}},
      { name:"Pet C4",rarity:4,stats:{attack:120,defense:60,speed:24}},
      { name:"Pet C5",rarity:5,stats:{attack:110,defense:55,speed:22}},
      { name:"Pet C6",rarity:6,stats:{attack:100,defense:50,speed:20}},
      { name:"Pet C7",rarity:7,stats:{attack:90,defense:45,speed:18}},
      { name:"Pet C8",rarity:8,stats:{attack:80,defense:40,speed:16}},
      { name:"Pet C9",rarity:9,stats:{attack:70,defense:35,speed:14}}
    ]
  },
  {
    name:"Legendary Egg",
    cost:100000,
    pets:[
      {name:"Pet D1",rarity:1,stats:{attack:200,defense:100,speed:40}},
      {name:"Pet D2",rarity:2,stats:{attack:185,defense:92,speed:37}},
      {name:"Pet D3",rarity:3,stats:{attack:170,defense:85,speed:34}},
      {name:"Pet D4",rarity:4,stats:{attack:155,defense:77,speed:31}},
      {name:"Pet D5",rarity:5,stats:{attack:140,defense:70,speed:28}},
      {name:"Pet D6",rarity:6,stats:{attack:125,defense:62,speed:25}},
      {name:"Pet D7",rarity:7,stats:{attack:110,defense:55,speed:22}},
      {name:"Pet D8",rarity:8,stats:{attack:95,defense:47,speed:19}},
      {name:"Pet D9",rarity:9,stats:{attack:80,defense:40,speed:16}}
    ]
  },
  {
    name:"Mythic Egg",
    cost:500000,
    pets:[
      {name:"Pet E1",rarity:1,stats:{attack:300,defense:150,speed:60}},
      {name:"Pet E2",rarity:2,stats:{attack:275,defense:137,speed:55}},
      {name:"Pet E3",rarity:3,stats:{attack:250,defense:125,speed:50}},
      {name:"Pet E4",rarity:4,stats:{attack:225,defense:112,speed:45}},
      {name:"Pet E5",rarity:5,stats:{attack:200,defense:100,speed:40}},
      {name:"Pet E6",rarity:6,stats:{attack:175,defense:87,speed:35}},
      {name:"Pet E7",rarity:7,stats:{attack:150,defense:75,speed:30}},
      {name:"Pet E8",rarity:8,stats:{attack:125,defense:62,speed:25}},
      {name:"Pet E9",rarity:9,stats:{attack:100,defense:50,speed:20}}
    ]
  }
];

// pastikan inventory ada
if(!gameState.petInventory){
  gameState.petInventory = [];
}

// ===== UI GENERATOR =====
function generateGachaUI(){
  const grid = document.querySelector(".gacha-grid");
  if(!grid) return;

  grid.innerHTML = "";

  gachaEggs.forEach((egg,i)=>{
    const card = document.createElement("div");
    card.className="gacha-card";

    card.innerHTML = `
      <div class="gacha-image">🥚</div>
      <div class="gacha-name">${egg.name}</div>
      <div class="gacha-cost">${formatNumber(egg.cost)}</div>
      <button class="gacha-btn" onclick="pullGacha(${i})">Pull</button>
    `;

    grid.appendChild(card);
  });

  updateGachaButtons();
}

// ===== PULL =====
function pullGacha(index){
  const egg = gachaEggs[index];

  if(gameState.clicks < egg.cost){
    alert("Not enough clicks");
    return;
  }

  gameState.clicks -= egg.cost;

  const pet = JSON.parse(JSON.stringify(
    egg.pets[Math.floor(Math.random()*egg.pets.length)]
  ));

  gameState.petInventory.push(pet);

  alert(`You got ${pet.name} (R${pet.rarity})`);

  updateUI();
  updatePetInventory();
  updateGachaButtons();
  saveGame();
}

// ===== BUTTON STATE =====
function updateGachaButtons(){
  const btns = document.querySelectorAll(".gacha-btn");
  btns.forEach((b,i)=>{
    if(gameState.clicks < gachaEggs[i].cost){
      b.disabled=true;
      b.classList.add("disabled");
    }else{
      b.disabled=false;
      b.classList.remove("disabled");
    }
  });
}

// ===== INVENTORY UI =====
function updatePetInventory(){
  const box = document.getElementById("petInventory");
  if(!box) return;

  box.innerHTML="";

  gameState.petInventory.forEach(p=>{
    const card = document.createElement("div");
    card.className="pet-card";

    card.innerHTML=`
      <div class="pet-image">🐾</div>
      <div class="pet-name">${p.name}</div>
      <div class="pet-rarity">Rarity ${p.rarity}</div>
      <div class="pet-stats">
        ATK ${p.stats.attack} |
        DEF ${p.stats.defense} |
        SPD ${p.stats.speed}
      </div>
    `;

    box.appendChild(card);
  });
}

// Big Number Tier System (URUTAN LENGKAP dari list user)
const bigNumberTiers = [
    { name: '', power: 0 },      // 1
    { name: 'K', power: 3 },      // 1K
    { name: 'M', power: 6 },      // 1M
    { name: 'B', power: 9 },      // 1B
    { name: 'T', power: 12 },     // 1T
    { name: 'Qa', power: 15 },    // 1Qa
    { name: 'Qi', power: 18 },    // 1Qi
    { name: 'Sx', power: 21 },    // 1Sx
    { name: 'Sp', power: 24 },    // 1Sp
    { name: 'Oc', power: 27 },    // 1Oc
    { name: 'No', power: 30 },    // 1No
    { name: 'DC', power: 33 },    // 1DC
    { name: 'Ud', power: 36 },    // 1Ud
    { name: 'Dd', power: 39 },    // 1Dd
    { name: 'Td', power: 42 },    // 1Td
    { name: 'Qad', power: 45 },   // 1Qad
    { name: 'Qid', power: 48 },   // 1Qid
    { name: 'Sxd', power: 51 },   // 1Sxd
    { name: 'Spd', power: 54 },   // 1Spd
    { name: 'Ocd', power: 57 },   // 1Ocd
    { name: 'Nod', power: 60 },   // 1Nod
    { name: 'Vg', power: 63 },    // 1Vg
    { name: 'Dvg', power: 66 },   // 1Dvg
    { name: 'Tvg', power: 69 },   // 1Tvg
    { name: 'Qavg', power: 72 },  // 1Qavg
    { name: 'Qivg', power: 75 },  // 1Qivg
    { name: 'Sxvg', power: 78 },  // 1Sxvg
    { name: 'Spvg', power: 81 },  // 1Spvg
    { name: 'Ocvg', power: 84 },  // 1Ocvg
    { name: 'Novg', power: 87 },  // 1Novg
    { name: 'Tg', power: 90 },    // 1Tg
    { name: 'Utg', power: 93 },   // 1Utg
    { name: 'Dtg', power: 96 },   // 1Dtg
    { name: 'Ttg', power: 99 },   // 1Ttg
    { name: 'Qatg', power: 102 }, // 1Qatg
    { name: 'Qitg', power: 105 }, // 1Qitg
    { name: 'Sxtg', power: 108 }, // 1Sxtg
    { name: 'Sptg', power: 111 }, // 1Sptg
    { name: 'Octg', power: 114 }, // 1Octg
    { name: 'Notg', power: 117 }, // 1Notg
    { name: 'Qag', power: 120 },  // 1Qag
    { name: 'Uqag', power: 123 }, // 1Uqag
    { name: 'Dqag', power: 126 }, // 1Dqag
    { name: 'Tqag', power: 129 }, // 1Tqag
    { name: 'Qaqag', power: 132 },// 1Qaqag
    { name: 'Sxqag', power: 135 },// 1Sxqag
    { name: 'Spqag', power: 138 },// 1Spqag
    { name: 'Ocqag', power: 141 } // 1Ocqag
];

// Format big numbers
function formatNumber(num) {
    // Handle decimals for small numbers (< 1000)
    if (num < 1000) {
        if (num % 1 === 0) {
            return num.toString(); // Integer
        } else {
            return num.toFixed(1); // Show 1 decimal for floats
        }
    }
    
    let tierIndex = 0;
    for (let i = bigNumberTiers.length - 1; i >= 0; i--) {
        if (num >= Math.pow(10, bigNumberTiers[i].power)) {
            tierIndex = i;
            break;
        }
    }
    
    const tier = bigNumberTiers[tierIndex];
    const value = num / Math.pow(10, tier.power);
    
    if (tier.name === '') {
        if (num % 1 === 0) {
            return num.toString();
        } else {
            return num.toFixed(1);
        }
    }
    
    // Format dengan 1 desimal kalo < 10, tanpa desimal kalo >= 10
    if (value < 10) {
        return value.toFixed(1) + tier.name;
    } else {
        return Math.floor(value) + tier.name;
    }
}

// Rebirth Base Options (50 total options - akan dipaginate)
const RebirthBaseOptions = [
    // Page 1 (10 options)
    { baseReward: 1, baseCost: 100 },
    { baseReward: 5, baseCost: 6200 },
    { baseReward: 10, baseCost: 17500 },
    { baseReward: 25, baseCost: 75000 },
    { baseReward: 50, baseCost: 250000 },
    { baseReward: 100, baseCost: 1000000 },
    { baseReward: 250, baseCost: 5000000 },
    { baseReward: 500, baseCost: 25000000 },
    { baseReward: 1000, baseCost: 100000000 },
    { baseReward: 2500, baseCost: 500000000 },
    
    // Page 2 (10 options)
    { baseReward: 5000, baseCost: 1e12 },
    { baseReward: 10000, baseCost: 5e12 },
    { baseReward: 25000, baseCost: 25e12 },
    { baseReward: 50000, baseCost: 100e12 },
    { baseReward: 100000, baseCost: 500e12 },
    { baseReward: 250000, baseCost: 1e15 },
    { baseReward: 500000, baseCost: 5e15 },
    { baseReward: 1000000, baseCost: 25e15 },
    { baseReward: 2500000, baseCost: 100e15 },
    { baseReward: 5000000, baseCost: 500e15 },
    
    // Page 3 (10 options)
    { baseReward: 10000000, baseCost: 1e18 },
    { baseReward: 25000000, baseCost: 5e18 },
    { baseReward: 50000000, baseCost: 25e18 },
    { baseReward: 100000000, baseCost: 100e18 },
    { baseReward: 250000000, baseCost: 500e18 },
    { baseReward: 500000000, baseCost: 1e21 },
    { baseReward: 1000000000, baseCost: 5e21 },
    { baseReward: 2500000000, baseCost: 25e21 },
    { baseReward: 5000000000, baseCost: 100e21 },
    { baseReward: 10000000000, baseCost: 500e21 },
    
    // Page 4 (10 options)
    { baseReward: 25000000000, baseCost: 1e24 },
    { baseReward: 50000000000, baseCost: 5e24 },
    { baseReward: 100000000000, baseCost: 25e24 },
    { baseReward: 250000000000, baseCost: 100e24 },
    { baseReward: 500000000000, baseCost: 500e24 },
    { baseReward: 1e12, baseCost: 1e27 },
    { baseReward: 2.5e12, baseCost: 5e27 },
    { baseReward: 5e12, baseCost: 25e27 },
    { baseReward: 10e12, baseCost: 100e27 },
    { baseReward: 25e12, baseCost: 500e27 },
    
    // Page 5 (10 options)
    { baseReward: 50e12, baseCost: 1e30 },
    { baseReward: 100e12, baseCost: 5e30 },
    { baseReward: 250e12, baseCost: 25e30 },
    { baseReward: 500e12, baseCost: 100e30 },
    { baseReward: 1e15, baseCost: 500e30 },
    { baseReward: 2.5e15, baseCost: 1e33 },
    { baseReward: 5e15, baseCost: 5e33 },
    { baseReward: 10e15, baseCost: 25e33 },
    { baseReward: 25e15, baseCost: 100e33 },
    { baseReward: 50e15, baseCost: 500e33 }
];

let currentRebirthPage = 1;
const optionsPerPage = 10;

// Calculate dynamic Rebirth cost
function calculateRebirthCost(baseCost, reward) {
    return baseCost + (gameState.totalRebirthCount * reward * 1000);
}

// settings
function toggleSettings() {
    const panel = document.getElementById("settingsPanel");
    panel.classList.toggle("show");
}

// Load game from localStorage
function loadGame() {
  if(!currentUser) return;

  const acc = getAccounts()[currentUser];
  if(acc && acc.save){
  gameState = acc.save;
}

syncAutoClickerDelay();  

gameState.RebirthMultiplier =
  1 + gameState.rebirthPoints * 0.1;

  updateUI();
  updateUpgradeUI();
}

function openProfile(){
  document.getElementById("profilePopup").style.display="flex";
}

function closeProfile(){
  document.getElementById("profilePopup").style.display="none";
}

function copyID(){
  const text = profileID.textContent;
  navigator.clipboard.writeText(text);
  alert("ID copied");
}

function playClickSound() {
    if (!gameState.clickSoundEnabled) return;

    const base = document.getElementById("clickSound");
    if (!base) return;

    const s = base.cloneNode();
    s.volume = 0.4;
    s.play().catch(()=>{});
    s.onended = () => s.remove();
}

// Wait for DOM to be ready
document.addEventListener('DOMContentLoaded', function() {

    if(currentUser){
        startUserSession();   // sudah load save di sini
    }else{
        // guest → pakai state default
        updateUI();
        updateUpgradeUI();
    }

    startAutoClicker();

    const toggle = document.getElementById("toggleClickSound");
    if(toggle){
        toggle.checked = gameState.clickSoundEnabled;

        toggle.addEventListener("change", () => {
            gameState.clickSoundEnabled = toggle.checked;
            saveGame();
        });
    }

    const clickBtn = document.getElementById('clickBtn');

    if (clickBtn) {
        clickBtn.addEventListener('click', function(e) {

            playClickSound();

            const actualPower =
                gameState.clickPower * gameState.RebirthMultiplier;

            gameState.clicks += actualPower;

            createParticle(e.clientX, e.clientY, actualPower);

            updateUI();
            updateUpgradeUI();
            saveGame();
        });
    }

});

// Create particle effect
function createParticle(x, y, power) {
    const particle = document.createElement('div');
    particle.className = 'particle';
    particle.textContent = `+${formatNumber(power)}`;
    particle.style.left = x + 'px';
    particle.style.top = y + 'px';
    particle.style.opacity = '1';
    particle.style.transform = 'translateY(0)';
    particle.style.position = 'fixed';
    particle.style.pointerEvents = 'none';
    particle.style.fontSize = '2.5em';
    particle.style.fontWeight = '700';
    particle.style.zIndex = '1000';
    particle.style.color = '#ffd700';
    particle.style.textShadow = '2px 2px 4px rgba(0, 0, 0, 0.5)';
    
    document.body.appendChild(particle);
    
    let pos = 0;
    let opacity = 1;
    const interval = setInterval(() => {
        pos -= 2;
        opacity -= 0.02;
        particle.style.transform = `translateY(${pos}px)`;
        particle.style.opacity = opacity;
        
        if (opacity <= 0) {
            clearInterval(interval);
            particle.remove();
        }
    }, 20);
}

// Buy upgrade
function buyUpgrade(type, amount) {
    const upgrade = gameState.upgrades[type];
    if (!upgrade) return;
    
    if (type === 'speedEnhancer') {
        if (upgrade.level >= 10) return;
        
        const cost = upgrade.costs[upgrade.level];
        if (gameState.clicks >= cost) {
            gameState.clicks -= cost;
            upgrade.level++;
            
            gameState.autoClickerDelay = Math.max(100, 1000 - (upgrade.level * 100));
            
            if (upgrade.level < 10) {
                upgrade.cost = upgrade.costs[upgrade.level];
            }
            
            updateAutoClickerCPS();
            restartAutoClicker();
        }
    } else {
        // Buy Max calculation
        if (amount === 'max') {
            let bought = 0;
            let tempCost = upgrade.cost;
            
            while (gameState.clicks >= tempCost) {
                gameState.clicks -= tempCost;
                bought++;
                tempCost = Math.floor(tempCost * upgrade.costMultiplier);
            }
            
            if (bought > 0) {
                if (type === 'clickPower') {
                    upgrade.level += bought;
                    gameState.clickPower += bought;
                } else if (type === 'autoClicker') {
                    upgrade.count += bought;
                    updateAutoClickerCPS();
                }
                upgrade.cost = tempCost;
            }
        } else {
            // Buy specific amount
            let totalCost = 0;
            let tempCost = upgrade.cost;
            
            for (let i = 0; i < amount; i++) {
                totalCost += tempCost;
                tempCost = Math.floor(tempCost * upgrade.costMultiplier);
            }
            
            if (gameState.clicks >= totalCost) {
                gameState.clicks -= totalCost;
                
                if (type === 'clickPower') {
                    upgrade.level += amount;
                    gameState.clickPower += amount;
                } else if (type === 'autoClicker') {
                    upgrade.count += amount;
                    updateAutoClickerCPS();
                }
                
                upgrade.cost = tempCost;
            }
        }
    }
    
    updateUI();
    updateUpgradeUI();
    saveGame();
}

// Update Auto-Clicker CPS
function getCpsPerUnitByTotal(totalCps) {
    if (totalCps >= 1_000_000) return 30000;
    if (totalCps >= 100_000)  return 6000;
    if (totalCps >= 10_000)   return 1250;
    if (totalCps >= 1_000)    return 250;
    if (totalCps >= 100)      return 50;
    return 10;
}

function updateAutoClickerCPS() {
    const count = gameState.upgrades.autoClicker.count;

    const tier = Math.floor(count / 10);   // tiap 10 naik tier
    const boost = Math.pow(2, tier);       // 2^tier

    const cps = count * 10 * boost;        // base 10/sec

    gameState.upgrades.autoClicker.cps = cps;
}

// Update UI
function updateUI() {
  document.getElementById('clickCount').textContent =
    formatNumber(gameState.clicks); 
  document.getElementById('clickPower').textContent =     
    formatNumber(gameState.clickPower);
  document.getElementById('totalRebirthDisplay').textContent =
    formatNumber(gameState.rebirthPoints);
  document.getElementById('multiplierDisplay').textContent =
    gameState.RebirthMultiplier.toFixed(1) + 'x';
  document.getElementById('totalRebirth').textContent =
    formatNumber(gameState.rebirthPoints);
  document.getElementById('currentMultiplier').textContent = 
    gameState.RebirthMultiplier.toFixed(1) + 'x';
}

function generateRebirthOptions() {
    const container = document.getElementById('RebirthOptions');
    if (!container) return;

    container.innerHTML = "";

    const startIndex = (currentRebirthPage - 1) * optionsPerPage;
    const endIndex = startIndex + optionsPerPage;
    const pageOptions = RebirthBaseOptions.slice(startIndex, endIndex);

    pageOptions.forEach((option, index) => {
        const actualIndex = startIndex + index;

        const cost = calculateRebirthCost(option.baseCost, option.baseReward);
        const isAvailable = gameState.clicks >= cost;

        const card = document.createElement('div');
        card.className = `Rebirth-card ${isAvailable ? 'available' : 'locked'}`;

        card.innerHTML = `
            <div class="Rebirth-cost">${formatNumber(cost)}</div>
            <div class="Rebirth-reward">+${formatNumber(option.baseReward)}</div>
        `;

        if (isAvailable) {
            card.addEventListener('click', () => performRebirth(actualIndex));
        }

        container.appendChild(card);
    });

    updateRebirthPagination();
}

// Update upgrade UI
function updateUpgradeUI() {
    // Click Power
    document.getElementById('level-clickPower').textContent = gameState.upgrades.clickPower.level;
    document.getElementById('cost-clickPower').textContent = formatNumber(gameState.upgrades.clickPower.cost);
    
    // Auto-Clicker
    document.getElementById('level-autoClicker').textContent = gameState.upgrades.autoClicker.count;
    document.getElementById('cost-autoClicker').textContent = formatNumber(gameState.upgrades.autoClicker.cost);
    document.getElementById('autoClickerCPS').textContent = formatNumber(gameState.upgrades.autoClicker.cps);
    
    // Speed Enhancer
    document.getElementById('level-speedEnhancer').textContent = gameState.upgrades.speedEnhancer.level;
    document.getElementById('cost-speedEnhancer').textContent = formatNumber(gameState.upgrades.speedEnhancer.cost);
    
    // Enable/disable buttons
    const upgrades = ['clickPower', 'autoClicker', 'speedEnhancer'];
    upgrades.forEach(type => {
        const cost = gameState.upgrades[type].cost;
        const buttons = document.querySelectorAll(`button[onclick*="${type}"]`);
        
        buttons.forEach(btn => {
            if (gameState.clicks < cost) {
                btn.classList.add('disabled');
                btn.disabled = true;
            } else {
                btn.classList.remove('disabled');
                btn.disabled = false;
            }
        });
        
        if (type === 'speedEnhancer' && gameState.upgrades.speedEnhancer.level >= 10) {
            buttons.forEach(btn => {
                btn.classList.add('disabled');
                btn.disabled = true;
            });
        }
    });
}

function showTab(tabName) {
    document.querySelectorAll('.tab-btn').forEach(btn => btn.classList.remove('active'));
    document.querySelectorAll('.tab-content').forEach(content => content.classList.remove('active'));
    
    if (tabName === 'game') {
        document.querySelectorAll('.tab-btn')[0].classList.add('active');
        document.getElementById('game-tab').classList.add('active');
    } 
    else if (tabName === 'Rebirth') {
        document.querySelectorAll('.tab-btn')[1].classList.add('active');
        document.getElementById('Rebirth-tab').classList.add('active');
        generateRebirthOptions();
    } 
    else if (tabName === 'gacha') {
        document.querySelectorAll('.tab-btn')[2].classList.add('active');
        document.getElementById('gacha-tab').classList.add('active');
        generateGachaUI();
        updatePetInventory();
    }
}

// Update Rebirth pagination UI
function updateRebirthPagination() {
    const totalPages = Math.ceil(RebirthBaseOptions.length / optionsPerPage);
    const pageInfo = document.getElementById('RebirthPageInfo');
    if (pageInfo) {
        pageInfo.textContent = `Page ${currentRebirthPage} of ${totalPages}`;
    }
    
    // Enable/disable buttons
    const prevBtn = document.getElementById('RebirthPrevBtn');
    const nextBtn = document.getElementById('RebirthNextBtn');
    
    if (prevBtn) {
        prevBtn.disabled = currentRebirthPage <= 1;
        prevBtn.classList.toggle('disabled', currentRebirthPage <= 1);
    }
    
    if (nextBtn) {
        nextBtn.disabled = currentRebirthPage >= totalPages;
        nextBtn.classList.toggle('disabled', currentRebirthPage >= totalPages);
    }
}

// Rebirth pagination controls
function previousRebirthPage() {
    if (currentRebirthPage > 1) {
        currentRebirthPage--;
        generateRebirthOptions();
    }
}

function nextRebirthPage() {
    const totalPages = Math.ceil(RebirthBaseOptions.length / optionsPerPage);
    if (currentRebirthPage < totalPages) {
        currentRebirthPage++;
        generateRebirthOptions();
    }
}

// Perform Rebirth
function performRebirth(optionIndex) {
    const option = RebirthBaseOptions[optionIndex];
    const cost = calculateRebirthCost(option.baseCost, option.baseReward);
    
    if (gameState.clicks >= cost) {
        // Reset
        gameState.clicks = 0;
        gameState.clickPower = 1;
        gameState.autoClickerDelay = 1000;
        
        // Reset upgrades
        gameState.upgrades.clickPower = { level: 0, cost: 10, costMultiplier: 1.15 };
        gameState.upgrades.autoClicker = { count: 0, cost: 100, costMultiplier: 1.25, cps: 0 };
        gameState.upgrades.speedEnhancer = { level: 0, cost: 1000, costs: [1000, 10000, 50000, 175000, 500000, 1000000, 2500000, 5000000, 10000000, 25000000] };
        
      syncAutoClickerDelay(); 
        
        // Add Rebirth
        const r = option.baseReward;

if (!gameState.rebirthLevels[r]) {
    gameState.rebirthLevels[r] = 0;
}

gameState.rebirthLevels[r] =
    (gameState.rebirthLevels[r] || 0) + 1;

gameState.totalRebirthCount += r;
gameState.rebirthPoints += r;
gameState.RebirthMultiplier =
    1 + gameState.rebirthPoints * 0.1;
        
        // Show animation
        showRebirthAnimation(option.baseReward);
        
        // Update
        updateUI();
        updateUpgradeUI();
        saveGame();
        generateRebirthOptions();
        restartAutoClicker();
    }
}

// Show Rebirth animation
function showRebirthAnimation(reward) {
    const message = `🎉 Rebirth! +${formatNumber(reward)} 🎉`;
    
    const msgEl = document.createElement('div');
    msgEl.textContent = message;
    msgEl.style.cssText = `
        position: fixed;
        top: 50%;
        left: 50%;
        transform: translate(-50%, -50%);
        background: linear-gradient(135deg, #e94560 0%, #ff5577 100%);
        color: #fff;
        padding: 30px 50px;
        border-radius: 15px;
        font-size: 1.8em;
        font-weight: bold;
        z-index: 10000;
        box-shadow: 0 10px 50px rgba(233, 69, 96, 0.5);
        animation: pulse 0.5s ease;
    `;
    
    document.body.appendChild(msgEl);
    
    setTimeout(() => {
        msgEl.remove();
    }, 2000);
}

// Auto-clicker
let autoClickerInterval = null;

function startAutoClicker() {
    if (autoClickerInterval) {
        clearInterval(autoClickerInterval);
    }

    autoClickerInterval = setInterval(() => {
        const cps = gameState.upgrades.autoClicker.cps;

        if (cps > 0) {
            const perTick = cps * gameState.RebirthMultiplier / (1000 / gameState.autoClickerDelay);
            gameState.clicks += perTick;
            updateUI();
        }
    }, gameState.autoClickerDelay);
}

function restartAutoClicker() {
    startAutoClicker();
}

// Pulse animation
const style = document.createElement('style');
style.textContent = `
    @keyframes pulse {
        0%, 100% { transform: translate(-50%, -50%) scale(1); }
        50% { transform: translate(-50%, -50%) scale(1.1); }
    }
`;
document.head.appendChild(style);

// Auto-save every 5 seconds
setInterval(saveGame, 5000);

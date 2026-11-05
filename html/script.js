let vehicleListings = [];
let clothingListings = [];
let sellableVehicles = [];
let sellableClothingSlots = [];
let myVehicleListings = [];
let myClothingListings = [];
let currentVehicleCategory = 'all';
let currentBidTarget = null;
let currentListVehicle = null;
let currentListClothing = null;
let premiumVehicles = [];

const CLASS_MAP = {
  super: 'adder zentorno t20 osiris reaper fmj italigtb tempesta nero penetrator xa21 pariah comet5 neon cyclone rapidgt3 sultanrs banshee2 autarch sc1 tyrant visione prototipo devil2 deveste krieger emerus furia zorrusso italirsx vagner s80 thrax komoda jugular sugoi rebla neo jester banshee infernus turismor cheetah entityxf'.split(' '),
  sport: 'blista felon felon2 jackal oracle oracle2 sentinel sentinel2 windsor windsor2 zion zion2 coquette4 sultan schafter2 schafter3 schafter4 schafter5 schafter6 cogcabrio exemplar f620 fusilade futo massacro massacro2 ninef ninef2 rapidgt rapidgt2 comet2 comet3 comet4 comet5 khamelion jester2 jester3 surano issi7 rsx gb200 ellie gauntlet deviant dominator4 dominator8 elegy elegy2 specter specter2 penumbra tampa tropos verlierer vstr stm growler comet6 champion ignus'.split(' '),
  sports_classic: 'btype btype2 btype3 casco cheetah2 coquette2 coquette3 feltzer2 feltzer3 gt500 infernus2 jb700 mamba manana monroe peyote pigalle retinue retinue2 stinger stingergt torero z190 ztype mille issi3 savestra'.split(' '),
  muscle: 'blade buccaneer buccaneer2 clique deviant dominator dominator2 dominator3 dominator4 dominator5 dominator7 dominator8 dukes dukes2 ellie faction faction2 faction3 gauntlet gauntlet2 gauntlet3 gauntlet4 gauntlet5 hotknife impaler impaler2 impaler3 impaler4 imperator imperator2 imperator3 lurcher moonbeam moonbeam2 peyote2 phoenix picador ratloader ratloader2 ruiner ruiner2 ruiner3 sabregt sabregt2 slamvan slamvan2 slamvan3 tulip vamos vigero vigero2 virgo virgo2 virgo3 voodoo yosemite yosemite2 hotring'.split(' '),
  offroad: 'bfinjection blazer blazer2 blazer3 blazer4 brawler caracara dune4 dune5 guardian hellion kalahari kamacho mesa mesa2 monster outlaw rancherxl rebel rebel2 riata sadler sandking sandking2 scarab trophytruck trophytruck2 vagrant verus winky draugur'.split(' '),
  motorcycles: 'akuma avarus bagger bati bati2 bf400 carbonrs cliffhanger daemon daemon2 defiler diablous diablous2 double esskey faggio faggio2 faggio3 fcr fcr2 gargoyle hakuchou hakuchou2 hexer innovation lectro manchez manchez2 nemesis nightblade oppressor oppressor2 pcj ratbike ruffian sanchez sanchez2 sovereign stryder thrust vader vindicator vortex wolfsbane zombia zombieb shotaro'.split(' '),
  sedans: 'asea asea2 asterope cog cog552 cognoscenti cognoscenti2 emperor emperor2 emperor3 fugitive glendale ingot intruder limo2 premier primo primo2 regina romero stanier stratum stretch superd surge tailgater warrener washington stafford virtue cinquemila'.split(' '),
  coupes: 'cogcabrio exemplar f620 felon felon2 jackal oracle oracle2 sentinel sentinel2 windsor windsor2 zion zion2'.split(' '),
  suvs: 'baller baller2 baller3 baller4 baller5 baller6 cavalcade cavalcade2 contender dubsta dubsta2 fq2 granger gresley habanero huntley landstalker mesa3 novak patriot patriot2 radi rebla rocoto seminole seminole2 serrano toros xls xls2'.split(' '),
  vans: 'bison bison2 bison3 bobcatxl burrito burrito2 burrito3 burrito4 burrito5 camper gburrito gburrito2 journey minivan minivan2 paradise pony pony2 rumpo rumpo2 rumpo3 speedo speedo2 speedo4 surfer surfer2 taco youga youga2 youga3'.split(' ')
};

// ============ NUI MESSAGE HANDLING ============
window.addEventListener('message', function (event) {
  const data = event.data;
  if (!data) return;
  switch (data.action) {
    case 'open':
      if (data.premiumVehicles) premiumVehicles = data.premiumVehicles;
      openUI(data.panel);
      break;
    case 'setListings':
      vehicleListings = data.vehicles || [];
      clothingListings = data.clothes || [];
      renderVehicleListings();
      renderClothingListings();
      break;
    case 'setSellable':
      sellableVehicles = data.vehicles || [];
      sellableClothingSlots = data.clothingSlots || [];
      renderSellableVehicles();
      renderSellableClothing();
      break;
    case 'setMyListings':
      myVehicleListings = data.vehicles || [];
      myClothingListings = data.clothes || [];
      renderMyVehicles();
      renderMyClothing();
      break;
  }
});

// ============ UI CONTROL ============
function openUI(panel) {
  document.getElementById('app').classList.remove('hidden');
  if (panel === 'list') switchTab('list');
  else if (panel === 'mine') { switchTab('mine'); requestMyListings(); }
  else switchTab('auction');
}

function closeUI() {
  document.getElementById('app').classList.add('hidden');
  post('close', {});
  closeAllModals();
}

function switchTab(tab) {
  document.querySelectorAll('.tab-btn').forEach(function (b) { b.classList.toggle('active', b.dataset.tab === tab); });
  document.querySelectorAll('.tab-content').forEach(function (c) { c.classList.toggle('active', c.id === 'tab-' + tab); });
  if (tab === 'auction') post('getListings', {});
  else if (tab === 'list') post('getSellableInfo', {});
  else if (tab === 'mine') requestMyListings();
}

function switchSubTab(sub) {
  document.querySelectorAll('.sub-tab-btn').forEach(function (b) { b.classList.toggle('active', b.dataset.sub === sub); });
  document.querySelectorAll('.sub-tab-content').forEach(function (c) { c.classList.toggle('active', c.id === 'sub-' + sub); });
}

function filterVehicles(cat) {
  currentVehicleCategory = cat;
  document.querySelectorAll('.cat-btn').forEach(function (b) { b.classList.toggle('active', b.dataset.cat === cat); });
  renderVehicleListings();
}

function post(action, data) {
  fetch('https://auction_house/' + action, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data || {})
  });
}

function requestMyListings() { post('getMyListings', {}); }

// ============ HELPERS ============
function getVehicleCategory(model) {
  model = String(model).toLowerCase();
  for (var cat in CLASS_MAP) {
    if (CLASS_MAP[cat].indexOf(model) !== -1) return cat;
  }
  return 'sport';
}

function isPremium(model) {
  model = String(model).toLowerCase();
  return premiumVehicles.indexOf(model) !== -1;
}

function formatPrice(p) { return '$' + Number(p || 0).toLocaleString(); }

function daysLeft(endsAt) {
  if (!endsAt) return '';
  var diff = new Date(endsAt.replace(' ', 'T')) - new Date();
  if (diff <= 0) return 'Ended';
  var h = Math.floor(diff / 3600000);
  var d = Math.floor(h / 24);
  if (d > 0) return d + 'd ' + (h % 24) + 'h left';
  return h + 'h left';
}

function getShortName(id) {
  if (!id) return 'Unknown';
  if (id.indexOf('license:') === 0) return id.substring(8, 14) + '...';
  return id;
}

// ============ RENDER: VEHICLE LISTINGS ============
function renderVehicleListings() {
  var container = document.getElementById('vehicle-listings');
  var empty = document.getElementById('empty-vehicles');
  container.innerHTML = '';

  var filtered = vehicleListings;
  if (currentVehicleCategory !== 'all') {
    filtered = filtered.filter(function (v) { return getVehicleCategory(v.vehicle_model) === currentVehicleCategory; });
  }
  filtered.sort(function (a, b) {
    var ap = isPremium(a.vehicle_model) ? 1 : 0;
    var bp = isPremium(b.vehicle_model) ? 1 : 0;
    return bp - ap;
  });

  if (filtered.length === 0) {
    empty.classList.remove('hidden');
    container.classList.add('hidden');
    return;
  }
  empty.classList.add('hidden');
  container.classList.remove('hidden');

  filtered.forEach(function (l) {
    var premium = isPremium(l.vehicle_model);
    var name = l.item_name || l.vehicle_model;
    var bidder = l.bidder ? getShortName(l.bidder) : 'None';
    var card = document.createElement('div');
    card.className = 'listing-card' + (premium ? ' premium' : '');
    card.innerHTML =
      '<div class="listing-name">' + name + (premium ? ' <span class="premium-badge">Premium</span>' : '') + '</div>' +
      '<div class="listing-detail">Model: ' + l.vehicle_model + '</div>' +
      '<div class="listing-price">' + formatPrice(l.price) + '</div>' +
      '<div class="listing-current-bid">Current Bid: ' + (l.bid > 0 ? formatPrice(l.bid) : 'No bids') + '</div>' +
      '<div class="listing-detail">Top Bidder: ' + bidder + '</div>' +
      '<div class="listing-days-left">' + daysLeft(l.ends_at) + '</div>' +
      '<div class="listing-actions">' +
      '<button class="action-btn buy-now-btn" onclick="post(\'buyNow\',{id:' + l.id + '})">Buy Now</button>' +
      '<button class="action-btn bid-btn" onclick="openBidModal(' + l.id + ',\'' + name.replace(/'/g, "\\'") + '\')">Bid</button>' +
      '<button class="action-btn preview-btn" onclick="post(\'spawnPreview\',{model:\'' + l.vehicle_model + '\'})">Preview</button>' +
      '</div>';
    container.appendChild(card);
  });
}

// ============ RENDER: CLOTHING LISTINGS ============
function renderClothingListings() {
  var container = document.getElementById('clothing-listings');
  var empty = document.getElementById('empty-clothes');
  container.innerHTML = '';

  if (clothingListings.length === 0) {
    empty.classList.remove('hidden');
    container.classList.add('hidden');
    return;
  }
  empty.classList.add('hidden');
  container.classList.remove('hidden');

  clothingListings.forEach(function (l) {
    var name = l.label || l.slot;
    var bidder = l.bidder ? getShortName(l.bidder) : 'None';
    var card = document.createElement('div');
    card.className = 'listing-card';
    card.innerHTML =
      '<div class="listing-name">' + name + '</div>' +
      '<div class="listing-detail">Slot: ' + l.slot + ' | Drawable: ' + l.drawable + ' | Texture: ' + l.texture + '</div>' +
      '<div class="listing-price">' + formatPrice(l.price) + '</div>' +
      '<div class="listing-current-bid">Current Bid: ' + (l.bid > 0 ? formatPrice(l.bid) : 'No bids') + '</div>' +
      '<div class="listing-detail">Top Bidder: ' + bidder + '</div>' +
      '<div class="listing-days-left">' + daysLeft(l.ends_at) + '</div>' +
      '<div class="listing-actions">' +
      '<button class="action-btn buy-now-btn" onclick="post(\'buyNow\',{id:' + l.id + '})">Buy Now</button>' +
      '<button class="action-btn bid-btn" onclick="openBidModal(' + l.id + ',\'' + name.replace(/'/g, "\\'") + '\')">Bid</button>' +
      '</div>';
    container.appendChild(card);
  });
}

// ============ RENDER: SELLABLE ============
function renderSellableVehicles() {
  var container = document.getElementById('sellable-vehicles');
  container.innerHTML = '';
  if (sellableVehicles.length === 0) {
    container.innerHTML = '<div class="empty-msg">You have no sellable vehicles in your garage.</div>';
    return;
  }
  sellableVehicles.forEach(function (v) {
    var premium = isPremium(v.model);
    var name = v.label || v.model;
    var item = document.createElement('div');
    item.className = 'sell-item';
    item.innerHTML =
      '<div>' +
      '<div class="sell-item-name">' + name + (premium ? ' <span class="premium-badge">Premium</span>' : '') + '</div>' +
      '<div class="sell-item-meta">' + v.model + ' - Plate: ' + (v.plate || 'N/A') + '</div>' +
      '</div>' +
      '<button class="sell-item-btn" onclick="openVehicleListModal(\'' + v.model.replace(/'/g, "\\'") + '\',\'' + name.replace(/'/g, "\\'") + '\')">Sell</button>';
    container.appendChild(item);
  });
}

function renderSellableClothing() {
  var container = document.getElementById('sellable-clothing');
  container.innerHTML = '';
  if (sellableClothingSlots.length === 0) {
    container.innerHTML = '<div class="empty-msg">No clothing slots available to sell.</div>';
    return;
  }
  sellableClothingSlots.forEach(function (s) {
    var item = document.createElement('div');
    item.className = 'sell-item';
    item.innerHTML =
      '<div>' +
      '<div class="sell-item-name">' + s.label + '</div>' +
      '<div class="sell-item-meta">Slot: ' + s.slot + ' | Suggested: ' + formatPrice(s.price) + '</div>' +
      '</div>' +
      '<button class="sell-item-btn" onclick="openClothingListModal(\'' + s.slot.replace(/'/g, "\\'") + '\',\'' + s.label.replace(/'/g, "\\'") + '\',' + (s.price || 0) + ')">Sell</button>';
    container.appendChild(item);
  });
}

// ============ RENDER: MY LISTINGS ============
function renderMyVehicles() {
  var c = document.getElementById('my-vehicle-listings');
  var empty = document.getElementById('empty-my-vehicles');
  c.innerHTML = '';
  if (myVehicleListings.length === 0) { empty.classList.remove('hidden'); return; }
  empty.classList.add('hidden');
  myVehicleListings.forEach(function (l) {
    var card = document.createElement('div');
    card.className = 'listing-card';
    var cancelBtn = l.status === 'active' ? '<div class="listing-actions"><button class="action-btn cancel-btn" onclick="post(\'cancelListing\',{id:' + l.id + '})">Cancel</button></div>' : '';
    card.innerHTML =
      '<div class="listing-name">' + (l.item_name || l.vehicle_model) + '</div>' +
      '<div class="listing-detail">Status: ' + l.status + '</div>' +
      '<div class="listing-price">' + formatPrice(l.price) + '</div>' +
      '<div class="listing-current-bid">Current Bid: ' + (l.bid > 0 ? formatPrice(l.bid) : 'No bids') + '</div>' +
      '<div class="listing-days-left">' + daysLeft(l.ends_at) + '</div>' +
      cancelBtn;
    c.appendChild(card);
  });
}

function renderMyClothing() {
  var c = document.getElementById('my-clothing-listings');
  var empty = document.getElementById('empty-my-clothes');
  c.innerHTML = '';
  if (myClothingListings.length === 0) { empty.classList.remove('hidden'); return; }
  empty.classList.add('hidden');
  myClothingListings.forEach(function (l) {
    var card = document.createElement('div');
    card.className = 'listing-card';
    var cancelBtn = l.status === 'active' ? '<div class="listing-actions"><button class="action-btn cancel-btn" onclick="post(\'cancelListing\',{id:' + l.id + ',isClothing:true})">Cancel</button></div>' : '';
    card.innerHTML =
      '<div class="listing-name">' + (l.label || l.slot) + '</div>' +
      '<div class="listing-detail">Status: ' + l.status + '</div>' +
      '<div class="listing-price">' + formatPrice(l.price) + '</div>' +
      '<div class="listing-current-bid">Current Bid: ' + (l.bid > 0 ? formatPrice(l.bid) : 'No bids') + '</div>' +
      '<div class="listing-days-left">' + daysLeft(l.ends_at) + '</div>' +
      cancelBtn;
    c.appendChild(card);
  });
}

// ============ MODALS ============
function openVehicleListModal(model, label) {
  currentListVehicle = { model: model, label: label };
  document.getElementById('modal-vehicle-name').textContent = 'Vehicle: ' + label + ' (' + model + ')';
  document.getElementById('vehicle-price').value = '';
  document.getElementById('modal-list-vehicle').classList.remove('hidden');
}

function openClothingListModal(slot, label, suggested) {
  currentListClothing = { slot: slot, label: label };
  document.getElementById('modal-clothing-name').textContent = 'Item: ' + label;
  document.getElementById('clothing-price').value = suggested || '';
  document.getElementById('modal-list-clothing').classList.remove('hidden');
}

function openBidModal(id, name) {
  currentBidTarget = { id: id };
  document.getElementById('modal-bid-item').textContent = 'Item: ' + name;
  document.getElementById('bid-amount').value = '';
  document.getElementById('modal-bid').classList.remove('hidden');
}

function closeModal(mid) { document.getElementById(mid).classList.add('hidden'); }

function closeAllModals() {
  closeModal('modal-list-vehicle');
  closeModal('modal-list-clothing');
  closeModal('modal-bid');
  currentListVehicle = null;
  currentListClothing = null;
  currentBidTarget = null;
}

// ============ ACTIONS ============
function confirmListVehicle() {
  var price = parseInt(document.getElementById('vehicle-price').value);
  if (!price || price < 1) { alert('Enter a valid price.'); return; }
  if (currentListVehicle) post('listVehicle', { model: currentListVehicle.model, price: price });
  closeModal('modal-list-vehicle');
}

function confirmListClothing() {
  var price = parseInt(document.getElementById('clothing-price').value);
  if (!price || price < 1) { alert('Enter a valid price.'); return; }
  if (currentListClothing) post('listClothing', { slot: currentListClothing.slot, price: price });
  closeModal('modal-list-clothing');
}

function confirmBid() {
  var amount = parseInt(document.getElementById('bid-amount').value);
  if (!amount || amount < 1) { alert('Enter a valid bid.'); return; }
  if (currentBidTarget) post('placeBid', { id: currentBidTarget.id, amount: amount });
  closeModal('modal-bid');
}

document.addEventListener('keydown', function (e) {
  if (e.key === 'Escape') closeUI();
});

// R3P Mobile Controller
let exercises = [];
let currentTab = "home";

// Theme State Management
let currentTheme = localStorage.getItem("r3p_theme") || "dark";

function applyTheme(theme) {
  currentTheme = theme;
  document.body.setAttribute("data-theme", theme);
  localStorage.setItem("r3p_theme", theme);
  const icon = document.getElementById("theme-icon");
  if (icon) {
    icon.textContent = theme === "dark" ? "light_mode" : "dark_mode";
  }
}

function toggleTheme() {
  const next = currentTheme === "dark" ? "light" : "dark";
  applyTheme(next);
  showToast(next === "light" ? "Light Theme Enabled" : "Dark Theme Enabled", next === "light" ? "wb_sunny" : "dark_mode");
}

document.addEventListener("DOMContentLoaded", async function() {
  applyTheme(currentTheme);
  const themeBtn = document.getElementById("theme-toggle-btn");
  if (themeBtn) {
    themeBtn.onclick = toggleTheme;
  }
  try {
    const res = await fetch("data/exercises.json");
    exercises = await res.json();
  } catch(e) {}
  render();
});

function render() {
  const user = window.appStore.getCurrentUser();
  const gym = window.appStore.getActiveGym();
  document.getElementById("header-gym-name").textContent = gym.name;
  document.getElementById("current-role-title").textContent = user.role.toUpperCase();
  document.getElementById("role-switcher-btn").onclick = openRoleModal;

  const c = document.getElementById("screen-container");
  const n = document.getElementById("bottom-nav");

  if (user.role === "owner") renderOwner(c, n);
  else if (user.role === "member") renderMember(c, n);
  else if (user.role === "trainer") renderTrainer(c, n);
  else if (user.role === "staff") renderStaff(c, n);
  else renderPlatform(c, n);
}

function showToast(m, icon, isErr) {
  const box = document.getElementById("toast-container");
  if (!box) return;
  const t = document.createElement("div");
  t.className = "toast";
  t.style.borderColor = isErr ? "var(--accent-rose)" : "var(--primary)";
  const iconColor = isErr ? "var(--accent-rose)" : "var(--accent-emerald)";
  t.innerHTML = `<span class="material-icons-round" style="color:${iconColor}">${icon || "check_circle"}</span><span style="font-size:13px;font-weight:600;color:#fff;">${m}</span>`;
  box.appendChild(t);
  setTimeout(function() { t.remove(); }, 3000);
}

function openRoleModal() {
  const modal = document.getElementById("app-modal");
  const sheet = document.getElementById("modal-sheet-content");
  let h = `<div class="modal-handle"></div><div style="display:flex;justify-content:space-between;margin-bottom:14px;"><h3 style="font-size:18px;font-weight:800;">Switch User Role</h3><span class="material-icons-round" style="cursor:pointer;" onclick="closeModal()">close</span></div>`;
  const roles = [
    { key: "owner", name: "Gym Owner", icon: "admin_panel_settings", desc: "Analytics, Members, Payroll, CSV" },
    { key: "member", name: "Gym Member (Aarav)", icon: "fitness_center", desc: "Workouts, 1000+ Vault, Class Booking, Dues" },
    { key: "trainer", name: "Trainer (Marcus)", icon: "sports", desc: "Assigned Clients, Workout Routine, PT" },
    { key: "staff", name: "Staff (Deepak)", icon: "fingerprint", desc: "GPS Geofenced Clock-in/Clock-out" },
    { key: "platform_admin", name: "SaaS Platform Operator", icon: "hub", desc: "Multi-tenant Gyms & Subscriptions" }
  ];
  h += `<div style="display:flex;flex-direction:column;gap:8px;">`;
  roles.forEach(function(r) {
    h += `<button class="btn btn-secondary" style="justify-content:flex-start;padding:12px;" onclick="setRole('${r.key}')"><span class="material-icons-round" style="color:var(--primary);font-size:24px;">${r.icon}</span><div style="text-align:left;"><div style="font-weight:700;">${r.name}</div><div style="font-size:11px;color:var(--text-muted);">${r.desc}</div></div></button>`;
  });
  h += `</div>`;
  sheet.innerHTML = h;
  modal.classList.add("active");
}

function closeModal() {
  const m = document.getElementById("app-modal");
  if (m) m.classList.remove("active");
}

function setRole(r) {
  window.appStore.setRole(r);
  closeModal();
  currentTab = "home";
  render();
  showToast("Switched to " + r.toUpperCase(), "verified_user");
}

function switchTab(t) {
  currentTab = t;
  render();
}

function renderOwner(c, n) {
  n.innerHTML = `<div class="nav-item ${currentTab === "home" ? "active" : ""}" onclick="switchTab('home')"><span class="material-icons-round">analytics</span><span>Overview</span></div>
    <div class="nav-item ${currentTab === "members" ? "active" : ""}" onclick="switchTab('members')"><span class="material-icons-round">group</span><span>Members</span></div>
    <div class="nav-item ${currentTab === "staff" ? "active" : ""}" onclick="switchTab('staff')"><span class="material-icons-round">badge</span><span>Staff</span></div>
    <div class="nav-item ${currentTab === "fin" ? "active" : ""}" onclick="switchTab('fin')"><span class="material-icons-round">receipt_long</span><span>Finances</span></div>`;

  if (currentTab === "home") {
    const fin = window.appStore.getFinancialSummary();
    const gym = window.appStore.getActiveGym();
    let h = `<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:14px;"><div><h2 style="font-size:20px;font-weight:800;">Operational Pulse</h2><div style="font-size:12px;color:var(--text-muted);">${gym.city} • Multi-tenant Workspace</div></div><button class="btn btn-primary btn-sm" onclick="openEnrollModal()"><span class="material-icons-round" style="font-size:16px;">person_add</span> Add</button></div>`;
    h += `<div class="kpi-grid">
      <div class="kpi-card"><div class="kpi-label">Total Revenue</div><div class="kpi-val">₹${fin.totalCollectedINR.toLocaleString("en-IN")}</div><div class="kpi-sub">+18.4% month</div></div>
      <div class="kpi-card"><div class="kpi-label">Pending Dues</div><div class="kpi-val" style="color:var(--accent-rose);">₹${fin.pendingDuesINR.toLocaleString("en-IN")}</div><div class="kpi-sub" style="color:var(--accent-amber);">1 overdue</div></div>
      <div class="kpi-card"><div class="kpi-label">Active Members</div><div class="kpi-val">${fin.activeMembersCount}</div><div class="kpi-sub">94% retention</div></div>
      <div class="kpi-card"><div class="kpi-label">Expiring Soon</div><div class="kpi-val" style="color:var(--accent-amber);">${fin.expiringSoonCount}</div><div class="kpi-sub">Reminders queued</div></div>
      </div>`;
    h += `<div class="glass-card"><div style="font-weight:700;margin-bottom:10px;">Quick Controls</div><div style="display:grid;grid-template-columns:repeat(3,1fr);gap:8px;">
      <button class="btn btn-secondary btn-sm" style="flex-direction:column;padding:10px 4px;font-size:11px;" onclick="switchTab('members')"><span class="material-icons-round" style="color:var(--accent-cyan);">qr_code_scanner</span>Check-in</button>
      <button class="btn btn-secondary btn-sm" style="flex-direction:column;padding:10px 4px;font-size:11px;" onclick="openGeofenceModal()"><span class="material-icons-round" style="color:var(--accent-amber);">fmd_good</span>Geofence</button>
      <button class="btn btn-secondary btn-sm" style="flex-direction:column;padding:10px 4px;font-size:11px;" onclick="downloadCsv()"><span class="material-icons-round" style="color:var(--accent-emerald);">file_download</span>CSV</button>
      </div></div>`;
    h += `<div class="glass-card" style="background:linear-gradient(135deg,rgba(20,23,36,0.9),rgba(99,102,241,0.15));border-color:rgba(99,102,241,0.3);"><div style="display:flex;justify-content:space-between;align-items:center;"><div><span class="badge badge-info">SaaS Subscription</span><div style="font-size:15px;font-weight:800;margin-top:4px;">R3P Pro (₹999/mo)</div><div style="font-size:11px;color:var(--text-muted);">Renews on ${gym.subscription.renewsOn}</div></div><span class="material-icons-round" style="font-size:32px;color:var(--secondary);">cloud_done</span></div></div>`;
    c.innerHTML = h;
  } else if (currentTab === "members") {
    const mems = window.appStore.getGymMembers();
    let h = `<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:14px;"><h2 style="font-size:20px;font-weight:800;">Members (${mems.length})</h2><button class="btn btn-primary btn-sm" onclick="openEnrollModal()"><span class="material-icons-round" style="font-size:16px;">add</span> New</button></div>`;
    mems.forEach(function(m) {
      h += `<div class="glass-card" style="padding:14px;margin-bottom:10px;"><div style="display:flex;justify-content:space-between;align-items:center;"><div style="display:flex;align-items:center;gap:10px;"><img src="${m.avatar}" style="width:40px;height:40px;border-radius:50%;object-fit:cover;"><div><div style="font-weight:700;">${m.name}</div><div style="font-size:11px;color:var(--text-muted);">${m.phone}</div></div></div><span class="badge ${m.membershipStatus === "active" ? "badge-success" : "badge-warning"}">${m.membershipStatus === "active" ? "Active" : "Expiring"}</span></div>`;
      h += `<div style="display:flex;justify-content:space-between;margin-top:10px;font-size:11px;color:var(--text-muted);"><div>Expiry: <strong style="color:#fff;">${m.planExpiry}</strong></div><div>Dues: <strong style="color:${m.outstandingDuesINR > 0 ? "var(--accent-rose)" : "var(--accent-emerald)"};">₹${m.outstandingDuesINR}</strong></div></div>`;
      if (m.outstandingDuesINR > 0) {
        h += `<button class="btn btn-primary btn-sm btn-block" style="margin-top:10px;" onclick="collectDues('${m.id}', ${m.outstandingDuesINR})"><span class="material-icons-round" style="font-size:14px;">receipt</span> Collect ₹${m.outstandingDuesINR}</button>`;
      }
      h += `</div>`;
    });
    c.innerHTML = h;
  } else if (currentTab === "staff") {
    const stf = window.appStore.state.users.filter(function(u) { return (u.role === "trainer" || u.role === "staff") && u.gymId === window.appStore.state.session.activeGymId; });
    const att = window.appStore.state.staffAttendance.filter(function(a) { return a.gymId === window.appStore.state.session.activeGymId; });
    let h = `<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:14px;"><h2 style="font-size:20px;font-weight:800;">Staff & Payroll</h2><button class="btn btn-primary btn-sm" onclick="showToast('Staff invite link copied!', 'content_copy')"><span class="material-icons-round" style="font-size:16px;">share</span> Invite</button></div>`;
    h += `<div class="glass-card" style="background:linear-gradient(135deg,rgba(20,23,36,0.9),rgba(16,185,129,0.15));border-color:rgba(16,185,129,0.3);"><div style="display:flex;justify-content:space-between;align-items:center;"><div><div style="font-size:11px;color:var(--accent-emerald);font-weight:700;">MONTHLY PAYROLL</div><div style="font-size:24px;font-weight:800;">₹69,000</div><div style="font-size:11px;color:var(--text-muted);">100% disbursed • 0 pending</div></div><span class="material-icons-round" style="font-size:36px;color:var(--accent-emerald);">account_balance_wallet</span></div></div>`;
    h += `<h3 style="font-size:14px;font-weight:700;margin:16px 0 10px;">Employees & Trainers</h3>`;
    stf.forEach(function(s) {
      h += `<div class="glass-card" style="padding:12px;margin-bottom:8px;"><div style="display:flex;justify-content:space-between;align-items:center;"><div style="display:flex;align-items:center;gap:10px;"><img src="${s.avatar}" style="width:38px;height:38px;border-radius:50%;object-fit:cover;"><div><div style="font-weight:700;">${s.name}</div><div style="font-size:11px;color:var(--text-muted);">${s.role === "trainer" ? "Certified Trainer" : "Operations Desk"}</div></div></div><span class="badge badge-info">${s.role.toUpperCase()}</span></div></div>`;
    });
    h += `<h3 style="font-size:14px;font-weight:700;margin:16px 0 10px;">Today Attendance</h3>`;
    att.forEach(function(a) {
      h += `<div class="glass-card" style="padding:12px;margin-bottom:8px;"><div style="display:flex;justify-content:space-between;align-items:center;"><div><div style="font-weight:700;">${a.staffName}</div><div style="font-size:11px;color:var(--text-muted);">${a.clockInTime} • ${a.clockInDistanceMeters}m from gym</div></div><span class="badge badge-success">GPS Verified</span></div></div>`;
    });
    c.innerHTML = h;
  } else {
    const tx = window.appStore.state.transactions.filter(function(t) { return t.gymId === window.appStore.state.session.activeGymId; });
    let h = `<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:14px;"><h2 style="font-size:20px;font-weight:800;">Financial Ledger</h2><button class="btn btn-secondary btn-sm" onclick="downloadCsv()"><span class="material-icons-round" style="font-size:16px;">download</span> Export CSV</button></div>`;
    h += `<div class="glass-card"><div style="font-size:12px;color:var(--text-muted);">Verified accounting transactions recorded with 18% GST splits and sandbox signatures.</div></div>`;
    tx.forEach(function(t) {
      h += `<div class="glass-card" style="padding:12px;margin-bottom:8px;"><div style="display:flex;justify-content:space-between;align-items:flex-start;"><div><div style="font-weight:700;">Invoice #${t.invoiceNumber || t.id}</div><div style="font-size:11px;color:var(--text-muted);">${new Date(t.date).toLocaleDateString()} • ${t.method}</div><div style="font-size:10px;color:var(--text-dim);">Ref: ${t.referenceNo}</div></div><div style="text-align:right;"><div style="font-weight:800;color:var(--accent-emerald);">+₹${t.amountINR.toLocaleString("en-IN")}</div><span class="badge badge-success" style="font-size:10px;">Settled</span></div></div></div>`;
    });
    c.innerHTML = h;
  }
}

function renderMember(c, n) {
  n.innerHTML = `<div class="nav-item ${currentTab === "home" ? "active" : ""}" onclick="switchTab('home')"><span class="material-icons-round">fitness_center</span><span>Home</span></div>
    <div class="nav-item ${currentTab === "vault" ? "active" : ""}" onclick="switchTab('vault')"><span class="material-icons-round">sports_gymnastics</span><span>1000+ Vault</span></div>
    <div class="nav-item ${currentTab === "classes" ? "active" : ""}" onclick="switchTab('classes')"><span class="material-icons-round">calendar_month</span><span>Classes</span></div>
    <div class="nav-item ${currentTab === "dues" ? "active" : ""}" onclick="switchTab('dues')"><span class="material-icons-round">account_balance_wallet</span><span>Dues & Pay</span></div>`;

  const user = window.appStore.getCurrentUser();
  if (currentTab === "home") {
    let h = `<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:14px;"><div><h2 style="font-size:20px;font-weight:800;">Welcome back, ${user.name.split(" ")[0]}!</h2><div style="font-size:12px;color:var(--text-muted);">Gold Annual Membership • Active</div></div><img src="${user.avatar}" style="width:42px;height:42px;border-radius:50%;object-fit:cover;border:2px solid var(--primary);"></div>`;
    h += `<div class="glass-card" style="background:linear-gradient(135deg,rgba(255,51,102,0.15),rgba(20,23,36,0.9));border-color:rgba(255,51,102,0.4);"><div style="display:flex;justify-content:space-between;align-items:center;"><div><div style="font-size:11px;color:var(--primary);font-weight:700;">CONSISTENCY STREAK</div><div style="font-size:24px;font-weight:800;">${user.streakCurrent} Days Strong</div><div style="font-size:11px;color:var(--text-muted);">Personal Best: ${user.streakBest} Days • ${user.monthlyVisits} visits this month</div></div><span class="material-icons-round" style="font-size:42px;color:var(--primary);">local_fire_department</span></div></div>`;
    if (user.outstandingDuesINR > 0) {
      h += `<div class="glass-card" style="border-color:rgba(244,63,94,0.4);"><div style="display:flex;justify-content:space-between;align-items:center;"><div><div style="font-weight:700;color:var(--accent-rose);">Pending Due: ₹${user.outstandingDuesINR}</div><div style="font-size:11px;color:var(--text-muted);">Due for quarterly cycle</div></div><button class="btn btn-primary btn-sm" onclick="switchTab('dues')">Pay Now</button></div></div>`;
    }
    const w = window.appStore.state.memberWorkouts[0];
    h += `<div class="glass-card"><div style="font-weight:700;margin-bottom:10px;">${w.title}</div>`;
    w.exercises.forEach(function(ex, i) {
      h += `<div style="display:flex;justify-content:space-between;align-items:center;padding:8px;background:var(--bg-surface);border-radius:8px;margin-bottom:6px;"><div><div style="font-weight:700;font-size:13px;">${i+1}. ${ex.name}</div><div style="font-size:11px;color:var(--text-muted);">${ex.sets} sets × ${ex.reps} reps • ${ex.targetWeightKg}kg • Rest: ${ex.rest}</div></div><input type="checkbox" style="width:18px;height:18px;accent-color:var(--primary);" ${ex.completed ? "checked" : ""}></div>`;
    });
    h += `<button class="btn btn-primary btn-block" style="margin-top:10px;" onclick="showToast('Workout completed and synced to cloud!', 'cloud_done')"><span class="material-icons-round">done_all</span> Complete Workout Session</button></div>`;
    c.innerHTML = h;
  } else if (currentTab === "vault") {
    let h = `<div style="margin-bottom:14px;"><h2 style="font-size:20px;font-weight:800;">Exercise Vault (${exercises.length})</h2><div style="font-size:12px;color:var(--text-muted);">1,000+ scientific biomechanical guides with safety cues</div></div>`;
    h += `<div class="form-group"><input type="text" class="form-control" placeholder="Search Bench, Deadlift, Cable, Squats..." oninput="searchVault(this.value)"></div>`;
    h += `<div id="vault-list">`;
    exercises.slice(0, 15).forEach(function(ex) {
      h += `<div class="glass-card" style="padding:12px;margin-bottom:8px;"><div style="display:flex;justify-content:space-between;"><div style="font-weight:700;">${ex.name}</div><span class="badge badge-info">${ex.muscle}</span></div><div style="font-size:11px;color:var(--text-muted);margin:4px 0;">${ex.instructions}</div><div style="font-size:11px;color:var(--accent-emerald);">Safety: ${ex.safety}</div></div>`;
    });
    h += `</div>`;
    c.innerHTML = h;
  } else if (currentTab === "classes") {
    let h = `<h2 style="font-size:20px;font-weight:800;margin-bottom:14px;">Class Booking</h2>`;
    window.appStore.state.classes.forEach(function(cl) {
      h += `<div class="glass-card"><div style="display:flex;justify-content:space-between;align-items:flex-start;"><div><div style="font-size:16px;font-weight:800;">${cl.title}</div><div style="font-size:11px;color:var(--text-muted);">${cl.time} (${cl.duration}) • Coach ${cl.trainerName}</div><div style="font-size:11px;color:var(--text-muted);">Location: ${cl.location}</div></div><span class="badge badge-success">${cl.capacity - cl.bookedCount} slots left</span></div><button class="btn btn-primary btn-block btn-sm" style="margin-top:12px;" onclick="bookClass('${cl.id}', '${cl.title}')"><span class="material-icons-round" style="font-size:16px;">event_seat</span> Reserve Spot</button></div>`;
    });
    c.innerHTML = h;
  } else {
    let h = `<h2 style="font-size:20px;font-weight:800;margin-bottom:14px;">Dues & Razorpay Gateway</h2>`;
    h += `<div class="glass-card"><div style="font-size:11px;color:var(--text-muted);font-weight:700;">CURRENT OUTSTANDING DUE</div><div style="font-size:26px;font-weight:800;color:${user.outstandingDuesINR > 0 ? "var(--accent-rose)" : "var(--accent-emerald)"};margin-top:2px;">₹${user.outstandingDuesINR}</div><div style="font-size:11px;color:var(--text-muted);margin-top:4px;">Plan expires on ${user.planExpiry}</div>`;
    if (user.outstandingDuesINR > 0) {
      h += `<button class="btn btn-primary btn-block" style="margin-top:14px;" onclick="payDue(${user.outstandingDuesINR})"><span class="material-icons-round">lock</span> Pay ₹${user.outstandingDuesINR} via Razorpay Sandbox</button>`;
    } else {
      h += `<div style="margin-top:10px;color:var(--accent-emerald);font-size:12px;font-weight:600;">All dues cleared! No pending obligations.</div>`;
    }
    h += `</div>`;
    h += `<h3 style="font-size:14px;font-weight:700;margin:16px 0 10px;">Receipts & Payment History</h3>`;
    const tx = window.appStore.state.transactions.filter(function(t) { return t.memberId === user.id; });
    tx.forEach(function(t) {
      h += `<div class="glass-card" style="padding:12px;margin-bottom:8px;"><div style="display:flex;justify-content:space-between;align-items:center;"><div><div style="font-weight:700;">Receipt #${t.invoiceNumber}</div><div style="font-size:11px;color:var(--text-muted);">${new Date(t.date).toLocaleDateString()} • ${t.method}</div><div style="font-size:10px;color:var(--text-dim);">Ref: ${t.referenceNo}</div></div><div style="text-align:right;"><div style="font-weight:800;color:var(--accent-emerald);">₹${t.amountINR}</div><span class="badge badge-success" style="font-size:10px;">Paid</span></div></div></div>`;
    });
    c.innerHTML = h;
  }
}

function searchVault(q) {
  q = q.toLowerCase();
  const list = document.getElementById("vault-list");
  if (!list) return;
  const filtered = exercises.filter(function(e) { return e.name.toLowerCase().includes(q) || e.muscle.toLowerCase().includes(q); });
  let h = "";
  filtered.slice(0, 15).forEach(function(ex) {
    h += `<div class="glass-card" style="padding:12px;margin-bottom:8px;"><div style="display:flex;justify-content:space-between;"><div style="font-weight:700;">${ex.name}</div><span class="badge badge-info">${ex.muscle}</span></div><div style="font-size:11px;color:var(--text-muted);margin:4px 0;">${ex.instructions}</div><div style="font-size:11px;color:var(--accent-emerald);">Safety: ${ex.safety}</div></div>`;
  });
  list.innerHTML = h;
}

function bookClass(id, title) {
  const c = window.appStore.state.classes.find(function(i) { return i.id === id; });
  if (c && c.bookedCount < c.capacity) {
    c.bookedCount++;
    window.appStore.save();
    showToast("Seat reserved for " + title, "event_seat");
    render();
  } else {
    showToast("Class is fully booked!", "error", true);
  }
}

function payDue(amt) {
  const user = window.appStore.getCurrentUser();
  if (confirm("Razorpay Sandbox Gateway\n\nPay INR " + amt + " for Gym Membership?")) {
    window.appStore.recordPayment(user.id, amt, "membership_due_clearance", "Razorpay UPI (Sandbox Verified)");
    showToast("Payment of INR " + amt + " verified!", "check_circle");
    render();
  }
}

function renderTrainer(c, n) {
  n.innerHTML = `<div class="nav-item active"><span class="material-icons-round">sports</span><span>Clients</span></div><div class="nav-item" onclick="showToast('Schedule sync active', 'schedule')"><span class="material-icons-round">calendar_today</span><span>Classes</span></div><div class="nav-item" onclick="showToast('Trainer Compensation: ₹47,000 paid', 'payments')"><span class="material-icons-round">payments</span><span>Pay & PT</span></div>`;
  const trainer = window.appStore.getCurrentUser();
  const clients = window.appStore.getGymMembers().filter(function(m) { return m.assignedTrainerId === trainer.id; });
  let h = `<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:14px;"><div><h2 style="font-size:20px;font-weight:800;">Trainer Portal</h2><div style="font-size:12px;color:var(--text-muted);">${trainer.name} • ${trainer.speciality}</div></div><img src="${trainer.avatar}" style="width:42px;height:42px;border-radius:50%;object-fit:cover;"></div>`;
  h += `<div class="kpi-grid"><div class="kpi-card"><div class="kpi-label">Assigned Athletes</div><div class="kpi-val">${clients.length}</div></div><div class="kpi-card"><div class="kpi-label">This Month Pay</div><div class="kpi-val">₹47,000</div><div class="kpi-sub">Paid in full</div></div></div>`;
  h += `<h3 style="font-size:14px;font-weight:700;margin:16px 0 10px;">Assigned Athletes</h3>`;
  clients.forEach(function(cl) {
    h += `<div class="glass-card" style="padding:12px;margin-bottom:8px;"><div style="display:flex;justify-content:space-between;align-items:center;"><div style="display:flex;align-items:center;gap:10px;"><img src="${cl.avatar}" style="width:38px;height:38px;border-radius:50%;object-fit:cover;"><div><div style="font-weight:700;">${cl.name}</div><div style="font-size:11px;color:var(--accent-cyan);">${cl.fitnessGoal}</div></div></div><button class="btn btn-secondary btn-sm" onclick="showToast('Routine customized for ${cl.name}', 'edit_note')"><span class="material-icons-round" style="font-size:14px;">edit_note</span> Routine</button></div></div>`;
  });
  c.innerHTML = h;
}

function renderStaff(c, n) {
  n.innerHTML = `<div class="nav-item active"><span class="material-icons-round">fingerprint</span><span>Attendance</span></div><div class="nav-item" onclick="showToast('Shift sync verified', 'schedule')"><span class="material-icons-round">schedule</span><span>Shifts</span></div><div class="nav-item" onclick="showToast('Staff Salary: ₹22,000 paid', 'account_balance')"><span class="material-icons-round">account_balance</span><span>Salary</span></div>`;
  const staff = window.appStore.getCurrentUser();
  const gym = window.appStore.getActiveGym();
  const att = window.appStore.state.staffAttendance.filter(function(a) { return a.staffId === staff.id; });
  let h = `<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:14px;"><div><h2 style="font-size:20px;font-weight:800;">Staff Desk Portal</h2><div style="font-size:12px;color:var(--text-muted);">${staff.name} • ${staff.designation}</div></div><img src="${staff.avatar}" style="width:42px;height:42px;border-radius:50%;object-fit:cover;"></div>`;
  h += `<div class="glass-card" style="text-align:center;padding:20px;"><div style="font-size:15px;font-weight:800;">GPS Geofenced Clock-In</div><div style="font-size:12px;color:var(--text-muted);margin-top:4px;">Gym: Indiranagar (${gym.geofence.radiusMeters}m radius)</div><div class="radar-box"><div class="radar-pulse"></div><span class="material-icons-round" style="font-size:48px;color:var(--primary);">location_searching</span></div><div id="geofence-status" style="font-size:13px;font-weight:700;color:var(--text-muted);margin-bottom:14px;">Press to simulate native GPS check</div><div style="display:flex;gap:8px;"><button class="btn btn-primary btn-block" onclick="clockIn(true)"><span class="material-icons-round">login</span> Inside Gym</button><button class="btn btn-secondary btn-block" onclick="clockIn(false)"><span class="material-icons-round">block</span> Outside Bounds</button></div></div>`;
  h += `<h3 style="font-size:14px;font-weight:700;margin:16px 0 10px;">Attendance Sessions</h3>`;
  att.forEach(function(a) {
    h += `<div class="glass-card" style="padding:12px;margin-bottom:8px;"><div style="display:flex;justify-content:space-between;align-items:center;"><div><div style="font-weight:700;">${a.staffName}</div><div style="font-size:11px;color:var(--text-muted);">${a.clockInTime} • ${a.clockInDistanceMeters}m away</div></div><span class="badge ${a.isGeofenceVerified ? "badge-success" : "badge-danger"}">${a.isGeofenceVerified ? "GPS Verified" : "Rejected"}</span></div></div>`;
  });
  c.innerHTML = h;
}

function clockIn(inside) {
  const staff = window.appStore.getCurrentUser();
  const gym = window.appStore.getActiveGym();
  const coords = inside ? { latitude: gym.geofence.latitude + 0.0001, longitude: gym.geofence.longitude + 0.0001 } : { latitude: gym.geofence.latitude + 0.02, longitude: gym.geofence.longitude + 0.02 };
  const r = window.appStore.recordStaffAttendance(staff.id, coords);
  const status = document.getElementById("geofence-status");
  if (r.isVerified) {
    status.innerHTML = `<span style="color:var(--accent-emerald);">✓ GPS Lock Verified (${r.distanceMeters}m)</span>`;
    showToast("Attendance recorded with verified GPS lock!", "verified");
  } else {
    status.innerHTML = `<span style="color:var(--accent-rose);">✗ Rejected (${r.distanceMeters}m out-of-bounds)</span>`;
    showToast("Clock-in rejected: Outside boundary", "error", true);
  }
  setTimeout(render, 1500);
}

function renderPlatform(c, n) {
  n.innerHTML = `<div class="nav-item active"><span class="material-icons-round">hub</span><span>Gym Tenants</span></div><div class="nav-item" onclick="showToast('Play Billing Subscriptions healthy', 'verified')"><span class="material-icons-round">price_check</span><span>Play Billing</span></div>`;
  const gyms = window.appStore.state.gyms;
  let h = `<h2 style="font-size:20px;font-weight:800;margin-bottom:14px;">SaaS Platform Operator</h2>`;
  h += `<div class="kpi-grid"><div class="kpi-card"><div class="kpi-label">Total Gym Tenants</div><div class="kpi-val">${gyms.length}</div></div><div class="kpi-card"><div class="kpi-label">Monthly MRR</div><div class="kpi-val">₹${(gyms.length * 999).toLocaleString("en-IN")}</div></div></div>`;
  h += `<h3 style="font-size:14px;font-weight:700;margin:16px 0 10px;">Independent Gyms</h3>`;
  gyms.forEach(function(g) {
    h += `<div class="glass-card"><div style="display:flex;justify-content:space-between;"><div><div style="font-size:15px;font-weight:800;">${g.name}</div><div style="font-size:11px;color:var(--accent-cyan);">Tenant: ${g.id} • ₹${g.subscription.monthlyRateINR}/mo</div></div><span class="badge badge-success">Active SaaS</span></div></div>`;
  });
  c.innerHTML = h;
}

function openEnrollModal() {
  const modal = document.getElementById("app-modal");
  const sheet = document.getElementById("modal-sheet-content");
  let h = `<div class="modal-handle"></div><h3 style="font-size:18px;font-weight:800;margin-bottom:14px;">Enroll New Member</h3>`;
  h += `<div class="form-group"><label class="form-label">Full Name</label><input type="text" id="m-name" class="form-control" placeholder="e.g. Kavya Patel"></div>`;
  h += `<div class="form-group"><label class="form-label">Phone</label><input type="tel" id="m-phone" class="form-control" placeholder="+91 98XXX XXXXX"></div>`;
  h += `<button class="btn btn-primary btn-block" onclick="saveEnroll()"><span class="material-icons-round">check</span> Enroll & Generate Invoice</button>`;
  sheet.innerHTML = h;
  modal.classList.add("active");
}

function saveEnroll() {
  const name = document.getElementById("m-name").value;
  const phone = document.getElementById("m-phone").value;
  if (!name || !phone) return showToast("Please enter name and phone", "error", true);
  const newMember = {
    id: "USR-MEMBER-" + Date.now().toString().slice(-4),
    gymId: window.appStore.state.session.activeGymId,
    role: "member",
    name: name,
    phone: phone,
    avatar: "https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=150&q=80",
    membershipStatus: "active",
    planExpiry: "2027-10-19",
    outstandingDuesINR: 0,
    assignedTrainerId: "USR-TRAINER-01",
    fitnessGoal: "General Conditioning",
    streakCurrent: 1,
    streakBest: 1,
    monthlyVisits: 1
  };
  window.appStore.state.users.push(newMember);
  window.appStore.recordPayment(newMember.id, 14999, "membership_enrollment", "Razorpay UPI (Sandbox Verified)");
  window.appStore.save();
  closeModal();
  showToast("Member enrolled successfully!", "person_add");
  render();
}

function collectDues(id, amt) {
  if (confirm("Collect INR " + amt + " dues for this member?")) {
    window.appStore.recordPayment(id, amt, "dues_clearance", "Cash / POS Card Terminal");
    showToast("Dues collected and reconciled!", "check_circle");
    render();
  }
}

function openGeofenceModal() {
  const gym = window.appStore.getActiveGym();
  const modal = document.getElementById("app-modal");
  const sheet = document.getElementById("modal-sheet-content");
  let h = `<div class="modal-handle"></div><h3 style="font-size:18px;font-weight:800;margin-bottom:14px;">Gym GPS Geofence</h3>`;
  h += `<div class="form-group"><label class="form-label">Latitude</label><input type="number" step="0.0001" id="g-lat" class="form-control" value="${gym.geofence.latitude}"></div>`;
  h += `<div class="form-group"><label class="form-label">Longitude</label><input type="number" step="0.0001" id="g-lng" class="form-control" value="${gym.geofence.longitude}"></div>`;
  h += `<div class="form-group"><label class="form-label">Permitted Radius (Meters)</label><input type="number" id="g-rad" class="form-control" value="${gym.geofence.radiusMeters}"></div>`;
  h += `<button class="btn btn-primary btn-block" onclick="saveGeofence()"><span class="material-icons-round">save</span> Save</button>`;
  sheet.innerHTML = h;
  modal.classList.add("active");
}

function saveGeofence() {
  const gym = window.appStore.getActiveGym();
  gym.geofence.latitude = parseFloat(document.getElementById("g-lat").value);
  gym.geofence.longitude = parseFloat(document.getElementById("g-lng").value);
  gym.geofence.radiusMeters = parseInt(document.getElementById("g-rad").value, 10);
  window.appStore.save();
  closeModal();
  showToast("Geofence updated!", "fmd_good");
}

function downloadCsv() {
  const tx = window.appStore.state.transactions.filter(function(t) { return t.gymId === window.appStore.state.session.activeGymId; });
  let csv = "Invoice,Date,Amount_INR,Type,Method,Reference\n";
  tx.forEach(function(t) {
    csv += (t.invoiceNumber || t.id) + "," + t.date + "," + t.amountINR + "," + t.type + "," + t.method + "," + t.referenceNo + "\n";
  });
  const b = new Blob([csv], { type: "text/csv" });
  const a = document.createElement("a");
  a.href = URL.createObjectURL(b);
  a.download = "R3P_Finances.csv";
  a.click();
  showToast("CSV Export downloaded!", "file_download");
}
const getPFP = (r) => {
  try {
    return localStorage.getItem('r3p_pfp_' + r) || (window.P && P[r] && P[r].photo) || '';
  } catch(e) { return (window.P && P[r] && P[r].photo) || ''; }
};
const setPFP = (r, dataUrl) => {
  try {
    if(dataUrl) { localStorage.setItem('r3p_pfp_' + r, dataUrl); }
    else { localStorage.removeItem('r3p_pfp_' + r); }
  } catch(e) {}
  if(window.P && P[r]) P[r].photo = dataUrl;
  if(typeof draw === 'function') draw();
};

window.triggerProfilePic = function() {
  window.openPhotoPickerSheet();
};

window.openPhotoPickerSheet = function() {
  const currentPhoto = getPFP(role);
  sh = `
    <div class="photo-modal-card">
      <div class="photo-modal-header">
        <div>
          <h3 style="font-size:18px;font-weight:700;color:var(--text-main);margin-bottom:4px">Profile Photo</h3>
          <div class="mut" style="font-size:13px">Choose how you want to add your picture</div>
        </div>
        <button class="sheet-close-btn" onclick="shut()">${ic("close")}</button>
      </div>
      
      <div class="photo-modal-options">
        <button type="button" class="photo-opt-btn" onclick="captureFromCamera()">
          <div class="photo-opt-icon camera-bg">${ic("camera")}</div>
          <div class="photo-opt-info">
            <span class="photo-opt-title">Take Photo</span>
            <span class="photo-opt-desc">Open camera with Android & browser permission</span>
          </div>
          ${ic("chev")}
        </button>

        <button type="button" class="photo-opt-btn" onclick="chooseFromFileSystem()">
          <div class="photo-opt-icon upload-bg">${ic("upload")}</div>
          <div class="photo-opt-info">
            <span class="photo-opt-title">Upload from Device</span>
            <span class="photo-opt-desc">Browse files, gallery and storage</span>
          </div>
          ${ic("chev")}
        </button>

        ${currentPhoto ? `
        <button type="button" class="photo-opt-btn danger" onclick="removeProfilePhoto()">
          <div class="photo-opt-icon remove-bg">${ic("close")}</div>
          <div class="photo-opt-info">
            <span class="photo-opt-title" style="color:#f43f5e">Remove Current Photo</span>
            <span class="photo-opt-desc">Revert back to your name initials</span>
          </div>
        </button>` : ""}
      </div>

      <div style="margin-top:16px;text-align:center">
        <button type="button" class="btn ghost sm" style="width:100%" onclick="shut()">Cancel</button>
      </div>
    </div>
  `;
  draw();
};

window.captureFromCamera = function() {
  shut();
  setTimeout(() => {
    // Request permission & trigger camera capture
    if(navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
      navigator.mediaDevices.getUserMedia({ video: { facingMode: "user" } })
        .then(stream => {
          // Release camera track right away so standard file capture gets access
          stream.getTracks().forEach(track => track.stop());
          const camInp = document.getElementById("profile-camera-input");
          if(camInp) { camInp.value = ""; camInp.click(); }
        })
        .catch(err => {
          // Fallback directly to file picker with camera attribute
          const camInp = document.getElementById("profile-camera-input");
          if(camInp) { camInp.value = ""; camInp.click(); }
        });
    } else {
      const camInp = document.getElementById("profile-camera-input");
      if(camInp) { camInp.value = ""; camInp.click(); }
    }
  }, 120);
};

window.chooseFromFileSystem = function() {
  shut();
  setTimeout(() => {
    const fileInp = document.getElementById("profile-file-input");
    if(fileInp) { fileInp.value = ""; fileInp.click(); }
  }, 120);
};

window.removeProfilePhoto = function() {
  setPFP(role, "");
  shut();
  ts = "Profile picture removed";
  draw();
  setTimeout(() => { ts = ""; draw(); }, 2000);
};

window.handleProfilePicUpload = function(event) {
  const file = event.target.files && event.target.files[0];
  if(!file) return;
  const reader = new FileReader();
  reader.onload = function(e) {
    const dataUrl = e.target.result;
    setPFP(role, dataUrl);
    ts = "Profile picture updated!";
    draw();
    setTimeout(() => { ts = ""; draw(); }, 2500);
  };
  reader.readAsDataURL(file);
};

let currentTheme = localStorage.getItem("r3p_theme") || "dark";
document.body.setAttribute("data-theme", currentTheme);
function toggleTheme() {
  currentTheme = currentTheme === "dark" ? "light" : "dark";
  document.body.setAttribute("data-theme", currentTheme);
  localStorage.setItem("r3p_theme", currentTheme);
  if(role){draw();}else{login();}
}
window.toggleTheme = toggleTheme;

const $=s=>document.querySelector(s);
const ICN={sun:"M12 7c-2.76 0-5 2.24-5 5s2.24 5 5 5 5-2.24 5-5-2.24-5-5-5zM2 13h2c.55 0 1-.45 1-1s-.45-1-1-1H2c-.55 0-1 .45-1 1s.45 1 1 1zm18 0h2c.55 0 1-.45 1-1s-.45-1-1-1h-2c-.55 0-1 .45-1 1s.45 1 1 1zM11 2v2c0 .55.45 1 1 1s1-.45 1-1V2c0-.55-.45-1-1-1s-1 .45-1 1zm0 18v2c0 .55.45 1 1 1s1-.45 1-1v-2c0-.55-.45-1-1-1s-1 .45-1 1zM5.99 4.58c-.39-.39-1.03-.39-1.41 0s-.39 1.03 0 1.41l1.06 1.06c.39.39 1.03.39 1.41 0s.39-1.03 0-1.41L5.99 4.58zm12.37 12.37c-.39-.39-1.03-.39-1.41 0s-.39 1.03 0 1.41l1.06 1.06c.39.39 1.03.39 1.41 0s.39-1.03 0-1.41l-1.06-1.06zm1.06-10.96c.39-.39.39-1.03 0-1.41s-1.03-.39-1.41 0l-1.06 1.06c-.39.39-.39 1.03 0 1.41s1.03.39 1.41 0l1.06-1.06zM7.05 18.36c.39-.39.39-1.03 0-1.41s-1.03-.39-1.41 0l-1.06 1.06c-.39.39-.39 1.03 0 1.41s1.03.39 1.41 0l1.06-1.06z",moon:"M12.3 2a10 10 0 0 0-1.9 19.8 10 10 0 0 0 11.6-11.6A10 10 0 0 0 12.3 2z",home:"M10 20v-6h4v6h5v-8h3L12 3 2 12h3v8z",check:"M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z",cc:"M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z",card:"M20 4H4c-1.11 0-1.99.89-1.99 2L2 18c0 1.11.89 2 2 2h16c1.11 0 2-.89 2-2V6c0-1.11-.89-2-2-2zm0 14H4v-6h16v6zm0-10H4V6h16v2z",trend:"M16 6l2.29 2.29-4.88 4.88-4-4L2 16.59 3.41 18l6-6 4 4 6.3-6.29L22 12V6z",dots:"M6 10c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2zm12 0c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2zm-6 0c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2z",people:"M16 11c1.66 0 2.99-1.34 2.99-3S17.66 5 16 5c-1.66 0-3 1.34-3 3s1.34 3 3 3zm-8 0c1.66 0 2.99-1.34 2.99-3S9.66 5 8 5C6.34 5 5 6.34 5 8s1.34 3 3 3zm0 2c-2.33 0-7 1.17-7 3.5V19h14v-2.5c0-2.33-4.67-3.5-7-3.5zm8 0c-.29 0-.62.02-.97.05 1.16.84 1.97 1.97 1.97 3.45V19h6v-2.5c0-2.33-4.67-3.5-7-3.5z",fit:"M20.57 14.86L22 13.43 20.57 12 17 15.57 8.43 7 12 3.43 10.57 2 9.14 3.43 7.71 2 5.57 4.14 4.14 2.71 2.71 4.14l1.43 1.43L2 7.71l1.43 1.43L2 10.57 3.43 12 7 8.43 15.57 17 12 20.57 13.43 22l1.43-1.43L16.29 22l2.14-2.14 1.43 1.43 1.43-1.43-1.43-1.43L22 16.29z",event:"M17 12h-5v5h5v-5zM16 1v2H8V1H6v2H5c-1.11 0-1.99.9-1.99 2L3 19c0 1.1.89 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2h-1V1h-2zm3 18H5V8h14v11z",wallet:"M21 18v1c0 1.1-.9 2-2 2H5c-1.11 0-2-.9-2-2V5c0-1.1.89-2 2-2h14c1.1 0 2 .9 2 2v1h-9c-1.11 0-2 .9-2 2v8c0 1.1.89 2 2 2h9zm-9-2h10V8H12v8zm4-2.5c-.83 0-1.5-.67-1.5-1.5s.67-1.5 1.5-1.5 1.5.67 1.5 1.5-.67 1.5-1.5 1.5z",gear:"M19.14 12.94c.04-.3.06-.61.06-.94 0-.32-.02-.64-.07-.94l2.03-1.58c.18-.14.23-.41.12-.61l-1.92-3.32c-.12-.22-.37-.29-.59-.22l-2.39.96c-.5-.38-1.03-.7-1.62-.94l-.36-2.54c-.04-.24-.24-.41-.48-.41h-3.84c-.24 0-.43.17-.47.41l-.36 2.54c-.59.24-1.13.57-1.62.94l-2.39-.96c-.22-.08-.47 0-.59.22L2.74 8.87c-.12.21-.08.47.12.61l2.03 1.58c-.05.3-.09.63-.09.94s.02.64.07.94l-2.03 1.58c-.18.14-.23.41-.12.61l1.92 3.32c.12.22.37.29.59.22l2.39-.96c.5.38 1.03.7 1.62.94l.36 2.54c.05.24.24.41.48.41h3.84c.24 0 .44-.17.47-.41l.36-2.54c.59-.24 1.13-.56 1.62-.94l2.39.96c.22.08.47 0 .59-.22l1.92-3.32c.12-.22.07-.47-.12-.61l-2.01-1.58zM12 15.6c-1.98 0-3.6-1.62-3.6-3.6s1.62-3.6 3.6-3.6 3.6 1.62 3.6 3.6-1.62 3.6-3.6 3.6z",chart:"M5 9.2h3V19H5zM10.6 5h2.8v14h-2.8zm5.6 8H19v6h-2.8z",back:"M20 11H7.83l5.59-5.59L12 4l-8 8 8 8 1.41-1.41L7.83 13H20v-2z",add:"M19 13h-6v6h-2v-6H5v-2h6V5h2v6h6v2z",clock:"M11.99 2C6.47 2 2 6.48 2 12s4.47 10 9.99 10C17.52 22 22 17.52 22 12S17.52 2 11.99 2zM12 20c-4.42 0-8-3.58-8-8s3.58-8 8-8 8 3.58 8 8-3.58 8-8 8zm.5-13H11v6l5.25 3.15.75-1.23-4.5-2.67z",build:"M22.7 19l-9.1-9.1c.9-2.3.4-5-1.5-6.9-2-2-5-2.4-7.4-1.3L9 6 6 9 1.6 4.7C.4 7.1.9 10.1 2.9 12.1c1.9 1.9 4.6 2.4 6.9 1.5l9.1 9.1c.4.4 1 .4 1.4 0l2.3-2.3c.5-.4.5-1.1.1-1.4z",camp:"M18 11v2h4v-2h-4zm-2 6.61c.96.71 2.21 1.65 3.2 2.39.4-.53.8-1.07 1.2-1.6-.99-.74-2.24-1.68-3.2-2.4-.4.54-.8 1.08-1.2 1.61zM20.4 5.6c-.4-.53-.8-1.07-1.2-1.6-.99.74-2.24 1.68-3.2 2.4.4.53.8 1.07 1.2 1.6.96-.72 2.21-1.65 3.2-2.4zM4 9c-1.1 0-2 .9-2 2v2c0 1.1.9 2 2 2h1v4h2v-4h1l5 3V6L8 9H4zm11.5 3c0-1.33-.58-2.53-1.5-3.35v6.69c.92-.81 1.5-2.01 1.5-3.34z",qr:"M3 11h8V3H3v8zm2-6h4v4H5V5zM3 21h8v-8H3v8zm2-6h4v4H5v-4zM13 3v8h8V3h-8zm6 6h-4V5h4v4zM13 13h2v2h-2zM15 15h2v2h-2zM13 17h2v2h-2zM15 19h2v2h-2zM17 17h2v2h-2zM17 13h2v2h-2zM19 15h2v2h-2zM19 19h2v2h-2z",task:"M19 3h-4.18C14.4 1.84 13.3 1 12 1c-1.3 0-2.4.84-2.82 2H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm-7 0c.55 0 1 .45 1 1s-.45 1-1 1-1-.45-1-1 .45-1 1-1zm2 14H7v-2h7v2zm3-4H7v-2h10v2zm0-4H7V7h10v2z",pay:"M19 14V6c0-1.1-.9-2-2-2H3c-1.1 0-2 .9-2 2v8c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2zm-9-1c-1.66 0-3-1.34-3-3s1.34-3 3-3 3 1.34 3 3-1.34 3-3 3zm13-6v11c0 1.1-.9 2-2 2H4v-2h17V7h2z",person:"M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z",chev:"M10 6L8.59 7.41 13.17 12l-4.58 4.59L10 18l6-6z",upload:"M9 16h6v-6h4l-7-7-7 7h4zm-4 2h14v2H5z",folder:"M10 4H4c-1.1 0-1.99.9-1.99 2L2 18c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2h-8l-2-2z",close:"M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z",edit:"M3 17.25V21h3.75L17.81 9.94l-3.75-3.75L3 17.25zM20.71 7.04c.39-.39.39-1.02 0-1.41l-2.34-2.34c-.39-.39-1.02-.39-1.41 0l-1.83 1.83 3.75 3.75 1.83-1.83z",camera:"M12 15c1.66 0 3-1.34 3-3s-1.34-3-3-3-3 1.34-3 3 1.34 3 3 3zm0-8c.55 0 1 .45 1 1s-.45 1-1 1-1-.45-1-1 .45-1 1-1zm8 2h-3.17l-1.83-2H9L7.17 9H4c-1.1 0-2 .9-2 2v9c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2v-9c0-1.1-.9-2-2-2zm-8 11c-2.76 0-5-2.24-5-5s2.24-5 5-5 5 2.24 5 5-2.24 5-5 5zm9-1c0 .55-.45 1-1 1H4c-.55 0-1-.45-1-1v-9c0-.55.45-1 1-1h3.76l1.83-2h4.82l1.83 2H20c.55 0 1 .45 1 1v9z",wa:"M12.04 2c-5.46 0-9.91 4.45-9.91 9.91 0 1.75.46 3.45 1.32 4.95L2.05 22l5.25-1.38c1.45.79 3.08 1.21 4.74 1.21 5.46 0 9.91-4.45 9.91-9.91 0-2.65-1.03-5.14-2.9-7.01A9.816 9.816 0 0 0 12.04 2zm.01 1.67c2.2 0 4.26.86 5.82 2.42a8.19 8.19 0 0 1 2.41 5.83c0 4.54-3.7 8.24-8.24 8.24-1.42 0-2.81-.37-4.04-1.08l-.29-.17-3.01.79.8-2.93-.19-.3a8.16 8.16 0 0 1-1.25-4.29c0-4.54 3.7-8.24 8.24-8.24zm4.52 11.64c-.25.7-.72 1.29-1.37 1.63-.44.23-1.02.41-1.76.41-1.12 0-2.22-.38-3.34-1.15-1.13-.76-2.07-1.84-2.73-3.13-.39-.77-.59-1.55-.59-2.31 0-.83.27-1.54.78-2.06.27-.27.6-.42.94-.42.12 0 .24.03.35.08.26.11.75 1.28.82 1.42.06.13.1.28.02.44-.07.15-.17.31-.28.45l-.26.29c-.11.13-.23.27-.1.49.25.43.68.96 1.22 1.44.7.62 1.34.88 1.69 1.05.2.1.38.08.5-.06.15-.18.66-.77.83-.98.14-.17.31-.15.5-.07.2.08 1.27.6 1.49.71.22.11.37.16.42.26.06.09.06.53-.19 1.23z"};
const ic=n=>`<svg class="ic" viewBox="0 0 24 24"><path d="${ICN[n]}"/></svg>`;
let role="",tab="",sub=null,sid=0,seg="Members",ps="Collections",q="",cycle="Monthly",lr="adm",fresh=1,sh=null,pay=null,ts="",clocked=0,clockT="",flash=0;
const ini=n=>n.split(" ").map(w=>w[0]).join("").slice(0,2).toUpperCase();
const inr=n=>"₹"+Math.round(n).toLocaleString("en-IN");
const now=()=>new Date().toLocaleTimeString([],{hour:"numeric",minute:"2-digit"});
const today=()=>new Date().toLocaleDateString("en-IN",{day:"numeric",month:"short"});
const members=[["Aarav Mehta","Pro",1,1999,"+91 99221 33445"],["Diya Sharma","Elite",1,0,"+91 98220 54321"],["Rohan Patil","Basic",0,999,"+91 98901 12345"],["Sneha Iyer","Pro",1,0,"+91 97654 32109"],["Kabir Singh","Basic",0,999,"+91 98234 56789"],["Meera Nair","Elite",0,3499,"+91 99701 23456"],["Vikram Rao","Pro",1,0,"+91 98112 34567"],["Ananya Joshi","Basic",0,0,"+91 98990 12345"]].map(([n,p,i,due,phone],k)=>({n,p,i,t:i?"6:"+(10+k*7)+" AM":"",due,phone:phone||"+91 99221 33445"}));
const staff=[["Rahul Desai","Head Trainer",1,38500,"rahul@okhdfc"],["Priya Kulkarni","Yoga Instructor",1,32000,"priya.k@oksbi"],["Imran Shaikh","Front Desk",0,22000,"imran@ybl"],["Neha Bhat","Nutritionist",0,30000,"neha.b@paytm"],["Sameer Jadhav","Trainer",1,34000,"sameer@okicici"]].map(([n,p,i,sal,upi],k)=>({n,p,i,t:i?"8:00 AM":"",sal,upi,phone:"+91 98200 1"+(1000+k),paid:k==1?1:0,act:1}));
const txns=[{t:"Diya Sharma · Elite renewal",a:3499,d:"18 Oct",k:"in",m:"UPI"},{t:"Aarav Mehta · Sep membership",a:1999,d:"10 Sep",k:"in",m:"UPI"},{t:"Priya Kulkarni · salary",a:32000,d:"1 Oct",k:"out",m:"UPI"},{t:"Sneha Iyer · Pro renewal",a:1999,d:"12 Oct",k:"in",m:"Cash"}];
const plans=[{n:"Basic",p:999,f:["Gym floor access","Locker room","6am–10pm"]},{n:"Pro",p:1999,pop:1,f:["All Basic perks","Group classes","1 PT session / month"]},{n:"Elite",p:3499,f:["All Pro perks","Unlimited PT","Diet consultation"]}];
const cyc={Monthly:[1,1],Quarterly:[3,.9],Yearly:[12,.75]};
const exp=[["Rohan Patil","Basic",2],["Kabir Singh","Basic",4],["Meera Nair","Elite",6]];
const eq=[["Treadmill #3","Belt needs service",1],["Cable machine","Serviced 2 weeks ago",0],["Leg press","Serviced last month",0],["Spin bikes (x8)","All working",0]];
const ann=[["Diwali timings","Open 7am–2pm on 1 Nov"],["New Zumba batch","Starts Thursday 6pm"]];
const tasks=[["Wipe down cardio machines",0],["Restock towels",1],["Update locker key log",0],["Check treadmill #3 belt",0]];
const eclients=[["Aarav Mehta","Fat loss",72,0],["Diya Sharma","Strength",55,0],["Sneha Iyer","Mobility",38,1],["Vikram Rao","Muscle gain",64,0]];
const eclasses=[["HIIT","6:30 AM",18,20,0],["Strength Basics","9:00 AM",9,15,0],["Evening Burn","6:00 PM",14,20,0]];
const mclasses=[["Yoga Flow","Tue 7:00 AM","Priya K.",0],["HIIT Blast","Wed 6:30 AM","Rahul D.",1],["Zumba","Thu 6:00 PM","Neha B.",0],["Spin","Sat 8:00 AM","Sameer J.",0]];
const wk=[["Push day","Bench press 4×8 · Shoulder press 3×10 · Dips 3×12",0],["Pull day","Rows 4×8 · Lat pulldown 3×10 · Curls 3×12",1],["Leg day","Squats 4×8 · Lunges 3×12 · Leg press 3×10",0],["Core & cardio","Plank 3×60s · Bike 20 min · Leg raises 3×15",0]];
const P={adm:{name:"Amey Owner",email:"owner@r3p.fit",phone:"+91 98765 43210",gym:"R3P Fitness by KREW/MESH, Pune",hours:"6:00 AM – 10:00 PM",upi:"r3p@okaxis"},emp:{name:"Rahul Desai",email:"rahul@r3p.fit",phone:"+91 98220 45671",emg:"Anita Desai · +91 98220 11223",title:"Head Trainer",shift:"6:00 AM – 2:00 PM",skill:"Strength & conditioning"},mem:{name:"Aarav Mehta",email:"aarav@r3p.fit",phone:"+91 99221 33445",emg:"Sunita Mehta · +91 98900 22334",height:"176",weight:"74.6",goal:"Fat loss"}};
const FL={adm:[["Personal info",[["name","Full name"],["email","Email"],["phone","Phone"]]],["Gym & payments",[["gym","Gym name & city"],["hours","Opening hours"],["upi","Gym UPI ID (receives member payments)"]]]],emp:[["Personal info",[["name","Full name"],["email","Email"],["phone","Phone"],["emg","Emergency contact"]]],["Work",[["title","Designation"],["shift","Preferred shift"],["skill","Specialty"]]]],mem:[["Personal info",[["name","Full name"],["email","Email"],["phone","Phone"],["emg","Emergency contact"]]],["Fitness",[["height","Height (cm)"],["weight","Weight (kg)"],["goal","Primary goal"]]]]};
const NT={adm:[["Renewal alerts",1],["Daily revenue summary",1],["Low-attendance alerts",0],["Staff leave requests",1]],emp:[["Shift reminders",1],["Client session alerts",1],["Class roster changes",1],["Payslip ready",0]],mem:[["Class reminders",1],["Workout reminders",1],["Renewal reminders",1],["Offers & events",0]]};
const RL={adm:"Gym Owner · Admin",emp:"Employee",mem:"Member"};
/* helpers */
const homeTab = {adm:"home",emp:"today",mem:"home"};
const isRootHome = () => (!sub && tab === homeTab[role]);
const navHome = () => { sub=null; tab=homeTab[role]; fresh=1; draw(); };
const navBack = () => { if(sub){ sub=null; } else { tab=homeTab[role]; } fresh=1; draw(); };

const T=(t,s)=>{
  const showNav = !isRootHome();
  return `<header class="app-header">
    <div style="display:flex;align-items:center;gap:12px;flex:1;min-width:0">
      ${showNav ? `<button class="header-btn nav-back-btn" onclick="navBack()" title="Back to Home">${ic("back")}</button>` : ""}
      <div class="header-titles">
        <h1>${t}</h1>
        ${s?`<div class="mut">${s}</div>`:""}
      </div>
    </div>
    <div class="header-controls">
      ${showNav ? `<button class="header-btn" onclick="navHome()" title="Home">${ic("home")}</button>` : ""}
      <div class="av" style="cursor:pointer;overflow:hidden;background-size:cover;background-position:center;${role && getPFP(role)?`background-image:url('${getPFP(role)}');font-size:0;`:""}" onclick="op('Profile')" title="Account Profile">${(role && !getPFP(role))?ini(P[role].name):""}</div>
    </div>
  </header>`;
};
const kpi=(l,v,x="")=>`<div class="card"><div class="mut">${l}</div><div class="big ${x}">${v}</div></div>`;
const btn=(l,oc,c="")=>`<button class="btn sm ${c}" onclick="event.stopPropagation();${oc}">${l}</button>`;
const item=(t,s,r="",oc="")=>`<div class="card row" ${oc?`onclick="${oc}" style="cursor:pointer"`:""}><div style="min-width:0"><b>${t}</b><div class="mut">${s}</div></div>${r}</div>`;
const prog=(n,v)=>`<div class="row" style="margin:7px 0"><span style="width:56px">${n}</span><div class="bar" style="flex:1"><i style="width:${v}%"></i></div><b>${v}%</b></div>`;
const tg=(a,i,k)=>{a[i][k]=a[i][k]?0:1;draw()};
const toast=m=>{ts=m;draw();setTimeout(()=>{ts="";draw()},1700)};
const shut=()=>{sh=null;pay=null;draw()};
const lbl=(id,l,v,t="text")=>`<div class="mut" style="margin:0 0 4px 2px">${l}</div><input id="${id}" type="${t}" value="${v}">`;
const g=id=>$("#"+id).value.trim();
const qr=z=>{let s="";for(let y=0;y<9;y++)for(let x=0;x<9;x++)if((x*7+y*13+x*y)%3==0||(x<3&&y<3)||(x>5&&y<3)||(x<3&&y>5))s+=`<rect x="${x*10}" y="${y*10}" width="9" height="9" rx="2"/>`;return `<svg viewBox="0 0 90 90" width="${z}" fill="#111" style="background:#fff;border-radius:12px;padding:6px">${s}</svg>`};
function setArt(){const [a,b,s]={"":["#d4ff3a","#7dd3fc","#84cc16"],adm:["#d4ff3a","#a7f3d0","#84cc16"],emp:["#93c5fd","#c7d2fe","#3b82f6"],mem:["#fdba74","#fcd34d","#f97316"]}[role];const svg=`<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 430 600'><defs><radialGradient id='g1'><stop offset='0' stop-color='${a}' stop-opacity='.5'/><stop offset='1' stop-color='${a}' stop-opacity='0'/></radialGradient><radialGradient id='g2'><stop offset='0' stop-color='${b}' stop-opacity='.55'/><stop offset='1' stop-color='${b}' stop-opacity='0'/></radialGradient></defs><circle cx='400' cy='40' r='220' fill='url(#g1)'/><circle cx='20' cy='360' r='200' fill='url(#g2)'/><g transform='translate(335 170) rotate(-28)' fill='none' stroke='${s}' stroke-opacity='.25' stroke-width='5' stroke-linecap='round'><rect x='-70' y='-6' width='140' height='12' rx='6'/><rect x='-95' y='-30' width='20' height='60' rx='7'/><rect x='75' y='-30' width='20' height='60' rx='7'/></g></svg>`,h=`<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 300 160'><g fill='none' stroke='white' stroke-opacity='.22' stroke-width='6'><circle cx='255' cy='45' r='78'/><circle cx='255' cy='45' r='48'/></g></svg>`;const A=$("#app").style;A.setProperty("--art",`url("data:image/svg+xml,${encodeURIComponent(svg)}")`);A.setProperty("--hart",`url("data:image/svg+xml,${encodeURIComponent(h)}")`)}
/* UPI GATEWAY */
const APPS=[["GPay","#4285f4"],["PhonePe","#5f259f"],["Paytm","#00b9f1"],["BHIM","#f97316"]];
function payOpen(kind,i){let amt,to,nm;if(kind=="due"){amt=members[i].due;to=P.adm.upi;nm=P.adm.gym.split(",")[0]}else if(kind=="sal"){amt=staff[i].sal;to=staff[i].upi;nm=staff[i].n}else{const L=staff.filter(s=>s.act&&!s.paid);amt=L.reduce((a,s)=>a+s.sal,0);to="Bulk UPI payout";nm=L.length+" staff members"}pay={kind,i,amt,to,nm,step:1,app:"",err:0};draw()}
function payApp(a){pay.app=a;pay.step=2;draw()}
function payGo(){const v=$("#pin").value;if(v.length<4){pay.err=1;draw();return}pay.err=0;pay.step=3;draw();setTimeout(payDone,1200)}
function payDone(){const p=pay;if(!p)return;if(p.kind=="due"){txns.unshift({t:members[p.i].n+" · membership",a:p.amt,d:today(),k:"in",m:"UPI"});members[p.i].due=0}else if(p.kind=="sal"){txns.unshift({t:staff[p.i].n+" · salary",a:p.amt,d:today(),k:"out",m:"UPI"});staff[p.i].paid=1}else staff.filter(s=>s.act&&!s.paid).forEach(s=>{txns.unshift({t:s.n+" · salary",a:s.sal,d:today(),k:"out",m:"UPI"});s.paid=1});p.txn="UPI"+String(Date.now()).slice(-9);p.step=4;draw()}
function payHtml(){const p=pay;if(p.step==1)return `<div style="text-align:center"><div class="mut">${p.kind=="due"?"Paying":"Paying out"}</div><div class="big" style="font-size:34px">${inr(p.amt)}</div><div class="mut">to ${p.nm}${p.kind=="all"?"":" · "+p.to}</div></div><h2>Choose UPI app</h2><div class="grid">${APPS.map(([a,c])=>`<button class="app" onclick="payApp('${a}')"><i style="background:${c}">${a[0]}</i>${a}</button>`).join("")}</div><button class="btn ghost" style="margin-top:12px" onclick="shut()">Cancel</button>`;if(p.step==2)return `<h2 style="margin-top:0">Enter UPI PIN</h2><div class="mut" style="margin-bottom:10px">${p.app} · paying ${inr(p.amt)}</div><input id="pin" type="password" inputmode="numeric" maxlength="6" placeholder="••••">${p.err?'<div class="bad" style="margin:-4px 0 10px">Enter a 4–6 digit PIN</div>':""}<button class="btn" onclick="payGo()">Pay ${inr(p.amt)}</button><button class="btn ghost" style="margin-top:8px" onclick="pay.step=1;draw()">Back</button>`;if(p.step==3)return `<div style="text-align:center"><div class="spin"></div><b>Processing payment…</b><div class="mut">Do not close this screen</div></div>`;return `<div style="text-align:center"><div class="ok">${ic("check")}</div><h1>Payment successful</h1><div class="big" style="margin:6px 0">${inr(p.amt)}</div><div class="mut">to ${p.nm}</div><div class="card" style="margin:16px 0;text-align:left"><div class="row"><span class="mut">Transaction ID</span><b>${p.txn}</b></div><div class="row" style="margin-top:6px"><span class="mut">Paid via</span><b>${p.app}</b></div><div class="row" style="margin-top:6px"><span class="mut">Date</span><b>${today()}, ${now()}</b></div></div><button class="btn" onclick="shut()">Done</button></div>`}
/* LOGIN */
const ROLES={adm:["Admin","person","owner@r3p.fit"],emp:["Employee","fit","rahul@r3p.fit"],mem:["Member","cc","aarav@r3p.fit"]};
let authMode="login"; // "login" or "signup" or "splash"
function toggleAuthPass(){
  const inp = document.getElementById("pw");
  if(!inp) return;
  inp.type = inp.type === "password" ? "text" : "password";
}
function setAuthMode(m){
  authMode = m;
  login();
}
function pick(r){
  lr=r;
  const emInput = document.getElementById("em");
  if(emInput && ROLES[r]) emInput.value = ROLES[r][2];
  login();
}
function login(){
  role="";sub=null;pay=null;sh=null;
  const A = document.querySelector("#app");
  A.dataset.role="";
  setArt();
  A.className="fx auth-screen-active";
  
  const currentRole = ROLES[lr] || ROLES.adm;
  const roleEmail = currentRole[2];

  A.innerHTML = `
    <div class="clean-login-wrapper">
      <!-- Minimalist Top Navigation: Brand + Light/Dark Mode Switcher -->
      <div class="clean-login-topbar">
        <span class="clean-login-brand">R3P FITNESS</span>
        <button type="button" onclick="toggleTheme()" class="clean-theme-toggle" aria-label="Toggle theme">
          ${currentTheme === 'light' ? 
            `<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"></path></svg>` : 
            `<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="5"></circle><line x1="12" y1="1" x2="12" y2="3"></line><line x1="12" y1="21" x2="12" y2="23"></line><line x1="4.22" y1="4.22" x2="5.64" y2="5.64"></line><line x1="18.36" y1="18.36" x2="19.78" y2="19.78"></line><line x1="1" y1="12" x2="3" y2="12"></line><line x1="21" y1="12" x2="23" y2="12"></line><line x1="4.22" y1="19.78" x2="5.64" y2="18.36"></line><line x1="18.36" y1="5.64" x2="19.78" y2="4.22"></line></svg>`}
        </button>
      </div>
      <!-- Hero Image with Fade In from Bottom -->
      <div class="clean-login-hero-container">
        <img src="assets/login_hero.png" alt="R3P Athlete" class="clean-login-hero-img">
      </div>

      <!-- Stationary Brand Logo with Breathing Orange Element Glow -->
      <div class="clean-login-logo-wrap">
        <div class="r3p-composite-logo">
          <img src="assets/r3p_logo_base.png" class="r3p-base-layer" alt="R3P Letters">
          <img src="assets/r3p_logo_orange.png" class="r3p-orange-glow-layer" alt="R3P Orange '3'">
        </div>
      </div>

      <!-- Simplified Minimalist Clean Form Container -->
      <div class="clean-login-card">
        <!-- Role Quick Switcher Pills -->
        <div class="clean-role-pills">
          ${Object.entries(ROLES).map(([k,v])=>`
            <button type="button" onclick="pick('${k}')" class="clean-role-pill ${lr===k?'active':''}">
              ${v[0]}
            </button>
          `).join("")}
        </div>

        <form onsubmit="event.preventDefault();enter();" style="margin:0;width:100%">
          <div class="clean-field">
            <input id="em" class="clean-input" type="email" placeholder="Email address" value="${roleEmail}" required autocomplete="email">
          </div>

          <div class="clean-field" style="position:relative">
            <input id="pw" class="clean-input" type="password" placeholder="Password" value="password" required autocomplete="current-password">
            <button type="button" class="clean-eye-btn" onclick="toggleAuthPass()" aria-label="Toggle password visibility">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8z"></path>
                <circle cx="12" cy="12" r="3"></circle>
              </svg>
            </button>
          </div>

          <button type="submit" class="clean-submit-btn">
            Sign In
          </button>
        </form>
      </div>
    </div>
  `;
}
function enter(){role=lr||"adm";tab={adm:"home",emp:"today",mem:"home"}[role];sub=null;fresh=1;draw()}

/* ADMIN */
function aHome(){
  const ci=members.filter(m=>m.i).length,
        du=members.filter(m=>m.due),
        dt=du.reduce((a,m)=>a+m.due,0),
        sp=staff.filter(s=>s.act&&!s.paid).reduce((a,s)=>a+s.sal,0),
        totalMem=312,
        capacityPct=Math.round((ci/50)*100);

  const hrs=[["6a",35],["8a",85],["10a",60],["12p",30],["5p",80],["7p",98],["9p",45]];
  const maxH=Math.max(...hrs.map(h=>h[1]));
  
  return T("Hello, "+P.adm.name.split(" ")[0],"Gym Overview & Operations")+
    `<div class="hero">
      <div class="row" style="justify-content:space-between;align-items:flex-start">
        <div>
          <div class="mut" style="font-size:12px;text-transform:uppercase;letter-spacing:0.05em">Live Floor Occupancy</div>
          <div class="big" style="font-size:26px;margin:2px 0">${ci} <span style="font-size:15px;font-weight:500;opacity:0.8">training now</span></div>
        </div>
        <div style="text-align:right">
          <span class="live-pill"><span class="live-indicator-dot"></span>Live Active</span>
          <div class="mut" style="font-size:11px;margin-top:4px">Max 50 peak cap</div>
        </div>
      </div>
      <div class="bar" style="height:8px;margin:12px 0 6px;background:rgba(255,255,255,0.12)">
        <i style="width:${Math.min(100, capacityPct)}%;background:var(--ac);border-radius:4px"></i>
      </div>
      <div class="row mut" style="font-size:12px;margin-top:4px">
        <span><b>${capacityPct}%</b> floor capacity</span>
        <span><b>${totalMem}</b> registered members</span>
      </div>
    </div>

    <div class="grid">
      ${kpi("Dues Pending",inr(dt),dt?"warn":"")}
      ${kpi("Salaries Due",inr(sp),sp?"warn":"")}
    </div>

    <h2>Live Activity & Peak Trend</h2>
    <div class="card" style="padding:14px 14px 10px;cursor:pointer" onclick="op('Insights')">
      <div class="row" style="margin-bottom:12px">
        <div>
          <b style="font-size:13px">Hourly Footfall Curve</b>
          <div class="mut" style="font-size:11px">Peak time today: 7:00 PM – 8:30 PM</div>
        </div>
        <span class="pill" style="font-size:11px">Insights ${ic("chev")}</span>
      </div>
      <div style="display:flex;align-items:flex-end;gap:8px;height:70px;padding-top:4px">
        ${hrs.map(([h,v])=>{
          const isPeak=v>=85;
          const bg=isPeak?"var(--ac)":"var(--hl)";
          return `<div style="flex:1;text-align:center;display:flex;flex-direction:column;align-items:center;height:100%;justify-content:flex-end">
            <div style="width:100%;max-width:18px;height:${Math.round((v/maxH)*54)}px;background:${bg};border-radius:4px 4px 2px 2px;transition:var(--transition);opacity:${isPeak?1:0.75}"></div>
            <div class="mut" style="font-size:10px;margin-top:4px;font-weight:${isPeak?'700':'400'}">${h}</div>
          </div>`;
        }).join("")}
      </div>
    </div>

    <h2>Operational Status</h2>
    <div class="grid">
      <div class="card" style="margin:0;cursor:pointer" onclick="op('Equipment')">
        <div class="row">
          <div>
            <div class="mut" style="font-size:11px">Equipment</div>
            <b style="font-size:15px">${eq.filter(e=>!e[2]).length}/${eq.length} OK</b>
          </div>
          <div style="color:${eq.filter(e=>e[2]).length?'var(--warn)':'var(--ok)'}">${ic('build')}</div>
        </div>
        <div class="mut" style="font-size:11px;margin-top:6px">${eq.filter(e=>e[2]).length?eq.filter(e=>e[2]).length+' service pending':'All machines active'}</div>
      </div>
      <div class="card" style="margin:0;cursor:pointer" onclick="go('staff')">
        <div class="row">
          <div>
            <div class="mut" style="font-size:11px">On-duty Staff</div>
            <b style="font-size:15px">${staff.filter(s=>s.i).length} on floor</b>
          </div>
          <div style="color:var(--ac)">${ic('people')}</div>
        </div>
        <div class="mut" style="font-size:11px;margin-top:6px">${staff.filter(s=>s.act).length} active team members</div>
      </div>
    </div>

    <h2>Upcoming Group Classes</h2>
    <div class="card" style="padding:8px 14px;cursor:pointer" onclick="op('Classes')">
      ${[
        ["HIIT Blast","Today 6:30 PM","Rahul D.","18/20","Booked"],
        ["Power Yoga","Tomorrow 7:00 AM","Priya K.","12/15","Available"]
      ].map(([c,tm,tr,bk,st],idx)=>`
        <div class="row" style="padding:8px 0;${idx>0?'border-top:1px solid var(--ln)':''}">
          <div>
            <b style="font-size:13px">${c}</b>
            <div class="mut" style="font-size:11px">${tm} · ${tr}</div>
          </div>
          <div style="text-align:right">
            <span class="pill ${st=='Booked'?'in':''}">${bk}</span>
          </div>
        </div>
      `).join("")}
    </div>

    <h2>Action Required</h2>
    ${item(exp.length+" memberships expiring","Renew before memberships lapse",ic("chev"),"op('Subs')")}
    ${item(du.length+" pending dues",inr(dt)+" outstanding to collect",ic("chev"),"go('pay')")}
    ${item("Equipment service notice",eq.filter(e=>e[2]).length+" machine needs maintenance",ic("chev"),"op('Equipment')")}
  `;
}
function aAtt(){const A=seg=="Members"?members:staff,L=A.filter(x=>x.n.toLowerCase().includes(q.toLowerCase())),ci=L.filter(x=>x.i).length;return T("Attendance",new Date().toDateString())+`<div class="seg">${["Members","Employees"].map(s=>`<button class="${seg==s?"on":""}" onclick="seg='${s}';q='';draw()">${s}</button>`).join("")}</div><input placeholder="Search ${seg.toLowerCase()}…" value="${q}" oninput="q=this.value;lst()"><div class="row mut" style="margin:4px 4px 14px;font-weight:600"><span>● ${ci} currently checked in</span><span>${L.length-ci} outside</span></div><div id="lst">${rows(L)}</div>`}
function rows(L){const A=seg=="Members"?members:staff;return L.map(x=>`<div class="card row"><div class="row" style="justify-content:flex-start"><div class="av">${ini(x.n)}</div><div><b>${x.n}</b><div class="mut">${x.p}${x.i?` · <span class="in">In ${x.t}</span>`:""}</div></div></div>${btn(x.i?"Check out":"Check in","tog("+A.indexOf(x)+")",x.i?"ghost":"")}</div>`).join("")||`<p class="mut" style="text-align:center">No results</p>`}
function lst(){const A=seg=="Members"?members:staff;$("#lst").innerHTML=rows(A.filter(x=>x.n.toLowerCase().includes(q.toLowerCase())))}
function tog(i){
  const isMem = seg == "Members";
  const list = isMem ? members : staff;
  const x = list[i];
  if(!x) return;
  x.i = x.i ? 0 : 1;
  x.t = x.i ? now() : "";
  draw();
  // Live Cloud Synchronization with Supabase
  if(window.R3PSupabase && window.R3PSupabase.client) {
    if(isMem) {
      window.R3PSupabase.client.from("members")
        .update({ is_checked_in: !!x.i, checked_in_at: x.t, updated_at: new Date().toISOString() })
        .eq("name", x.n)
        .then(({error}) => {
          if(error) console.warn("[Supabase Sync] Member check-in update error:", error);
          else console.log("[Supabase Sync] Member check-in updated in cloud:", x.n, x.i);
        });
    } else {
      window.R3PSupabase.client.from("staff")
        .update({ is_clocked_in: !!x.i, clocked_in_at: x.t })
        .eq("name", x.n)
        .then(({error}) => {
          if(error) console.warn("[Supabase Sync] Staff check-in update error:", error);
          else console.log("[Supabase Sync] Staff check-in updated in cloud:", x.n, x.i);
        });
    }
  }
}
function aPay(){const col=txns.filter(t=>t.k=="in").reduce((a,t)=>a+t.a,0),du=members.map((m,i)=>[m,i]).filter(([m])=>m.due),pend=staff.filter(s=>s.act&&!s.paid);let c;if(ps=="Collections")c=du.map(([m,i])=>item(m.n,m.p+" plan · due "+inr(m.due),btn(ic("wa")+" Remind","openWaReminder("+i+")","ghost")+btn("Cash","cash("+i+")","ghost"))).join("")||`<p class="mut" style="text-align:center;padding:20px">All dues are cleared</p>`;else if(ps=="Payroll")c=(pend.length?`<div class="card row"><div><b>${inr(pend.reduce((a,s)=>a+s.sal,0))}</b><div class="mut">${pend.length} salaries pending</div></div>${btn("Pay all via UPI","payOpen('all',0)")}</div>`:"")+staff.map((s,i)=>s.act?item(s.n,s.p+" · "+inr(s.sal)+"<br>"+s.upi,s.paid?'<span class="pill in">Paid</span>':btn("Pay via UPI","payOpen('sal',"+i+")")):"").join("");else c=txns.map(t=>item(t.t,t.d+" · "+t.m,`<b class="${t.k=="in"?"in":""}">${t.k=="in"?"+":"−"}${inr(t.a)}</b>`)).join("");return T("Payments","Collections, payroll & history")+`<div class="grid">${kpi("Collected",inr(col))}${kpi("Dues pending",inr(du.reduce((a,[m])=>a+m.due,0)),"warn")}</div><div class="seg">${["Collections","Payroll","History"].map(s=>`<button class="${ps==s?"on":""}" onclick="ps='${s}';draw()">${s}</button>`).join("")}</div>`+c}
function cash(i){txns.unshift({t:members[i].n+" · membership",a:members[i].due,d:today(),k:"in",m:"Cash"});members[i].due=0;toast("Marked as paid in cash")}
function aStaff(){return T("Staff",staff.filter(s=>s.act).length+" active")+`<button class="btn" style="margin-bottom:14px" onclick="staffForm(-1)">${ic("add")} Add staff member</button>`+staff.map((s,i)=>item(s.n,s.p+" · "+inr(s.sal)+"/mo",s.act?(s.paid?'<span class="pill in">Paid</span>':'<span class="pill warn">Salary due</span>'):'<span class="pill">Inactive</span>',"openStaff("+i+")")).join("")}
function openStaff(i){sid=i;sub="StaffD";fresh=1;draw()}
function staffD(){const s=staff[sid];return `<div class="card" style="text-align:center;padding:20px"><div class="av" style="width:70px;height:70px;font-size:24px;margin:0 auto 8px">${ini(s.n)}</div><b style="font-size:18px">${s.n}</b><div class="mut">${s.p}</div></div>${item("Phone",s.phone)}${item("UPI ID",s.upi||"—")}${item("Monthly salary",inr(s.sal),s.paid?'<span class="pill in">Paid</span>':'<span class="pill warn">Due</span>')}${item("Today",s.i?"Checked in "+s.t:"Not checked in")}<div class="grid" style="margin-top:6px"><button class="btn ghost" onclick="staffForm(${sid})">Edit details</button><button class="btn ghost" onclick="staff[sid].act=staff[sid].act?0:1;toast(staff[sid].act?'Staff activated':'Staff deactivated')">${s.act?"Deactivate":"Activate"}</button></div>${!s.paid&&s.act?`<button class="btn" style="margin-top:10px" onclick="payOpen('sal',${sid})">Pay ${inr(s.sal)} via UPI</button>`:""}`}
function staffForm(i){const s=i<0?{n:"",p:"",phone:"",upi:"",sal:""}:staff[i];sh=`<h2 style="margin-top:0">${i<0?"Add staff":"Edit staff"}</h2>${lbl("sn","Full name",s.n)}${lbl("sr","Role",s.p)}${lbl("sp","Phone",s.phone)}${lbl("su","UPI ID",s.upi)}${lbl("ss","Monthly salary (₹)",s.sal,"number")}<button class="btn" onclick="staffSave(${i})">Save</button><button class="btn ghost" style="margin-top:8px" onclick="shut()">Cancel</button>`;draw()}
function staffSave(i){const n=g("sn");if(!n){toast("Name is required");return}const d={n,p:g("sr")||"Staff",phone:g("sp"),upi:g("su"),sal:+g("ss")||0};if(i<0)staff.push({...d,i:0,t:"",paid:0,act:1});else Object.assign(staff[i],d);sh=null;toast(i<0?"Staff added":"Staff updated")}
function aMore(){
  const sections = [
    {
      group: "Business & Growth",
      items: [
        ["card", "Membership Plans", "Configure pricing & tiers", "Plans"],
        ["trend", "Subscriptions & Health", "Active members, churn & renewals", "Subs"],
        ["chart", "Analytics & Insights", "Footfall curve & class fill rates", "Insights"]
      ]
    },
    {
      group: "Operations & Facilities",
      items: [
        ["people", "Member Directory", "312 total registered athletes", "Members"],
        ["event", "Class Schedules", "Bookings, trainer rosters & capacity", "Classes"],
        ["build", "Equipment Service", "Maintenance log & machine health", "Equipment"]
      ]
    },
    {
      group: "Communication & Settings",
      items: [
        ["camp", "Announcements", "Post notices to member app", "Announcements"],
        ["gear", "Profile & Settings", "Account, hours & appearance theme", "Profile"]
      ]
    }
  ];

  return T("More", "Gym Management Suite") + `
    <div style="display:flex;flex-direction:column;gap:18px;margin-top:6px">
      ${sections.map(sec => `
        <div>
          <div class="mut" style="font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:0.05em;margin:0 0 8px 4px">${sec.group}</div>
          <div class="card" style="padding:4px 0;margin:0;overflow:hidden">
            ${sec.items.map(([icon, title, desc, target], idx) => `
              <div class="row v-menu-item" onclick="op('${target}')" style="padding:14px 18px;cursor:pointer;border-top:${idx>0?'1px solid var(--ln)':'none'};transition:var(--transition)">
                <div style="display:flex;align-items:center;gap:14px">
                  <div class="v-menu-icon" style="width:38px;height:38px;border-radius:12px;background:var(--card-subtle);display:grid;place-items:center;flex-shrink:0">
                    ${ic(icon)}
                  </div>
                  <div>
                    <b style="font-size:14px;color:var(--text-titles);display:block;line-height:1.2">${title}</b>
                    <div class="mut" style="font-size:12px;margin-top:2px">${desc}</div>
                  </div>
                </div>
                <div style="color:var(--mut);display:flex;align-items:center;opacity:0.7">
                  ${ic("chev")}
                </div>
              </div>
            `).join("")}
          </div>
        </div>
      `).join("")}
    </div>
  `;
}
function aPlans(){const[m,d]=cyc[cycle];return T("Plans & pricing","Membership plans")+`<div class="seg">${Object.keys(cyc).map(c=>`<button class="${cycle==c?"on":""}" onclick="cycle='${c}';draw()">${c}</button>`).join("")}</div>`+plans.map((p,i)=>`<div class="card"><div class="row"><b style="font-size:17px">${p.n}${p.pop?' <span class="pill">Popular</span>':""}</b><div><span class="big">${inr(p.p*m*d)}</span><span class="mut">/${m==1?"mo":m==3?"qtr":"yr"}</span></div></div>${d<1?`<div class="mut">Save ${Math.round((1-d)*100)}% vs monthly</div>`:""}<div class="mut" style="margin:8px 0">${p.f.join(" · ")}</div>${btn("Edit plan","planForm("+i+")","ghost")}</div>`).join("")+`<button class="btn" onclick="planForm(-1)">${ic("add")} New plan</button>`}
function planForm(i){const p=i<0?{n:"",p:""}:plans[i];sh=`<h2 style="margin-top:0">${i<0?"New plan":"Edit plan"}</h2>${lbl("pn","Plan name",p.n)}${lbl("pp","Monthly price (₹)",p.p,"number")}<button class="btn" onclick="planSave(${i})">Save</button><button class="btn ghost" style="margin-top:8px" onclick="shut()">Cancel</button>`;draw()}
function planSave(i){const n=g("pn"),pr=+g("pp");if(!n||!pr){toast("Enter name and price");return}if(i<0)plans.push({n,p:pr,f:["Gym floor access"]});else{plans[i].n=n;plans[i].p=pr}sh=null;toast("Plan saved")}
function aSubs(){const r=[2.8,3.1,3.4,3.7,3.9,4.2],mo=["May","Jun","Jul","Aug","Sep","Oct"];return T("Subscriptions","Membership health")+`<div class="grid">${kpi("Active","312")}${kpi("MRR","₹4.2L")}${kpi("Churn","3.1%")}${kpi("Expiring",exp.length,"warn")}</div><h2>Revenue (₹ lakh)</h2><div class="card"><svg viewBox="0 0 300 130" width="100%">${r.map((v,i)=>{const h=v/4.5*90;return `<rect x="${i*50+10}" y="${100-h}" width="30" height="${h}" rx="7" fill="${i==5?"#111":"#e5e7eb"}"/><text x="${i*50+25}" y="118" text-anchor="middle" font-size="10" fill="#7b8088">${mo[i]}</text><text x="${i*50+25}" y="${94-h}" text-anchor="middle" font-size="10" fill="#111">${v}</text>`}).join("")}</svg></div><h2>Plan split</h2><div class="card">${prog("Basic",42)}${prog("Pro",38)}${prog("Elite",20)}</div><h2>Expiring soon</h2>`+(exp.map((e,i)=>item(e[0],e[1]+" · ends in "+e[2]+" days",btn("Renew","renewSub("+i+")"))).join("")||`<p class="mut">No upcoming expiries</p>`)}
function renewSub(i){const e=exp[i],p=plans.find(x=>x.n==e[1])||plans[0];txns.unshift({t:e[0]+" · "+e[1]+" renewal",a:p.p,d:today(),k:"in",m:"Cash"});exp.splice(i,1);toast("Membership renewed")}
function aIns(){
  const hrs=[["6a",40],["8a",85],["12p",35],["5p",75],["7p",100],["9p",45]];
  return T("Insights","Gym performance")+`
    <h2 style="margin-top:0">Peak hours</h2>
    <div class="card" style="display:flex;align-items:flex-end;gap:8px;height:120px;padding:16px 14px">
      ${hrs.map(([h,v])=>{
        const isPeak = v >= 80;
        const barBg = isPeak ? "var(--ac)" : "var(--card-subtle)";
        return `<div style="flex:1;text-align:center;display:flex;flex-direction:column;align-items:center;height:100%;justify-content:flex-end">
          <div style="width:100%;max-width:22px;height:${v*.8}px;background:${barBg};border-radius:6px;opacity:${isPeak?1:0.75}"></div>
          <div class="mut" style="font-size:11px;margin-top:6px;font-weight:${isPeak?'700':'500'}">${h}</div>
        </div>`;
      }).join("")}
    </div>
    <h2>Class fill rate</h2>
    <div class="card">${prog("HIIT",92)}${prog("Yoga",78)}${prog("Zumba",64)}${prog("Spin",55)}</div>
    <h2>Trainer leaderboard</h2>
    ${[["Rahul Desai","48 PT sessions"],["Sameer Jadhav","41 PT sessions"],["Priya Kulkarni","36 classes"]].map(([n,s],i)=>item(n,s,`<span class="pill in">4.${9-i} ★</span>`)).join("")}
    <h2>Growth</h2>
    <div class="grid">${kpi("90-day retention","76%")}${kpi("New joins (Oct)","41")}</div>
  `;
}
function aMem(){return T("Members","312 total")+members.map((m,i)=>item(m.n,m.p+" plan · "+m.phone,`<div style="display:flex;align-items:center;gap:6px">${m.due?`<span class="pill warn">Due ${inr(m.due)}</span>`:'<span class="pill in">Paid</span>'}<button class="header-btn" style="width:34px;height:34px;color:#25D366" onclick="event.stopPropagation();openWaReminder(${i})" title="Send WhatsApp">${ic("wa")}</button></div>`,"openWaReminder("+i+")")).join("")}
function aCls(){return T("Classes","This week")+[["HIIT · Mon 6:30 AM","Rahul D. · 18/20 booked"],["Yoga Flow · Tue 7:00 AM","Priya K. · 12/15 booked"],["Zumba · Thu 6:00 PM","Neha B. · 16/25 booked"],["Spin · Sat 8:00 AM","Sameer J. · 10/12 booked"]].map(([t,s])=>item(t,s)).join("")}
function aEq(){return T("Equipment","Maintenance")+eq.map((e,i)=>item(e[0],e[1],e[2]?btn("Mark fixed","eq["+i+"][2]=0;eq["+i+"][1]='Serviced today';toast('Marked as fixed')"):'<span class="pill in">OK</span>')).join("")}
function aAnn(){return T("Announcements","Visible to members")+`<button class="btn" style="margin-bottom:14px" onclick="annForm()">${ic("add")} New announcement</button>`+ann.map(a=>item(a[0],a[1])).join("")}
function annForm(){sh=`<h2 style="margin-top:0">New announcement</h2>${lbl("at","Title","")}${lbl("ab","Message","")}<button class="btn" onclick="annSave()">Post</button><button class="btn ghost" style="margin-top:8px" onclick="shut()">Cancel</button>`;draw()}
function annSave(){const t=g("at");if(!t){toast("Add a title");return}ann.unshift([t,g("ab")||"—"]);sh=null;toast("Announcement posted")}
/* WHATSAPP REMINDER INTEGRATION */
function openWaReminder(i){
  const m = members[i];
  if(!m) return;
  const gymName = (P.adm.gym.split(",")[0]) || "R3P Fitness";
  const defaultMsg = m.due 
    ? ("Hi " + m.n + ", friendly reminder from " + gymName + ": your " + m.p + " membership payment of " + inr(m.due) + " is currently due. You can pay via UPI to " + P.adm.upi + " or visit the front desk. Thank you!")
    : ("Hi " + m.n + ", this is " + gymName + "! We missed you on the gym floor. Check out our latest workouts and group classes this week!");

  sh = `
    <div style="display:flex;justify-content:space-between;align-items:flex-start;margin-bottom:14px">
      <div>
        <div class="pill in" style="font-size:11px;margin-bottom:6px;gap:6px">
          ${ic("wa")} WhatsApp Reminder
        </div>
        <h2 style="margin:4px 0 2px">Message ${m.n}</h2>
        <div class="mut">${m.p} plan · ${m.phone}</div>
      </div>
      <button class="header-btn" onclick="shut()">${ic("back")}</button>
    </div>

    <div class="card" style="margin-bottom:14px">
      <div class="mut" style="font-size:12px;margin-bottom:6px;font-weight:600">Member Status</div>
      <div class="row">
        <div>
          <b>${m.due ? `<span style="color:var(--apple-amber, #ff9500)">Payment Due: `+inr(m.due)+`</span>` : `<span style="color:var(--apple-exercise, #a1ff00)">Membership Active</span>`}</b>
          <div class="mut" style="font-size:12px;margin-top:2px">Recipient: ${m.phone}</div>
        </div>
        <div class="av">${ini(m.n)}</div>
      </div>
    </div>

    <div style="margin-bottom:16px">
      <div class="mut" style="font-size:12px;font-weight:600;margin:0 0 6px 2px">Message Preview (Editable)</div>
      <textarea id="waMsg" style="width:100%;height:105px;border-radius:14px;padding:12px 14px;font-family:inherit;font-size:13px;line-height:1.45;resize:none;border:1px solid var(--ln);background:var(--card-subtle);color:inherit;outline:none">${defaultMsg}</textarea>
    </div>

    <div style="display:flex;flex-direction:column;gap:8px">
      <button class="btn" style="background:#25D366;color:#ffffff;display:flex;align-items:center;justify-content:center;gap:8px" onclick="sendWa('${m.phone}')">
        ${ic("wa")} Send via WhatsApp
      </button>
      <button class="btn ghost" onclick="shut()">Cancel</button>
    </div>
  `;
  draw();
}

function sendWa(phone){
  const msgEl = $("#waMsg");
  const text = msgEl ? msgEl.value : "";
  const cleanPhone = phone.replace(/[^0-9]/g, "");
  const url = "https://wa.me/" + cleanPhone + "?text=" + encodeURIComponent(text);
  window.open(url, "_blank");
  shut();
  toast("Opening WhatsApp...");
}

/* EMPLOYEE */
function eToday(){const done=eclients.filter(c=>c[3]).length;return T("Dashboard","Trainer Shift")+`<div class="hero"><div class="mut" style="margin-bottom:4px">Good morning</div><h1 style="font-size:26px;margin:2px 0 6px 0;line-height:1.2">${P.emp.name}</h1><div class="mut" style="line-height:1.4">${P.emp.title} · ${P.emp.shift}</div><button class="btn" style="margin-top:20px !important" onclick="clocked=clocked?0:1;clockT=now();draw()">${ic("clock")} ${clocked?"Clock out":"Clock in"}</button>${clocked?`<div class="mut" style="margin-top:8px;text-align:center">Clocked in at ${clockT}</div>`:""}</div><div class="grid">${kpi("Sessions today",done+"/"+eclients.length)}${kpi("Hours this week","31.5")}</div><h2>Today's schedule</h2>${eclasses.map(c=>item(c[0],c[1]+" · "+c[2]+" attending",`<span class="pill">${c[3]} cap</span>`)).join("")}`}
function eClients(){return T("My clients","Assigned training")+eclients.map((c,i)=>`<div class="card"><div class="row"><div><b>${c[0]}</b><div class="mut">Goal: ${c[1]}</div></div>${btn(c[3]?"Logged":"Log session","tg(eclients,"+i+",3)",c[3]?"ghost":"")}</div>${prog("Goal",c[2])}</div>`).join("")}
function eClasses(){return T("Classes","Take roll")+eclasses.map((c,i)=>item(c[0],c[1]+" · "+c[2]+"/"+c[3]+" booked",btn(c[4]?"Done":"Take roll","tg(eclasses,"+i+",4)",c[4]?"ghost":""))).join("")}
function eTasks(){const d=tasks.filter(t=>t[1]).length;return T("Tasks",d+" of "+tasks.length+" done")+`<div class="bar" style="margin:0 0 16px"><i style="width:${d/tasks.length*100}%"></i></div>`+tasks.map((t,i)=>`<div class="card row" onclick="tg(tasks,${i},1)" style="cursor:pointer"><b style="${t[1]?"text-decoration:line-through;opacity:.5":""}">${t[0]}</b><div class="chk ${t[1]?"d":""}">${t[1]?ic("check"):""}</div></div>`).join("")}
function eSal(){const s=staff[0],my=txns.filter(t=>t.k=="out"&&t.t.startsWith("Rahul"));return T("Salary","October 2026")+`<div class="hero"><div class="mut">Monthly salary</div><div class="big">${inr(s.sal)}</div><div class="mut">${s.paid?"Credited via UPI to "+s.upi:"Pending · will be credited to "+s.upi}</div></div><div class="grid">${kpi("Status",s.paid?"Paid":"Pending",s.paid?"in":"warn")}${kpi("Leave balance","9 days")}</div><h2>Payslips</h2>${my.map(t=>item(t.d,"Transaction via "+t.m,`<b>${inr(t.a)}</b>`)).join("")||`<p class="mut">No payslips yet this month</p>`}<button class="btn" style="margin-top:10px" onclick="leaveForm()">Request leave</button>`}
function leaveForm(){sh=`<h2 style="margin-top:0">Request leave</h2>${lbl("ld","From date","","date")}${lbl("lr","Reason","")}<button class="btn" onclick="if(!g('ld')){toast('Pick a date');return}sh=null;toast('Leave request sent')">Submit</button><button class="btn ghost" style="margin-top:8px" onclick="shut()">Cancel</button>`;draw()}
/* MEMBER */
function mHome(){const m=members[0];return T("Hi, "+P.mem.name.split(" ")[0],"Let's train today")+`<div class="hero"><div class="row"><div><div class="mut">Pro plan · ${m.due?"Payment due":"Active"}</div><div class="big">${m.due?inr(m.due):"22 days left"}</div><div class="mut">${m.due?"Due now":"Renews 10 Nov"}</div></div>${qr(84)}</div>${m.due?`<button class="btn hero-cta-btn" onclick="payOpen('due',0)">${ic("wallet")} Pay ${inr(m.due)} via UPI</button>`:`<button class="btn hero-cta-btn" onclick="qrSheet()">${ic("qr")} Show check-in QR</button>`}</div><div class="grid">${kpi("Day streak","6")}${kpi("Visits / month","14")}</div><h2>Today's workout</h2>${item("Push day","Bench press · Shoulder press · Dips",btn("Start","go('work')"))}<h2>Next class</h2>${item("HIIT Blast","Wed 6:30 AM · Rahul D.",'<span class="pill in">Booked</span>')}`}
function qrSheet(){
  const pass = (window.R3P_DB && window.R3P_DB.generateRotatingQrPass) ? window.R3P_DB.generateRotatingQrPass("MEM-001") : { token: "R3P-001", secondsRemaining: 30 };
  sh = `<div style="text-align:center">
    <div style="display:inline-flex;align-items:center;gap:6px;background:rgba(16,185,129,0.15);color:#10b981;padding:4px 12px;border-radius:9999px;font-size:11px;font-weight:700;margin-bottom:8px">
      <span style="display:inline-block;width:6px;height:6px;border-radius:50%;background:#10b981"></span>
      CRYPTOGRAPHIC ROTATING PASS
    </div>
    <h2 style="margin:4px 0 12px">Digital Access QR</h2>
    <div style="background:#ffffff;padding:14px;border-radius:20px;display:inline-block;box-shadow:0 10px 30px rgba(0,0,0,0.5)">
      ${qr(190)}
    </div>
    <div style="display:flex;align-items:center;justify-content:center;gap:8px;margin:12px 0 4px">
      <span class="mut" style="font-size:12px">Token expires in:</span>
      <b style="color:var(--ac,#ff5500);font-size:13px">${pass.secondsRemaining}s</b>
    </div>
    <div class="mut" style="font-size:11px;margin-bottom:18px">Anti-Fraud Security · Code rotates every 30s</div>
    <button class="btn" onclick="shut()">Done</button>
  </div>`;
  draw();
}
const ALL_ROUTINES = [{"id": "RTN-001", "title": "Chest & Triceps Hypertrophy", "category": "Strength & Muscle", "duration": "35 mins", "exercisesCount": "6 exercises", "targetMuscles": "Chest / Triceps", "exercises": ["Flat Bench", "Incline DB Press", "Cable Flyes", "Dips", "Rope Pushdowns", "Skull Crushers"], "difficulty": "Intermediate", "completed": 0}, {"id": "RTN-002", "title": "Back & Biceps Thickness", "category": "Strength & Muscle", "duration": "40 mins", "exercisesCount": "6 exercises", "targetMuscles": "Lats / Biceps", "exercises": ["Deadlifts", "Barbell Rows", "Lat Pulldown", "Seated Cable Row", "Hammer Curls", "Preacher Curls"], "difficulty": "Intermediate", "completed": 0}, {"id": "RTN-003", "title": "Leg Day Quad Focus", "category": "Strength & Muscle", "duration": "45 mins", "exercisesCount": "6 exercises", "targetMuscles": "Quads / Calves", "exercises": ["Back Squats", "Leg Press", "Walking Lunges", "Leg Extensions", "Standing Calf Raises", "Seated Calf Raises"], "difficulty": "Advanced", "completed": 0}, {"id": "RTN-004", "title": "Leg Day Posterior Chain", "category": "Strength & Muscle", "duration": "45 mins", "exercisesCount": "6 exercises", "targetMuscles": "Hamstrings / Glutes", "exercises": ["Romanian Deadlifts", "Hip Thrusts", "Lying Leg Curls", "Bulgarian Split Squats", "Kettlebell Swings"], "difficulty": "Intermediate", "completed": 0}, {"id": "RTN-005", "title": "Shoulder Boulder Blast", "category": "Strength & Muscle", "duration": "30 mins", "exercisesCount": "5 exercises", "targetMuscles": "Delts / Traps", "exercises": ["Overhead Press", "Dumbbell Lateral Raises", "Face Pulls", "Front Plate Raises", "DB Shrugs"], "difficulty": "Intermediate", "completed": 0}, {"id": "RTN-006", "title": "Arm Annihilator Super-set", "category": "Strength & Muscle", "duration": "30 mins", "exercisesCount": "6 exercises", "targetMuscles": "Biceps / Triceps", "exercises": ["Barbell Curls", "Close Grip Bench", "Incline DB Curls", "Overhead Triceps Extension", "Cable 21s"], "difficulty": "Intermediate", "completed": 0}, {"id": "RTN-007", "title": "Chest & Back Antagonist", "category": "Strength & Muscle", "duration": "45 mins", "exercisesCount": "6 exercises", "targetMuscles": "Chest / Back", "exercises": ["Incline Bench Press", "Pull-ups", "DB Flat Flyes", "T-Bar Rows", "Dips", "Chest-supported Rows"], "difficulty": "Advanced", "completed": 0}, {"id": "RTN-008", "title": "Upper Body Power Builder", "category": "Strength & Muscle", "duration": "40 mins", "exercisesCount": "5 exercises", "targetMuscles": "Upper Body", "exercises": ["Standing Military Press", "Barbell Bench Press", "Weighted Pull-ups", "Pendlay Rows", "Push Press"], "difficulty": "Advanced", "completed": 0}, {"id": "RTN-009", "title": "Lower Body Strength Test", "category": "Strength & Muscle", "duration": "45 mins", "exercisesCount": "5 exercises", "targetMuscles": "Lower Body", "exercises": ["Front Squats", "Sumo Deadlifts", "Bulgarian Split Squats", "Calf Raises", "Nordic Curls"], "difficulty": "Advanced", "completed": 0}, {"id": "RTN-010", "title": "Push Day Volume Focus", "category": "Strength & Muscle", "duration": "40 mins", "exercisesCount": "6 exercises", "targetMuscles": "Push", "exercises": ["DB Incline Press", "Standing OHP", "Cable Crossovers", "Dips", "Lateral Raises", "Tricep Kickbacks"], "difficulty": "Intermediate", "completed": 0}, {"id": "RTN-011", "title": "Pull Day Lat Width", "category": "Strength & Muscle", "duration": "40 mins", "exercisesCount": "6 exercises", "targetMuscles": "Pull", "exercises": ["Wide-grip Lat Pulldowns", "Single Arm DB Rows", "Straight Arm Pulldowns", "Barbell Shrugs", "Incline Curls"], "difficulty": "Intermediate", "completed": 0}, {"id": "RTN-012", "title": "Glute Sculptor Pro", "category": "Strength & Muscle", "duration": "35 mins", "exercisesCount": "5 exercises", "targetMuscles": "Glutes", "exercises": ["Barbell Hip Thrusts", "Cable Kickbacks", "Romanian Deadlifts", "Step Ups", "Abductor Machine"], "difficulty": "Intermediate", "completed": 0}, {"id": "RTN-013", "title": "Full Body Calorie Torch", "category": "Fat Loss & HIIT", "duration": "25 mins", "exercisesCount": "7 exercises", "targetMuscles": "Full Body", "exercises": ["Burpees", "Kettlebell Swings", "Box Jumps", "Mountain Climbers", "Battle Ropes", "Jump Squats"], "difficulty": "All Levels", "completed": 0}, {"id": "RTN-014", "title": "Tabata Core & Conditioning", "category": "Fat Loss & HIIT", "duration": "20 mins", "exercisesCount": "6 exercises", "targetMuscles": "Abs & Cardio", "exercises": ["Plank Jacks", "High Knees", "Bicycle Crunches", "Russian Twists", "Hollow Body Hold", "Sprint Burpees"], "difficulty": "All Levels", "completed": 0}, {"id": "RTN-015", "title": "Sprint Interval Treadmill Blast", "category": "Fat Loss & HIIT", "duration": "20 mins", "exercisesCount": "5 rounds", "targetMuscles": "Cardio", "exercises": ["30s 14km/h Sprint", "60s Walking Rest", "Incline Jog", "Sled Push Finisher"], "difficulty": "Intermediate", "completed": 0}, {"id": "RTN-016", "title": "Kettlebell Chaos Complex", "category": "Fat Loss & HIIT", "duration": "25 mins", "exercisesCount": "5 exercises", "targetMuscles": "Conditioning", "exercises": ["KB Clean & Press", "Goblet Squats", "KB Swings", "Snatch", "Turkish Get-up"], "difficulty": "Intermediate", "completed": 0}, {"id": "RTN-017", "title": "Rowing Ergometer Metcon", "category": "Fat Loss & HIIT", "duration": "20 mins", "exercisesCount": "4 rounds", "targetMuscles": "Cardio Endurance", "exercises": ["500m Row", "20 Wall Balls", "15 Push-ups", "10 Box Jumps"], "difficulty": "Advanced", "completed": 0}, {"id": "RTN-018", "title": "Bodyweight Burner Zero Gear", "category": "Fat Loss & HIIT", "duration": "20 mins", "exercisesCount": "6 exercises", "targetMuscles": "Bodyweight", "exercises": ["Air Squats", "Push-ups", "Lunges", "Plank", "Burpees", "Jumping Jacks"], "difficulty": "Beginner", "completed": 0}, {"id": "RTN-019", "title": "Stair Climber Metabolic Ladder", "category": "Fat Loss & HIIT", "duration": "25 mins", "exercisesCount": "Intervals", "targetMuscles": "Legs & Heart Rate", "exercises": ["Level 8 Steady", "Level 14 Sprint", "Skip Step", "Side Step", "Reverse Climb"], "difficulty": "Intermediate", "completed": 0}, {"id": "RTN-020", "title": "Assault Bike Lung Buster", "category": "Fat Loss & HIIT", "duration": "15 mins", "exercisesCount": "Tabata", "targetMuscles": "Cardio", "exercises": ["10s All-out Max Wattage", "20s Active Recovery x 16 Rounds"], "difficulty": "Advanced", "completed": 0}, {"id": "RTN-021", "title": "Jump Rope & Shadow Boxing", "category": "Fat Loss & HIIT", "duration": "25 mins", "exercisesCount": "6 rounds", "targetMuscles": "Speed & Agility", "exercises": ["Speed Rope", "1-2-Hook Combos", "Double Unders", "Slip & Roll Drills"], "difficulty": "Intermediate", "completed": 0}, {"id": "RTN-022", "title": "Dumbbell Complex Fat Melter", "category": "Fat Loss & HIIT", "duration": "30 mins", "exercisesCount": "5 exercises", "targetMuscles": "Full Body", "exercises": ["DB Romanian Deadlift", "Hang Clean", "Front Squat", "Push Press", "Bent Row"], "difficulty": "Advanced", "completed": 0}, {"id": "RTN-023", "title": "Speed & Agility Ladder Drills", "category": "Fat Loss & HIIT", "duration": "20 mins", "exercisesCount": "8 drills", "targetMuscles": "Agility", "exercises": ["Ickey Shuffle", "In-and-Outs", "Linear Sprints", "Lateral Shuffles", "Cone Drills"], "difficulty": "All Levels", "completed": 0}, {"id": "RTN-024", "title": "Boxing Bag Power Intervals", "category": "Fat Loss & HIIT", "duration": "25 mins", "exercisesCount": "5 rounds", "targetMuscles": "Full Body / Stamina", "exercises": ["Heavy Bag Combos", "Speed Bag", "Body Snatchers", "Push-up Burpees"], "difficulty": "Intermediate", "completed": 0}, {"id": "RTN-025", "title": "Athletic Explosiveness", "category": "Functional & Athletic", "duration": "35 mins", "exercisesCount": "5 exercises", "targetMuscles": "Power", "exercises": ["Power Cleans", "Medicine Ball Slams", "Broad Jumps", "Plyo Push-ups", "Trap Bar Jumps"], "difficulty": "Advanced", "completed": 0}, {"id": "RTN-026", "title": "Prowler Sled & Turf Circuit", "category": "Functional & Athletic", "duration": "30 mins", "exercisesCount": "4 exercises", "targetMuscles": "Legs & Core", "exercises": ["Heavy Sled Push", "Sled Pull", "Farmers Walk", "Sandbag Carries"], "difficulty": "Advanced", "completed": 0}, {"id": "RTN-027", "title": "Cross-Training WOD Alpha", "category": "Functional & Athletic", "duration": "25 mins", "exercisesCount": "For Time", "targetMuscles": "Functional", "exercises": ["21-15-9 Thrusters & Pull-ups", "400m Run", "50 Double Unders"], "difficulty": "Advanced", "completed": 0}, {"id": "RTN-028", "title": "Kettlebell Flow & Stability", "category": "Functional & Athletic", "duration": "30 mins", "exercisesCount": "5 exercises", "targetMuscles": "Mobility & Core", "exercises": ["Windmills", "Turkish Get-ups", "Halo Circles", "Single-leg Deadlifts"], "difficulty": "Intermediate", "completed": 0}, {"id": "RTN-029", "title": "Rings & Calisthenics Mastery", "category": "Functional & Athletic", "duration": "35 mins", "exercisesCount": "5 exercises", "targetMuscles": "Upper Body", "exercises": ["Ring Muscle-ups", "Ring Dips", "Skin the Cat", "L-Sit Pull-ups", "Handstand Hold"], "difficulty": "Advanced", "completed": 0}, {"id": "RTN-030", "title": "MMA Fighter Conditioning", "category": "Functional & Athletic", "duration": "30 mins", "exercisesCount": "5 rounds", "targetMuscles": "Full Body", "exercises": ["Sprawls", "Clinch Knee Strikes", "Heavy Bag Slams", "Ground & Pound", "Battle Ropes"], "difficulty": "Advanced", "completed": 0}, {"id": "RTN-031", "title": "Grip Strength & Forearm Armor", "category": "Functional & Athletic", "duration": "20 mins", "exercisesCount": "5 exercises", "targetMuscles": "Grip / Forearms", "exercises": ["Dead Hangs", "Wrist Rollers", "Pinch Plate Holds", "Fat Grip Curls", "Reverse Curls"], "difficulty": "All Levels", "completed": 0}, {"id": "RTN-032", "title": "Unilateral Balance & Power", "category": "Functional & Athletic", "duration": "30 mins", "exercisesCount": "5 exercises", "targetMuscles": "Lower Body", "exercises": ["Single Leg Box Jumps", "Pistol Squats", "Single Arm Snatch", "Suitcase Carries"], "difficulty": "Intermediate", "completed": 0}, {"id": "RTN-033", "title": "Core Fortress 360", "category": "Functional & Athletic", "duration": "20 mins", "exercisesCount": "6 exercises", "targetMuscles": "Core", "exercises": ["Hanging Leg Raises", "Ab Wheel Rollouts", "Dragon Flags", "Pallof Press", "Side Planks"], "difficulty": "Intermediate", "completed": 0}, {"id": "RTN-034", "title": "Joint Mobility & Bulletproofing", "category": "Functional & Athletic", "duration": "25 mins", "exercisesCount": "7 exercises", "targetMuscles": "Mobility", "exercises": ["World's Greatest Stretch", "Thoracic Rotations", "Jefferson Curls", "Couch Stretch", "Band Pull-aparts"], "difficulty": "All Levels", "completed": 0}, {"id": "RTN-035", "title": "Sandbag Tactical Strength", "category": "Functional & Athletic", "duration": "30 mins", "exercisesCount": "5 exercises", "targetMuscles": "Functional", "exercises": ["Sandbag Shouldering", "Bear Hug Squats", "Rotational Toss", "Overhead Lunges"], "difficulty": "Advanced", "completed": 0}, {"id": "RTN-036", "title": "Speed Acceleration & Sprinting", "category": "Functional & Athletic", "duration": "25 mins", "exercisesCount": "5 drills", "targetMuscles": "Speed", "exercises": ["Wall Drives", "A-Skips", "30m Flying Sprints", "Resisted Band Sprints"], "difficulty": "Intermediate", "completed": 0}, {"id": "RTN-037", "title": "First Day Foundation A", "category": "Beginner & Foundation", "duration": "30 mins", "exercisesCount": "5 exercises", "targetMuscles": "Full Body", "exercises": ["Machine Chest Press", "Lat Pulldown", "Leg Press", "Dumbbell Curls", "Seated Calf"], "difficulty": "Beginner", "completed": 0}, {"id": "RTN-038", "title": "First Day Foundation B", "category": "Beginner & Foundation", "duration": "30 mins", "exercisesCount": "5 exercises", "targetMuscles": "Full Body", "exercises": ["Goblet Squat", "Seated Cable Row", "Dumbbell Shoulder Press", "Plank", "Treadmill Walk"], "difficulty": "Beginner", "completed": 0}, {"id": "RTN-039", "title": "Posture Restoration Protocol", "category": "Beginner & Foundation", "duration": "25 mins", "exercisesCount": "6 exercises", "targetMuscles": "Spine & Neck", "exercises": ["Face Pulls", "Prone Y-T-W", "Chin Tucks", "Glute Bridges", "Hip Flexor Release"], "difficulty": "Beginner", "completed": 0}, {"id": "RTN-040", "title": "Bodyweight Essentials 101", "category": "Beginner & Foundation", "duration": "20 mins", "exercisesCount": "5 exercises", "targetMuscles": "Full Body", "exercises": ["Assisted Pull-ups", "Knee Push-ups", "Box Squats", "Glute Bridges", "Plank"], "difficulty": "Beginner", "completed": 0}, {"id": "RTN-041", "title": "Dumbbell Only Home & Gym", "category": "Beginner & Foundation", "duration": "30 mins", "exercisesCount": "5 exercises", "targetMuscles": "Full Body", "exercises": ["DB Floor Press", "DB Squats", "DB Rows", "DB Romanian Deadlift", "Overhead Press"], "difficulty": "Beginner", "completed": 0}, {"id": "RTN-042", "title": "Desk Worker Tension Relief", "category": "Beginner & Foundation", "duration": "15 mins", "exercisesCount": "6 exercises", "targetMuscles": "Mobility", "exercises": ["Cat-Cow", "Doorway Pec Stretch", "Seated Spinal Twist", "Neck Rolls", "Hamstring Reach"], "difficulty": "Beginner", "completed": 0}, {"id": "RTN-043", "title": "Low Impact Senior / Gentle Cardio", "category": "Beginner & Foundation", "duration": "25 mins", "exercisesCount": "4 exercises", "targetMuscles": "Longevity", "exercises": ["Recumbent Bike", "Wall Squats", "Light Band Pulls", "Balance Walk"], "difficulty": "Beginner", "completed": 0}, {"id": "RTN-044", "title": "Core Stability for Back Pain", "category": "Beginner & Foundation", "duration": "20 mins", "exercisesCount": "5 exercises", "targetMuscles": "Core", "exercises": ["Bird-Dog", "Dead Bug", "Side Plank", "Glute Bridge", "McGill Curl-up"], "difficulty": "Beginner", "completed": 0}, {"id": "RTN-045", "title": "Cardio Aerobic Base Builder", "category": "Beginner & Foundation", "duration": "30 mins", "exercisesCount": "Steady State", "targetMuscles": "Heart Rate Zone 2", "exercises": ["Incline Walk 12%", "4.5 km/h", "Heart Rate 125-135 BPM for 30 Mins"], "difficulty": "Beginner", "completed": 0}, {"id": "RTN-046", "title": "Arm Definition Dumbbell Only", "category": "Beginner & Foundation", "duration": "25 mins", "exercisesCount": "5 exercises", "targetMuscles": "Arms", "exercises": ["Standing DB Curls", "Hammer Curls", "Overhead Triceps Extension", "Kickbacks"], "difficulty": "Beginner", "completed": 0}, {"id": "RTN-047", "title": "Leg Tone & Sculpt Beginner", "category": "Beginner & Foundation", "duration": "30 mins", "exercisesCount": "5 exercises", "targetMuscles": "Legs", "exercises": ["Goblet Squats", "Lying Leg Curls", "Bodyweight Lunges", "Glute Bridges"], "difficulty": "Beginner", "completed": 0}, {"id": "RTN-048", "title": "Daily 10-Minute Morning Wakeup", "category": "Beginner & Foundation", "duration": "10 mins", "exercisesCount": "4 exercises", "targetMuscles": "Mobility", "exercises": ["Sun Salutations", "Deep Squat Hold", "Inchworms", "Downward Dog"], "difficulty": "Beginner", "completed": 0}, {"id": "RTN-049", "title": "Deadlift Peak Performance", "category": "Powerlifting & Strength", "duration": "50 mins", "exercisesCount": "5 exercises", "targetMuscles": "Posterior Chain", "exercises": ["Deadlift 5x3 Ramp", "Deficit Deadlifts", "Barbell Shrugs", "Hamstring Curls", "Back Hyperextensions"], "difficulty": "Advanced", "completed": 0}, {"id": "RTN-050", "title": "Squat Mastery 5x5", "category": "Powerlifting & Strength", "duration": "50 mins", "exercisesCount": "5 exercises", "targetMuscles": "Quads & Core", "exercises": ["Barbell Back Squat 5x5", "Pause Squats", "Leg Press", "Standing Calf Raise", "Ab Wheel"], "difficulty": "Advanced", "completed": 0}, {"id": "RTN-051", "title": "Bench Press PR Day", "category": "Powerlifting & Strength", "duration": "45 mins", "exercisesCount": "5 exercises", "targetMuscles": "Chest & Triceps", "exercises": ["Competition Bench 5x3", "Spoto Press", "Close Grip Bench", "Incline DB Press", "Cable Triceps"], "difficulty": "Advanced", "completed": 0}, {"id": "RTN-052", "title": "Overhead Strict Press Heavy", "category": "Powerlifting & Strength", "duration": "40 mins", "exercisesCount": "5 exercises", "targetMuscles": "Shoulders & Core", "exercises": ["Strict Standing OHP 5x5", "Z-Press", "Behind the Neck Press", "Lateral Raise", "Face Pull"], "difficulty": "Advanced", "completed": 0}, {"id": "RTN-053", "title": "Full Body 5x5 Power A", "category": "Powerlifting & Strength", "duration": "50 mins", "exercisesCount": "3 exercises", "targetMuscles": "Compound", "exercises": ["Back Squats 5x5", "Bench Press 5x5", "Barbell Rows 5x5"], "difficulty": "Intermediate", "completed": 0}, {"id": "RTN-054", "title": "Full Body 5x5 Power B", "category": "Powerlifting & Strength", "duration": "50 mins", "exercisesCount": "3 exercises", "targetMuscles": "Compound", "exercises": ["Back Squats 5x5", "Overhead Press 5x5", "Conventional Deadlift 1x5"], "difficulty": "Intermediate", "completed": 0}, {"id": "RTN-055", "title": "Lockout & Grip Power", "category": "Powerlifting & Strength", "duration": "35 mins", "exercisesCount": "4 exercises", "targetMuscles": "Strength", "exercises": ["Rack Pulls", "Board Press", "Paused Squats", "Farmers Carry"], "difficulty": "Advanced", "completed": 0}, {"id": "RTN-056", "title": "Dynamic Effort Speed Bench", "category": "Powerlifting & Strength", "duration": "35 mins", "exercisesCount": "6 exercises", "targetMuscles": "Upper Body Speed", "exercises": ["Speed Bench 9x3 (50% + Bands)", "Plyo Push-ups", "DB Incline", "Tricep Band Pushdowns"], "difficulty": "Advanced", "completed": 0}, {"id": "RTN-057", "title": "Dynamic Effort Speed Squat", "category": "Powerlifting & Strength", "duration": "40 mins", "exercisesCount": "5 exercises", "targetMuscles": "Lower Body Speed", "exercises": ["Box Squat 10x2 (55% + Bands)", "Speed Deadlifts", "Reverse Hypers", "Sled Drags"], "difficulty": "Advanced", "completed": 0}, {"id": "RTN-058", "title": "Hypertrophy Deload Recovery", "category": "Powerlifting & Strength", "duration": "30 mins", "exercisesCount": "5 exercises", "targetMuscles": "Recovery", "exercises": ["Light Goblet Squats", "Band Pull-aparts", "Incline Treadmill Walk", "Hanging Knee Raise"], "difficulty": "All Levels", "completed": 0}, {"id": "RTN-059", "title": "Basketball Vertical Jump", "category": "Functional & Athletic", "duration": "35 mins", "exercisesCount": "6 exercises", "targetMuscles": "Legs", "exercises": ["Depth Jumps", "Trap Bar Jumps", "Bulgarian Split Squats", "Tibialis Raises", "Box Jumps"], "difficulty": "Advanced", "completed": 0}, {"id": "RTN-060", "title": "Cricket Fast Bowler Core & Shoulder", "category": "Functional & Athletic", "duration": "35 mins", "exercisesCount": "5 exercises", "targetMuscles": "Shoulders & Core", "exercises": ["Rotational Med Ball Throws", "Landmine Press", "Cable Woodchoppers", "Face Pulls"], "difficulty": "Intermediate", "completed": 0}, {"id": "RTN-061", "title": "Football Striker Agility & Stamina", "category": "Functional & Athletic", "duration": "40 mins", "exercisesCount": "6 exercises", "targetMuscles": "Conditioning", "exercises": ["Suicide Sprints", "Cone Ladders", "Nordic Hamstring Curls", "Broad Jumps"], "difficulty": "Intermediate", "completed": 0}, {"id": "RTN-062", "title": "Tennis Rotational Power", "category": "Functional & Athletic", "duration": "30 mins", "exercisesCount": "5 exercises", "targetMuscles": "Core & Back", "exercises": ["Cable Woodchoppers", "Rotational Med Ball Slams", "Banded Shoulder ER", "Lunges"], "difficulty": "Intermediate", "completed": 0}, {"id": "RTN-063", "title": "Swimming Lat & Shoulder Endurance", "category": "Functional & Athletic", "duration": "35 mins", "exercisesCount": "5 exercises", "targetMuscles": "Back & Delts", "exercises": ["Straight Arm Pulldowns", "Scapular Pull-ups", "Swimmer Kicks", "Band Pulls"], "difficulty": "Intermediate", "completed": 0}, {"id": "RTN-064", "title": "Marathon Runner Leg Durability", "category": "Functional & Athletic", "duration": "30 mins", "exercisesCount": "5 exercises", "targetMuscles": "Legs & Core", "exercises": ["Single-leg Deadlift", "Calf Raise Eccentrics", "Side Planks", "Hamstring Sliders"], "difficulty": "Intermediate", "completed": 0}, {"id": "RTN-065", "title": "Cycling Quad Power Intervals", "category": "Functional & Athletic", "duration": "30 mins", "exercisesCount": "4 exercises", "targetMuscles": "Quads", "exercises": ["High Cadence Spin", "Leg Press Dropset", "Step Ups", "Walking Lunges"], "difficulty": "Intermediate", "completed": 0}, {"id": "RTN-066", "title": "Rock Climbing Grip & Lats", "category": "Functional & Athletic", "duration": "35 mins", "exercisesCount": "5 exercises", "targetMuscles": "Grip & Back", "exercises": ["Campus Board", "Frenchies", "Weighted Pull-ups", "Finger Board Hangs", "Inverted Rows"], "difficulty": "Advanced", "completed": 0}, {"id": "RTN-067", "title": "Badminton Explosive Court Speed", "category": "Functional & Athletic", "duration": "30 mins", "exercisesCount": "5 exercises", "targetMuscles": "Agility", "exercises": ["Split Step Drills", "Lateral Lunges", "Shadow Footwork", "Calf Explosions"], "difficulty": "Intermediate", "completed": 0}, {"id": "RTN-068", "title": "Calisthenics Front Lever Path", "category": "Functional & Athletic", "duration": "35 mins", "exercisesCount": "5 exercises", "targetMuscles": "Core & Lats", "exercises": ["Tuck Front Lever", "Dragon Flags", "Scapular Retractions", "Hollow Body Rocks"], "difficulty": "Advanced", "completed": 0}, {"id": "RTN-069", "title": "Calisthenics Planche Prep", "category": "Functional & Athletic", "duration": "35 mins", "exercisesCount": "5 exercises", "targetMuscles": "Shoulders & Core", "exercises": ["Planche Leans", "Pseudo Planche Push-ups", "Pike Push-ups", "Wrist Prep"], "difficulty": "Advanced", "completed": 0}, {"id": "RTN-070", "title": "Calisthenics Muscle-up Progression", "category": "Functional & Athletic", "duration": "30 mins", "exercisesCount": "5 exercises", "targetMuscles": "Upper Body", "exercises": ["Explosive Chest-to-Bar Pull-ups", "Straight Bar Dips", "Transition Drills"], "difficulty": "Advanced", "completed": 0}, {"id": "RTN-071", "title": "Office Neck & Shoulder Release", "category": "Beginner & Foundation", "duration": "15 mins", "exercisesCount": "4 exercises", "targetMuscles": "Neck", "exercises": ["Upper Trap Stretch", "Levator Scapulae Stretch", "Wall Angels", "Foam Roll Thoracic"], "difficulty": "Beginner", "completed": 0}, {"id": "RTN-072", "title": "Lower Back Decompression", "category": "Beginner & Foundation", "duration": "20 mins", "exercisesCount": "5 exercises", "targetMuscles": "Lower Back", "exercises": ["Dead Hang", "Child Pose", "Piriformis Stretch", "Cat-Camel", "Glute Bridge"], "difficulty": "Beginner", "completed": 0}, {"id": "RTN-073", "title": "Knee Pain Relief & VMO Activation", "category": "Beginner & Foundation", "duration": "25 mins", "exercisesCount": "5 exercises", "targetMuscles": "Knees & Quads", "exercises": ["Poliquin Step-ups", "Terminal Knee Extensions", "Hamstring Curls", "Calf Raises"], "difficulty": "Beginner", "completed": 0}, {"id": "RTN-074", "title": "Shoulder Impingement Protocol", "category": "Beginner & Foundation", "duration": "20 mins", "exercisesCount": "5 exercises", "targetMuscles": "Rotator Cuff", "exercises": ["Sleeper Stretch", "External Rotations", "Scapular Wall Slides", "Face Pulls"], "difficulty": "Beginner", "completed": 0}, {"id": "RTN-075", "title": "Hip Flexor Opening Session", "category": "Beginner & Foundation", "duration": "20 mins", "exercisesCount": "5 exercises", "targetMuscles": "Hips", "exercises": ["Couch Stretch", "Pigeon Pose", "Half Kneeling Hip Stretch", "Butterfly Stretch"], "difficulty": "Beginner", "completed": 0}, {"id": "RTN-076", "title": "Ankle Mobility & Plantar Relief", "category": "Beginner & Foundation", "duration": "15 mins", "exercisesCount": "4 exercises", "targetMuscles": "Feet & Ankles", "exercises": ["Calf Wall Stretch", "Band Ankle Distractions", "Golf Ball Foot Roll", "Heel Drops"], "difficulty": "Beginner", "completed": 0}, {"id": "RTN-077", "title": "Pre-Workout Dynamic Warmup 1", "category": "Beginner & Foundation", "duration": "10 mins", "exercisesCount": "5 exercises", "targetMuscles": "Full Body", "exercises": ["Arm Circles", "Leg Swings", "Butt Kicks", "Torso Twists", "Bodyweight Squats"], "difficulty": "Beginner", "completed": 0}, {"id": "RTN-078", "title": "Post-Workout Full Cool Down", "category": "Beginner & Foundation", "duration": "12 mins", "exercisesCount": "6 exercises", "targetMuscles": "Flexibility", "exercises": ["Standing Quad Stretch", "Hamstring Fold", "Cobra Stretch", "Cross-body Shoulder"], "difficulty": "Beginner", "completed": 0}, {"id": "RTN-079", "title": "Upper Body Dumbbell Shred", "category": "Fat Loss & HIIT", "duration": "30 mins", "exercisesCount": "5 exercises", "targetMuscles": "Upper Body", "exercises": ["DB Push Press", "DB Rows", "DB Floor Press", "Shadow Jabs with 2kg", "Mountain Climbers"], "difficulty": "Intermediate", "completed": 0}, {"id": "RTN-080", "title": "Lower Body Dumbbell Burner", "category": "Fat Loss & HIIT", "duration": "30 mins", "exercisesCount": "5 exercises", "targetMuscles": "Lower Body", "exercises": ["DB Goblet Squats", "Alternating DB Lunges", "DB Romanian Deadlifts", "Jump Rope"], "difficulty": "Intermediate", "completed": 0}, {"id": "RTN-081", "title": "300 Rep Spartan Challenge", "category": "Fat Loss & HIIT", "duration": "25 mins", "exercisesCount": "6 exercises", "targetMuscles": "Full Body", "exercises": ["50 Pull-ups", "50 Push-ups", "50 Box Jumps", "50 Floor Wipers", "50 Clean & Press", "50 Squats"], "difficulty": "Advanced", "completed": 0}, {"id": "RTN-082", "title": "Deck of Cards Bodyweight", "category": "Fat Loss & HIIT", "duration": "30 mins", "exercisesCount": "4 exercises", "targetMuscles": "Conditioning", "exercises": ["Hearts=Push-ups", "Spades=Burpees", "Diamonds=Squats", "Clubs=Sit-ups"], "difficulty": "Intermediate", "completed": 0}, {"id": "RTN-083", "title": "EMOM 20-Minute Grind", "category": "Fat Loss & HIIT", "duration": "20 mins", "exercisesCount": "4 exercises", "targetMuscles": "Metcon", "exercises": ["Min 1: 15 KB Swings", "Min 2: 12 Burpees", "Min 3: 15 Box Jumps", "Min 4: Rest"], "difficulty": "Intermediate", "completed": 0}, {"id": "RTN-084", "title": "AMRAP 15-Minute Inferno", "category": "Fat Loss & HIIT", "duration": "15 mins", "exercisesCount": "3 exercises", "targetMuscles": "Metcon", "exercises": ["10 Thrusters", "10 Pull-ups", "200m Run as many rounds as possible"], "difficulty": "Advanced", "completed": 0}, {"id": "RTN-085", "title": "Rowing 2K Time Trial Prep", "category": "Fat Loss & HIIT", "duration": "30 mins", "exercisesCount": "Intervals", "targetMuscles": "Cardio", "exercises": ["5x500m Row with 1:1 Rest at Target Split Pace"], "difficulty": "Advanced", "completed": 0}, {"id": "RTN-086", "title": "SkiErg Upper Body Cardio", "category": "Fat Loss & HIIT", "duration": "20 mins", "exercisesCount": "5 rounds", "targetMuscles": "Upper Body Cardio", "exercises": ["500m SkiErg", "15 Push-ups", "20 Core Twists"], "difficulty": "Intermediate", "completed": 0}, {"id": "RTN-087", "title": "Heavy Bag 10-Round Boxing", "category": "Fat Loss & HIIT", "duration": "30 mins", "exercisesCount": "10 rounds", "targetMuscles": "Boxing", "exercises": ["3-minute rounds with 30-sec active rest (Push-ups", "Plank", "Jumping Jacks)"], "difficulty": "Advanced", "completed": 0}, {"id": "RTN-088", "title": "Agility Cones & Shuttle Sprints", "category": "Fat Loss & HIIT", "duration": "20 mins", "exercisesCount": "5 drills", "targetMuscles": "Speed", "exercises": ["Pro Agility 5-10-5", "T-Drill", "Shuttle Runs", "Figure 8s"], "difficulty": "All Levels", "completed": 0}, {"id": "RTN-089", "title": "Barbell Squat Volume 10x10", "category": "Strength & Muscle", "duration": "50 mins", "exercisesCount": "German Volume", "targetMuscles": "Quads", "exercises": ["Barbell Back Squat 10 sets x 10 reps @ 60% 1RM", "Leg Curls 3x12"], "difficulty": "Advanced", "completed": 0}, {"id": "RTN-090", "title": "Barbell Bench Volume 10x10", "category": "Strength & Muscle", "duration": "50 mins", "exercisesCount": "German Volume", "targetMuscles": "Chest", "exercises": ["Barbell Flat Bench 10 sets x 10 reps @ 60% 1RM", "Lat Pulldowns 3x12"], "difficulty": "Advanced", "completed": 0}, {"id": "RTN-091", "title": "Barbell Deadlift Volume 8x8", "category": "Strength & Muscle", "duration": "50 mins", "exercisesCount": "Volume", "targetMuscles": "Back", "exercises": ["Conventional Deadlift 8 sets x 8 reps", "Barbell Shrugs", "Hamstring Curls"], "difficulty": "Advanced", "completed": 0}, {"id": "RTN-092", "title": "Dumbbell Incline Hypertrophy", "category": "Strength & Muscle", "duration": "35 mins", "exercisesCount": "5 exercises", "targetMuscles": "Upper Chest", "exercises": ["Incline DB Press", "Incline DB Flyes", "Low-to-High Cable Crossover", "Push-ups"], "difficulty": "Intermediate", "completed": 0}, {"id": "RTN-093", "title": "Wide Back V-Taper Specialist", "category": "Strength & Muscle", "duration": "40 mins", "exercisesCount": "5 exercises", "targetMuscles": "Lats", "exercises": ["Weighted Pull-ups", "Wide Grip Lat Pulldown", "Neutral Grip Cable Row", "Straight Arm Pull"], "difficulty": "Intermediate", "completed": 0}, {"id": "RTN-094", "title": "Hamstring Isolation Masterclass", "category": "Strength & Muscle", "duration": "35 mins", "exercisesCount": "4 exercises", "targetMuscles": "Hamstrings", "exercises": ["Seated Leg Curl", "Lying Leg Curl", "Romanian Deadlift", "Nordic Hamstring Curl"], "difficulty": "Intermediate", "completed": 0}, {"id": "RTN-095", "title": "Calf Titan Blast", "category": "Strength & Muscle", "duration": "20 mins", "exercisesCount": "4 exercises", "targetMuscles": "Calves", "exercises": ["Standing Barbell Calf Raise", "Seated Calf Raise", "Donkey Calf Raise", "Tibialis Raise"], "difficulty": "All Levels", "completed": 0}, {"id": "RTN-096", "title": "Trap & Neck Armor", "category": "Strength & Muscle", "duration": "25 mins", "exercisesCount": "4 exercises", "targetMuscles": "Traps", "exercises": ["Barbell Shrugs", "DB Farmer Walks", "Neck Flexion/Extension", "Face Pulls"], "difficulty": "Intermediate", "completed": 0}, {"id": "RTN-097", "title": "Triceps Horseshoe Builder", "category": "Strength & Muscle", "duration": "25 mins", "exercisesCount": "4 exercises", "targetMuscles": "Triceps", "exercises": ["Overhead Rope Extension", "Skull Crushers", "Diamond Push-ups", "Cable Pushdown"], "difficulty": "Intermediate", "completed": 0}, {"id": "RTN-098", "title": "Biceps Peak Sculptor", "category": "Strength & Muscle", "duration": "25 mins", "exercisesCount": "4 exercises", "targetMuscles": "Biceps", "exercises": ["Incline Dumbbell Curl", "Spider Curl", "Concentration Curl", "Reverse Grip Barbell Curl"], "difficulty": "Intermediate", "completed": 0}, {"id": "RTN-099", "title": "Forearm Popeye Density", "category": "Strength & Muscle", "duration": "20 mins", "exercisesCount": "4 exercises", "targetMuscles": "Forearms", "exercises": ["Behind-the-back Wrist Curl", "Reverse Barbell Curl", "Towel Pull-up Hang", "Gripper"], "difficulty": "All Levels", "completed": 0}, {"id": "RTN-100", "title": "Chest Dips & Push-up Finisher", "category": "Strength & Muscle", "duration": "25 mins", "exercisesCount": "4 exercises", "targetMuscles": "Chest", "exercises": ["Weighted Dips", "Decline Push-ups", "Diamond Push-ups", "Cable Fly Drop Set"], "difficulty": "Intermediate", "completed": 0}, {"id": "RTN-101", "title": "Abs Six-Pack Density", "category": "Strength & Muscle", "duration": "20 mins", "exercisesCount": "5 exercises", "targetMuscles": "Abs", "exercises": ["Hanging Leg Raises", "Cable Woodchoppers", "Ab Wheel Rollout", "Decline Sit-ups"], "difficulty": "Intermediate", "completed": 0}, {"id": "RTN-102", "title": "Heavy Overhead Push Press", "category": "Powerlifting & Strength", "duration": "40 mins", "exercisesCount": "4 exercises", "targetMuscles": "Shoulders", "exercises": ["Push Press 5x3", "Barbell Front Squat", "Face Pulls", "Lateral Raises"], "difficulty": "Advanced", "completed": 0}, {"id": "RTN-103", "title": "Trap Bar Deadlift Max Effort", "category": "Powerlifting & Strength", "duration": "45 mins", "exercisesCount": "4 exercises", "targetMuscles": "Posterior Chain", "exercises": ["Trap Bar High Handle 5x3", "Deficit Reverse Lunges", "Glute Ham Developer"], "difficulty": "Advanced", "completed": 0}, {"id": "RTN-104", "title": "Front Squat Core & Quad Heavy", "category": "Powerlifting & Strength", "duration": "45 mins", "exercisesCount": "4 exercises", "targetMuscles": "Quads & Core", "exercises": ["Barbell Front Squats 5x5", "Zercher Squats", "Walking Barbell Lunges", "Planks"], "difficulty": "Advanced", "completed": 0}, {"id": "RTN-105", "title": "Close Grip Bench Press Power", "category": "Powerlifting & Strength", "duration": "40 mins", "exercisesCount": "4 exercises", "targetMuscles": "Triceps & Chest", "exercises": ["Close Grip Bench Press 5x5", "Weighted Dips", "Floor Press", "JM Press"], "difficulty": "Advanced", "completed": 0}, {"id": "RTN-106", "title": "Sumo Deadlift Technician", "category": "Powerlifting & Strength", "duration": "45 mins", "exercisesCount": "4 exercises", "targetMuscles": "Hips & Hamstrings", "exercises": ["Sumo Deadlift 5x3", "Paused Sumo at Knees", "Hip Thrusts", "Abductor Machine"], "difficulty": "Advanced", "completed": 0}, {"id": "RTN-107", "title": "Safety Squat Bar Quad Crusher", "category": "Powerlifting & Strength", "duration": "45 mins", "exercisesCount": "4 exercises", "targetMuscles": "Quads", "exercises": ["SSB Squats 5x5", "Hatfields Squats", "Bulgarian Split Squats", "Leg Extensions"], "difficulty": "Advanced", "completed": 0}, {"id": "RTN-108", "title": "Swiss Bar Neutral Bench Press", "category": "Powerlifting & Strength", "duration": "40 mins", "exercisesCount": "4 exercises", "targetMuscles": "Chest & Shoulders", "exercises": ["Swiss Bar Bench 5x5", "Neutral DB Incline", "Seal Rows", "Tricep Band Pushdowns"], "difficulty": "Advanced", "completed": 0}];

let rCat = 'All';
let rSearch = '';
function mWork(){
  const cats = ["All", "Strength & Muscle", "Fat Loss & HIIT", "Functional & Athletic", "Beginner & Foundation", "Powerlifting & Strength"];
  
  const filtered = ALL_ROUTINES.filter(r => {
    const matchCat = (rCat === "All" || r.category === rCat);
    const matchSearch = (!rSearch || r.title.toLowerCase().includes(rSearch.toLowerCase()) || r.targetMuscles.toLowerCase().includes(rSearch.toLowerCase()));
    return matchCat && matchSearch;
  });

  return T("Workout Routines", ALL_ROUTINES.length + " Curated Programs") + `
    <div style="margin-bottom:14px">
      <input type="text" placeholder="Search 100+ routines (e.g. Squat, Chest, HIIT)..." value="${rSearch}" oninput="rSearch=this.value;renderWorkoutList();" style="margin-bottom:10px">
      <div class="seg" style="margin-bottom:0">
        ${cats.map(c => `<button class="${rCat===c?'on':''}" onclick="rCat='${c}';draw()">${c}</button>`).join("")}
      </div>
    </div>
    <div class="row mut" style="margin:6px 4px 14px;font-weight:600">
      <span>Showing ${filtered.length} routines</span>
      <span>${ALL_ROUTINES.filter(r=>r.completed).length} completed</span>
    </div>
    <div id="routineList">
      ${renderRoutineCards(filtered)}
    </div>
  `;
}

function renderRoutineCards(list){
  if(!list.length) return `<div class="card" style="text-align:center;padding:30px;color:var(--mut)">No workout routines found matching your search.</div>`;
  
  return list.map((r, i) => {
    const isDone = r.completed;
    return `
      <div class="card" style="cursor:pointer;padding:16px 18px;margin-bottom:12px;border-left:4px solid ${isDone?'var(--ac)':'transparent'}" onclick="openRoutineDetail('${r.id}')">
        <div class="row" style="align-items:flex-start;margin-bottom:8px">
          <div style="flex:1;min-width:0">
            <div style="display:flex;align-items:center;gap:6px;margin-bottom:4px">
              <span class="pill in" style="font-size:10px;padding:2px 8px">${r.category}</span>
              <span class="pill" style="font-size:10px;padding:2px 8px">${r.difficulty}</span>
            </div>
            <b style="font-size:16px;color:var(--text-titles);display:block;line-height:1.25">${r.title}</b>
            <div class="mut" style="font-size:12px;margin-top:4px">${r.targetMuscles}</div>
          </div>
          <div style="text-align:right;flex-shrink:0">
            <span class="pill" style="font-weight:800;font-family:var(--font-mono);font-size:12px;background:var(--card-subtle);color:var(--text-titles)">${r.duration}</span>
            <div class="mut" style="font-size:10px;margin-top:4px">${r.exercisesCount}</div>
          </div>
        </div>
        <div class="row" style="margin-top:10px;padding-top:10px;border-top:1px solid var(--ln);font-size:11px">
          <span class="mut">${r.exercises.slice(0, 3).join(", ")}${r.exercises.length>3?'...':''}</span>
          <div style="display:flex;align-items:center;gap:8px" onclick="event.stopPropagation()">
            <button class="btn sm ${isDone?'ghost':''}" onclick="toggleRoutineComplete('${r.id}')" style="padding:4px 12px;font-size:11px">
              ${isDone ? ic("check") + " Done" : "Log"}
            </button>
          </div>
        </div>
      </div>
    `;
  }).join("");
}

function renderWorkoutList(){
  const listEl = $("#routineList");
  if(!listEl) return;
  const filtered = ALL_ROUTINES.filter(r => {
    const matchCat = (rCat === "All" || r.category === rCat);
    const matchSearch = (!rSearch || r.title.toLowerCase().includes(rSearch.toLowerCase()) || r.targetMuscles.toLowerCase().includes(rSearch.toLowerCase()));
    return matchCat && matchSearch;
  });
  listEl.innerHTML = renderRoutineCards(filtered);
}

function toggleRoutineComplete(id){
  const routine = ALL_ROUTINES.find(r => r.id === id);
  if(routine){
    routine.completed = routine.completed ? 0 : 1;
    toast(routine.completed ? "Workout marked as completed!" : "Workout uncompleted");
    draw();
  }
}

function openRoutineDetail(id){
  const routine = ALL_ROUTINES.find(r => r.id === id);
  if(!routine) return;
  
  sh = `
    <div style="display:flex;justify-content:space-between;align-items:flex-start;margin-bottom:12px">
      <div>
        <span class="pill in" style="font-size:11px;margin-bottom:6px">${routine.category}</span>
        <h2 style="margin:4px 0 2px">${routine.title}</h2>
        <div class="mut">${routine.duration} · ${routine.difficulty}</div>
      </div>
      <button class="header-btn" onclick="shut()">${ic("back")}</button>
    </div>
    
    <div class="card" style="background:var(--card-subtle);margin:14px 0">
      <div class="mut" style="font-size:11px;text-transform:uppercase;margin-bottom:6px">Target Muscles</div>
      <b style="font-size:14px;color:var(--ac)">${routine.targetMuscles}</b>
    </div>

    <h2 style="font-size:14px;margin:16px 0 8px">Exercise Breakdown (${routine.exercises.length})</h2>
    <div style="display:flex;flex-direction:column;gap:8px;margin-bottom:20px">
      ${routine.exercises.map((ex, idx) => `
        <div class="card row" style="margin:0;padding:12px 14px">
          <div style="display:flex;align-items:center;gap:10px">
            <div class="av" style="width:28px;height:28px;font-size:12px;background:var(--card-subtle);color:var(--ac)">${idx+1}</div>
            <b style="font-size:13px">${ex}</b>
          </div>
          <span class="pill" style="font-size:11px">3-4 sets</span>
        </div>
      `).join("")}
    </div>

    <button class="btn" onclick="toggleRoutineComplete('${routine.id}');shut();">${routine.completed?'Mark as Incomplete':'Start & Complete Workout'}</button>
    <button class="btn ghost" style="margin-top:10px" onclick="shut()">Close</button>
  `;
  draw();
}

function mBook(){return T("Book a class","Reserve your spot")+mclasses.map((c,i)=>item(c[0],c[1]+" · "+c[2],btn(c[3]?"Booked":"Book","tg(mclasses,"+i+",3)",c[3]?"ghost":""))).join("")}
function mProg(){const w=[78,77.2,76.5,76,75.1,74.6],pts=w.map((v,i)=>`${i*50+15},${(v-73)*22+10}`).join(" "),days=Array.from({length:28},(_,i)=>(i*5)%7<4);return T("Progress","Last 6 weeks")+`<div class="grid">${kpi("Weight",P.mem.weight+" kg")}${kpi("Body fat","18.2%")}</div><h2>Weight trend</h2><div class="card"><svg viewBox="0 0 280 120" width="100%"><polyline points="${pts}" fill="none" stroke="#ea580c" stroke-width="3" stroke-linecap="round"/>${pts.split(" ").map(p=>`<circle cx="${p.split(",")[0]}" cy="${p.split(",")[1]}" r="4" fill="#ea580c"/>`).join("")}</svg></div><h2>Attendance · 28 days</h2><div class="card" style="display:grid;grid-template-columns:repeat(7,1fr);gap:6px">${days.map(d=>`<div style="aspect-ratio:1;border-radius:8px;background:${d?"#ea580c":"#f3e9de"}"></div>`).join("")}</div>`}
function mPay(){const m=members[0],my=txns.filter(t=>t.t.startsWith("Aarav"));return T("Payments","Membership & billing")+`<div class="card"><div class="row"><div><b>Pro plan</b><div class="mut">${inr(1999)} / month</div></div>${m.due?'<span class="pill warn">Due</span>':'<span class="pill in">Paid</span>'}</div>${m.due?`<button class="btn" style="margin-top:12px" onclick="payOpen('due',0)">Pay ${inr(m.due)} via UPI</button>`:`<button class="btn ghost" style="margin-top:12px" onclick="renewSheet()">Renew or change plan</button>`}</div><h2>History</h2>`+(my.map(t=>item(t.t.split(" · ")[1],t.d+" · "+t.m,`<b class="in">${inr(t.a)}</b>`)).join("")||`<p class="mut">No payments yet</p>`)}
function renewSheet(){sh=`<h2 style="margin-top:0">Choose a plan</h2>${plans.map((p,i)=>item(p.n,p.f[0],btn(inr(p.p),"members[0].due="+p.p+";members[0].p='"+p.n+"';sh=null;payOpen('due',0)"))).join("")}<button class="btn ghost" onclick="shut()">Cancel</button>`;draw()}
/* PROFILE */
function sw(i){NT[role][i][1]=NT[role][i][1]?0:1;draw()}
function saveP(){flash=1;draw()}
function profile(){const p=P[role],f=flash;flash=0;const X={adm:item("Staff & payroll","Manage team and salaries",ic("chev"),"go('staff')"),emp:item("Salary & payslips","View pay status",ic("chev"),"go('salary')"),mem:item("Payments","Membership billing",ic("chev"),"go('pay')")}[role];return `<div class="card" style="text-align:center;padding:20px"><div class="profile-avatar-wrap" style="position:relative;width:76px;height:76px;margin:0 auto 12px">
  <div class="av" style="width:76px;height:76px;font-size:24px;margin:0 auto;overflow:hidden;background-size:cover;background-position:center;${getPFP(role)?`background-image:url('${getPFP(role)}');font-size:0;`:""}" onclick="triggerProfilePic()" title="Change profile picture">${!getPFP(role)?ini(p.name):""}</div>
  <button type="button" class="profile-cam-btn" onclick="triggerProfilePic()" title="Take photo or upload picture">
    ${ic("camera")}
  </button>
  <input type="file" id="profile-camera-input" accept="image/*" capture="user" style="display:none" onchange="handleProfilePicUpload(event)">
  <input type="file" id="profile-file-input" accept="image/*" style="display:none" onchange="handleProfilePicUpload(event)">
  </div><b style="font-size:18px">${p.name}</b><div class="mut">${role=="emp"?p.title+" · Employee":RL[role]}</div>${f?'<div class="pill in" style="display:inline-block;margin-top:8px">Changes saved</div>':""}</div>`+FL[role].map(([t,fs])=>`<h2>${t}</h2><div class="card">${fs.map(([k,l])=>`<div class="mut" style="margin:0 0 4px 2px">${l}</div><input value="${p[k]}" oninput="P[role].${k}=this.value">`).join("")}</div>`).join("")+`<h2>Appearance</h2>
<div class="card">
  <div class="row" style="padding:4px 0">
    <div>
      <b>Dark Theme</b>
      <div class="mut">Toggle light / dark appearance</div>
    </div>
    <div class="sw ${currentTheme==='dark'?'on':''}" onclick="toggleTheme()" title="Switch Theme"></div>
  </div>
</div>
<h2>Notifications</h2><div class="card">${NT[role].map(([l,v],i)=>`<div class="row" style="padding:8px 0"><span>${l}</span><div class="sw ${v?"on":""}" onclick="sw(${i})"></div></div>`).join("")}</div><h2>Shortcuts</h2>${X}<button class="btn" style="margin:6px 0 10px" onclick="saveP()">Save changes</button><button class="btn ghost" style="margin-bottom:30px" onclick="login()">Sign out</button>`}
/* SHELL */
const SV={Plans:aPlans,Subs:aSubs,Insights:aIns,Members:aMem,Classes:aCls,Equipment:aEq,Announcements:aAnn,Profile:profile,StaffD:staffD};
const APP={adm:{n:"n-adm",t:[["home","home","Home"],["att","cc","Attendance"],["pay","wallet","Payments"],["staff","people","Staff"],["more","dots","More"]],v:{home:aHome,att:aAtt,pay:aPay,staff:aStaff,more:aMore}},emp:{n:"n-emp",t:[["today","event","Today"],["clients","fit","Clients"],["classes","people","Classes"],["tasks","task","Tasks"],["salary","wallet","Salary"]],v:{today:eToday,clients:eClients,classes:eClasses,tasks:eTasks,salary:eSal}},mem:{n:"n-mem",t:[["home","home","Home"],["work","fit","Workouts"],["book","event","Book"],["prog","trend","Progress"],["pay","wallet","Payments"]],v:{home:mHome,work:mWork,book:mBook,prog:mProg,pay:mPay}}};
function go(t){tab=t;sub=null;fresh=1;draw()}
function op(k){sub=k;fresh=1;draw()}
function back(){sub=null;fresh=1;draw()}
function draw(){const R=APP[role],A=$("#app"),body=sub?SV[sub]():R.v[tab](),o=pay?payHtml():sh;A.dataset.role=role;setArt();A.className=fresh?"fx":"";A.innerHTML=body+`<nav class="${R.n}"><div>${R.t.map(([k,i,l])=>`<button class="${tab==k&&!sub?"on":""}" onclick="go('${k}')"><span class="nav-icon-wrap">${ic(i)}</span><span class="nav-lbl">${l}</span></button>`).join("")}</div></nav>`+(o?`<div class="ov" onclick="shut()"><div class="sheet" onclick="event.stopPropagation()">${o}</div></div>`:"")+(ts?`<div class="toast">${ts}</div>`:"");if(fresh)scrollTo(0,0);fresh=0}
login();

// Load live members & staff from Supabase on launch
if (window.R3PSupabase && window.R3PSupabase.client) {
  window.R3PSupabase.client.from("members").select("*").order("name").then(({data, error}) => {
    if (!error && data && data.length > 0) {
      data.forEach((m, idx) => {
        const existing = members.find(localM => localM.n === m.name);
        if (existing) {
          existing.i = m.is_checked_in ? 1 : 0;
          existing.t = m.checked_in_at || (m.is_checked_in ? "07:15 AM" : "");
          existing.p = m.plan_name || existing.p;
          existing.due = Math.round((m.due_amount_paise || 0) / 100);
        }
      });
      console.log("[Supabase Sync] Synced " + data.length + " members from cloud database.");
      if (typeof draw === "function" && role) draw();
    }
  });
}
